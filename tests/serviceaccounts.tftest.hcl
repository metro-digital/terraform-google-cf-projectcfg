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

mock_provider "google" {
  source = "./tests/mocks"
}
mock_provider "google-beta" {
  source = "./tests/mocks"
}
variables {
  project_id = "cf-unit-test"
}

run "empty_project" {
  command = plan

  override_data {
    target = data.google_service_accounts.this[0]
    values = { accounts = [] }
  }
  assert {
    condition     = length(local.unmanaged_service_account_emails) == 0
    error_message = "Unexpected unmanaged service-account classification."
  }
}

run "configured_accounts" {
  command = plan
  variables { service_accounts = { deployer = { display_name = "Deployment" } } }
  override_data {
    target = data.google_service_accounts.this[0]
    values = { accounts = [
      {
        email        = "deployer@cf-unit-test.iam.gserviceaccount.com"
        account_id   = "deployer"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:deployer@cf-unit-test.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/deployer@cf-unit-test.iam.gserviceaccount.com"
        unique_id    = "100000000000000000000"
      },
    ] }
  }
  assert {
    condition     = length(local.unmanaged_service_account_emails) == 0
    error_message = "Unexpected unmanaged service-account classification."
  }
}

run "google_managed_accounts" {
  command = plan

  override_data {
    target = data.google_service_accounts.this[0]
    values = { accounts = [
      {
        email        = "123456789012-compute@developer.gserviceaccount.com"
        account_id   = "123456789012-compute"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:123456789012-compute@developer.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/123456789012-compute@developer.gserviceaccount.com"
        unique_id    = "100000000000000000000"
      },
      {
        email        = "123456789012@cloudservices.gserviceaccount.com"
        account_id   = "123456789012"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:123456789012@cloudservices.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/123456789012@cloudservices.gserviceaccount.com"
        unique_id    = "100000000000000000001"
      },
      {
        email        = "service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com"
        account_id   = "service-123456789012"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com"
        unique_id    = "100000000000000000002"
      },
      {
        email        = "service-123456789012@compute-system.iam.gserviceaccount.com"
        account_id   = "service-123456789012"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:service-123456789012@compute-system.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/service-123456789012@compute-system.iam.gserviceaccount.com"
        unique_id    = "100000000000000000003"
      },
      {
        email        = "service-123456789012@service-networking.iam.gserviceaccount.com"
        account_id   = "service-123456789012"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:service-123456789012@service-networking.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/service-123456789012@service-networking.iam.gserviceaccount.com"
        unique_id    = "100000000000000000004"
      },
      {
        email        = "service-agent-manager@system.gserviceaccount.com"
        account_id   = "service-agent-manager"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:service-agent-manager@system.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/service-agent-manager@system.gserviceaccount.com"
        unique_id    = "100000000000000000005"
      },
    ] }
  }
  assert {
    condition     = length(local.unmanaged_service_account_emails) == 0
    error_message = "Unexpected unmanaged service-account classification."
  }
}

run "unexpected_accounts_warn" {
  command = plan
  variables { service_accounts = { deployer = { display_name = "Deployment" } } }
  override_data {
    target = data.google_service_accounts.this[0]
    values = { accounts = [
      {
        email        = "z-unmanaged@cf-unit-test.iam.gserviceaccount.com"
        account_id   = "z-unmanaged"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:z-unmanaged@cf-unit-test.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/z-unmanaged@cf-unit-test.iam.gserviceaccount.com"
        unique_id    = "100000000000000000000"
      },
      {
        email        = "deployer@cf-unit-test.iam.gserviceaccount.com"
        account_id   = "deployer"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:deployer@cf-unit-test.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/deployer@cf-unit-test.iam.gserviceaccount.com"
        unique_id    = "100000000000000000001"
      },
      {
        email        = "a-unmanaged@cf-unit-test.iam.gserviceaccount.com"
        account_id   = "a-unmanaged"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:a-unmanaged@cf-unit-test.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/a-unmanaged@cf-unit-test.iam.gserviceaccount.com"
        unique_id    = "100000000000000000002"
      },
      {
        email        = "service-custom@cf-unit-test.iam.gserviceaccount.com"
        account_id   = "service-custom"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:service-custom@cf-unit-test.iam.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/service-custom@cf-unit-test.iam.gserviceaccount.com"
        unique_id    = "100000000000000000003"
      },
      {
        email        = "123456789012-compute@developer.gserviceaccount.com"
        account_id   = "123456789012-compute"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:123456789012-compute@developer.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/123456789012-compute@developer.gserviceaccount.com"
        unique_id    = "100000000000000000004"
      },
    ] }
  }
  expect_failures = [check.unmanaged_service_accounts]
  assert {
    condition     = local.unmanaged_service_account_emails == tolist(["a-unmanaged@cf-unit-test.iam.gserviceaccount.com", "service-custom@cf-unit-test.iam.gserviceaccount.com", "z-unmanaged@cf-unit-test.iam.gserviceaccount.com"])
    error_message = "Unexpected unmanaged service-account classification."
  }
}

run "other_default_accounts_warn" {
  command = plan

  override_data {
    target = data.google_service_accounts.this[0]
    values = { accounts = [
      {
        email        = "cf-unit-test@appspot.gserviceaccount.com"
        account_id   = "cf-unit-test"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:cf-unit-test@appspot.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/cf-unit-test@appspot.gserviceaccount.com"
        unique_id    = "100000000000000000000"
      },
      {
        email        = "999999999999-compute@developer.gserviceaccount.com"
        account_id   = "999999999999-compute"
        disabled     = false
        display_name = ""
        member       = "serviceAccount:999999999999-compute@developer.gserviceaccount.com"
        name         = "projects/cf-unit-test/serviceAccounts/999999999999-compute@developer.gserviceaccount.com"
        unique_id    = "100000000000000000001"
      },
    ] }
  }
  expect_failures = [check.unmanaged_service_accounts]
  assert {
    condition     = length(local.unmanaged_service_account_emails) == 2
    error_message = "Unexpected unmanaged service-account classification."
  }
}

run "disabled_check_skips_lookup" {
  command = plan
  variables {
    disable_unmanaged_service_accounts_check = true
  }
  assert {
    condition     = length(data.google_service_accounts.this) == 0 && length(local.unmanaged_service_account_emails) == 0
    error_message = "Disabling the check must skip account discovery entirely."
  }
}
