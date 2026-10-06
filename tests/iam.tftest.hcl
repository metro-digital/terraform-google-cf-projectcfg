# Copyright 2026 METRO Digital GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Both providers are mocked. The service-account IAM scenario uses a mocked
# apply to resolve a deferred policy read.
mock_provider "google" {
  source = "./tests/mocks"
}

mock_provider "google-beta" {
  source = "./tests/mocks"
}

variables {
  project_id = "cf-unit-test"
  iam_policy = [{
    role    = "roles/viewer"
    members = ["user:requested@example.com", "user:requested@example.com", "deleted:user:removed@example.com?uid=1"]
  }]
}

# Existing policy has ordinary, service-agent, explicitly preserved, PAM, and
# Datadog bindings. Only the appropriate principals should survive composition.
override_data {
  target = data.google_project_iam_policy.this
  values = {
    policy_data = <<-JSON
{
  "bindings": [
    {
      "role": "roles/viewer",
      "members": [
        "user:old@example.com"
      ]
    },
    {
      "role": "roles/compute.serviceAgent",
      "members": [
        "serviceAccount:compute@example.com"
      ]
    },
    {
      "role": "roles/storage.objectViewer",
      "members": [
        "user:preserved@example.com"
      ]
    },
    {
      "role": "roles/logging.viewer",
      "members": [
        "user:temporary@example.com"
      ],
      "condition": {
        "title": "Created by: PAM",
        "expression": "request.time < timestamp(\"2026-12-31T23:59:59Z\")"
      }
    },
    {
      "role": "roles/monitoring.viewer",
      "members": [
        "serviceAccount:cf-bb-datadog-integration-ab12@cf-unit-test.iam.gserviceaccount.com",
        "user:unmanaged@example.com"
      ]
    }
  ]
}
JSON
  }
}

run "authoritative_policy_with_preserved_bindings" {
  command = plan
  variables { iam_policy_non_authoritative_roles = ["^roles/storage\\.objectViewer$"] }

  assert {
    condition     = toset(local.project_iam_bindings_combined["roles/viewer"].members) == toset(["user:requested@example.com"])
    error_message = "Authoritative roles must replace old principals, deduplicate input, and remove deleted principals."
  }

  assert {
    condition = (
      toset(local.project_iam_bindings_combined["roles/compute.serviceAgent"].members) == toset(["serviceAccount:compute@example.com"]) &&
      toset(local.project_iam_bindings_combined["roles/storage.objectViewer"].members) == toset(["user:preserved@example.com"])
    )
    error_message = "Service-agent roles and explicitly non-authoritative roles must preserve existing bindings."
  }

  assert {
    condition     = length(local.project_iam_pam_bindings) == 1 && length([for binding in values(local.project_iam_bindings_combined) : binding if binding.role == "roles/logging.viewer" && toset(binding.members) == toset(["user:temporary@example.com"])]) == 1
    error_message = "PAM's temporary binding and condition must be retained by default."
  }

  assert {
    condition     = toset(local.project_iam_bindings_combined["roles/monitoring.viewer"].members) == toset(["serviceAccount:cf-bb-datadog-integration-ab12@cf-unit-test.iam.gserviceaccount.com"])
    error_message = "Datadog preservation must retain only the building-block account, not other members sharing its role."
  }
}

run "opt_out_of_pam_and_datadog_preservation" {
  command = plan
  variables {
    iam_policy_keep_pam_bindings  = false
    ignore_datadog_building_block = false
  }

  assert {
    condition     = length(local.project_iam_pam_bindings) == 0 && !contains([for binding in values(local.project_iam_bindings_combined) : binding.role], "roles/logging.viewer") && !contains(keys(local.project_iam_bindings_combined), "roles/monitoring.viewer")
    error_message = "Disabling preservation must drop existing PAM and Datadog bindings."
  }
}

run "conditional_and_unconditional_bindings" {
  command = plan
  variables {
    iam_policy = [
      { role = "roles/viewer", members = ["user:unconditional@example.com"] },
      {
        role    = "roles/viewer"
        members = ["user:conditional@example.com"]
        condition = {
          title      = "Expires"
          expression = "request.time < timestamp(\"2026-12-31T23:59:59Z\")"
        }
      },
    ]
  }

  assert {
    condition = (
      length([for binding in values(local.project_iam_bindings_combined) : binding if binding.role == "roles/viewer"]) == 2 &&
      toset(local.project_iam_bindings_combined["roles/viewer"].members) == toset(["user:unconditional@example.com"]) &&
      length([for binding in values(local.project_iam_bindings_combined) : binding if binding.role == "roles/viewer" && binding.condition != null && toset(binding.members) == toset(["user:conditional@example.com"])]) == 1
    )
    error_message = "Conditional and unconditional bindings of the same role must stay separate."
  }
}

# The existing service-account policy read is deferred until its account exists.
# A mocked apply resolves this dependency without creating any cloud resources.
run "service_account_iam" {
  command = apply
  variables {
    service_accounts = {
      deployer = {
        display_name             = "Deployer"
        project_iam_policy_roles = ["roles/viewer"]
        iam_policy = [{
          role    = "roles/iam.serviceAccountTokenCreator"
          members = ["user:operator@example.com", "user:operator@example.com", "deleted:user:old@example.com?uid=1"]
        }]
        iam_policy_non_authoritative_roles = ["^roles/iam\\.serviceAccountUser$"]
      }
    }
  }

  override_data {
    target = data.google_service_account_iam_policy.this["deployer"]
    values = {
      policy_data = <<-JSON
{
  "bindings": [
    {
      "role": "roles/iam.serviceAccountUser",
      "members": [
        "user:existing@example.com"
      ]
    },
    {
      "role": "roles/iam.serviceAccountTokenCreator",
      "members": [
        "user:old@example.com"
      ]
    }
  ]
}
JSON
    }
  }

  assert {
    condition     = contains(local.project_iam_bindings_combined["roles/viewer"].members, "serviceAccount:deployer@cf-unit-test.iam.gserviceaccount.com")
    error_message = "Service-account project roles must merge with the explicitly requested project policy."
  }

  assert {
    condition = (
      toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.serviceAccountTokenCreator"].members) == toset(["user:operator@example.com"]) &&
      toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.serviceAccountUser"].members) == toset(["user:existing@example.com"])
    )
    error_message = "Service-account IAM must deduplicate and filter authoritative bindings while keeping non-authoritative roles."
  }
}
