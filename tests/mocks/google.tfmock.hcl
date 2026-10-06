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

# Deterministic inputs for module logic; no Google API calls are made.
mock_data "google_project" {
  defaults = {
    number = "123456789012"
    labels = {
      cf_mesh_env        = "prod"
      cf_customer_id     = "customer"
      cf_project_id      = "application"
      cf_landing_zone_id = "applications-prod-eu"
    }
  }
}

mock_data "google_project_iam_policy" {
  defaults = {
    policy_data = "{\"bindings\":[]}"
  }
}

mock_data "google_service_account_iam_policy" {
  defaults = {
    policy_data = "{\"bindings\":[]}"
  }
}

mock_data "google_netblock_ip_ranges" {
  defaults = {
    cidr_blocks = ["35.235.240.0/20"]
  }
}

# Stable computed identities for service-account IAM and federation assertions.
# Service-account scenarios use a single account named deployer.
mock_resource "google_service_account" {
  defaults = {
    id     = "projects/cf-unit-test/serviceAccounts/deployer@cf-unit-test.iam.gserviceaccount.com"
    name   = "projects/cf-unit-test/serviceAccounts/deployer@cf-unit-test.iam.gserviceaccount.com"
    email  = "deployer@cf-unit-test.iam.gserviceaccount.com"
    member = "serviceAccount:deployer@cf-unit-test.iam.gserviceaccount.com"
  }
}

mock_resource "google_iam_workload_identity_pool" {
  defaults = {
    name = "projects/123456789012/locations/global/workloadIdentityPools/unit-test"
  }
}

# google_iam_policy normally serializes bindings locally. Mock its JSON output
# and assert the module's composed bindings instead of the mocked serialization.
mock_data "google_iam_policy" {
  defaults = {
    policy_data = "{\"bindings\":[]}"
  }
}
