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

# Both providers are mocked; these tests make no Google API calls.
mock_provider "google" {
  source = "./tests/mocks"
}

mock_provider "google-beta" {
  source = "./tests/mocks"
}

variables {
  project_id = "cf-unit-test"
}

run "minimal_project" {
  command = plan

  assert {
    condition     = toset(keys(google_project_service.this)) == toset(["iam.googleapis.com", "servicenetworking.googleapis.com"])
    error_message = "A minimal project must enable only the two base APIs."
  }

  assert {
    condition     = alltrue([for service in google_project_service.this : !service.disable_on_destroy])
    error_message = "APIs must remain enabled on destroy by default."
  }

  assert {
    condition = (
      length(google_compute_network.default) == 0 &&
      length(google_compute_subnetwork.default) == 0 &&
      length(google_compute_router_nat.nat) == 0 &&
      length(google_compute_firewall.allow_ssh_iap) == 0 &&
      length(google_compute_firewall.allow_rdp_iap) == 0 &&
      length(google_dns_policy.logging) == 0
    )
    error_message = "No VPC-related resources should exist unless regions are requested."
  }

  assert {
    condition = (
      length(google_project_service.wif) == 0 &&
      length(google_iam_workload_identity_pool.github_actions) == 0 &&
      length(google_iam_workload_identity_pool.runtime_k8s) == 0 &&
      length(google_iam_workload_identity_pool.meshstack_buildingblocks) == 0 &&
      length(google_service_account.service_accounts) == 0 &&
      length(google_project_service.essential_contacts) == 0
    )
    error_message = "Optional identity and contact resources must be disabled by default."
  }

  assert {
    condition     = output.project_id == "cf-unit-test" && length(output.vpc.subnetworks) == 0
    error_message = "Outputs must identify the existing project and expose an empty VPC."
  }

  assert {
    condition = toset(local.project_iam_bindings_combined["roles/browser"].members) == toset([
      "group:customer.application-manager@cloudfoundation.metro.digital",
      "group:customer.application-developer@cloudfoundation.metro.digital",
      "group:customer.application-observer@cloudfoundation.metro.digital",
    ])
    error_message = "Cloud Foundation browser access must include all three panel groups."
  }
}

run "additional_services" {
  command = plan

  variables {
    enabled_services                    = ["storage.googleapis.com", "iam.googleapis.com", "storage.googleapis.com"]
    enabled_services_disable_on_destroy = true
  }

  assert {
    condition     = toset(keys(google_project_service.this)) == toset(["iam.googleapis.com", "servicenetworking.googleapis.com", "storage.googleapis.com"])
    error_message = "Additional APIs must be merged with the base APIs and deduplicated."
  }

  assert {
    condition     = alltrue([for service in google_project_service.this : service.disable_on_destroy])
    error_message = "The explicit API disable-on-destroy setting must be honored."
  }
}

run "non_panel_project" {
  command = plan

  variables {
    non_cf_panel_project = true
  }

  override_data {
    target = data.google_project.this
    values = { labels = {}, number = "123456789012" }
  }

  assert {
    condition     = !contains(keys(local.project_iam_bindings_combined), "roles/browser")
    error_message = "Non-panel projects must not receive Cloud Foundation group bindings."
  }

  assert {
    condition     = contains(local.project_iam_bindings_combined["roles/editor"].members, "serviceAccount:123456789012@cloudservices.gserviceaccount.com")
    error_message = "Google's default service agent must still be preserved in non-panel mode."
  }
}
