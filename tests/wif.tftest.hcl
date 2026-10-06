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
  service_accounts = {
    deployer = {
      display_name               = "Deployer"
      github_action_repositories = ["metro-digital/application", "metro-digital/infrastructure"]
    }
  }
}

run "github_federation" {
  command = apply

  assert {
    condition     = length(google_iam_workload_identity_pool.github_actions) == 1 && google_iam_workload_identity_pool_provider.github[0].attribute_condition == "assertion.repository_owner in [\"metro-digital\"]"
    error_message = "GitHub federation must create one pool and deduplicate repository owners in the default condition."
  }

  assert {
    condition = toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.workloadIdentityUser"].members) == toset([
      "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/attribute.repository/metro-digital/application",
      "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/attribute.repository/metro-digital/infrastructure",
    ])
    error_message = "Workload identity access must be scoped to each configured repository."
  }

  assert {
    condition     = toset(keys(google_project_service.wif)) == toset(["cloudresourcemanager.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com"]) && alltrue([for service in google_project_service.wif : !service.disable_on_destroy])
    error_message = "Federation must enable the three required APIs and retain them on destroy."
  }
}

run "custom_github_condition" {
  command = apply
  variables { workload_identity_pool_attribute_condition = "assertion.repository_owner_id == '1234'" }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_condition == "assertion.repository_owner_id == '1234'"
    error_message = "An explicit GitHub attribute condition must override the generated default."
  }
}

run "runtime_federation" {
  command = apply
  variables {
    service_accounts = {
      deployer = {
        display_name = "Deployer"
        runtime_service_accounts = [
          { cluster_id = "runtime-test", namespace = "app", service_account = "backend" },
          { cluster_id = "runtime-test", namespace = "app", service_account = "frontend" },
        ]
      }
    }
  }

  assert {
    condition     = toset(keys(google_iam_workload_identity_pool.runtime_k8s)) == toset(["runtime-test"]) && google_iam_workload_identity_pool.runtime_k8s["runtime-test"].workload_identity_pool_id == md5("runtime-test") && length(google_iam_workload_identity_pool.github_actions) == 0
    error_message = "Runtime federation must deduplicate clusters and create stable pool IDs without a GitHub pool."
  }

  assert {
    condition = google_iam_workload_identity_pool_provider.runtime_k8s_cluster["runtime-test"].oidc[0].issuer_uri == "https://storage.googleapis.com/runtime-test-wif-bucket" && toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.workloadIdentityUser"].members) == toset([
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/system:serviceaccount:app:backend",
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/system:serviceaccount:app:frontend",
    ])
    error_message = "Runtime federation must use the cluster issuer and namespace/service-account-specific subjects."
  }
}
