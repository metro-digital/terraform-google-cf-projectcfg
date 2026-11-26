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

run "meshstack_legacy_federation" {
  command = apply
  variables {
    service_accounts = {
      deployer = {
        display_name = "Deployer"
        meshstack_buildingblocks = [{
          issuer    = "https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"
          audiences = ["legacy-audience"]
          subjects  = ["system:serviceaccount:customer:buildingblock"]
        }]
      }
    }
  }

  assert {
    condition = (
      google_iam_workload_identity_pool.meshstack_buildingblocks[0].workload_identity_pool_id == "meshstack-buildingblocks" &&
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"].workload_identity_pool_provider_id == md5("https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks") &&
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"].attribute_mapping["google.subject"] == "assertion.sub" &&
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"].attribute_condition == "google.subject == \"system:serviceaccount:customer:buildingblock\"" &&
      toset(google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"].oidc[0].allowed_audiences) == toset(["legacy-audience"])
    )
    error_message = "Legacy federation must retain its pool, provider ID, audience and exact subject."
  }

  assert {
    condition = toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.workloadIdentityUser"].members) == toset([
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/system:serviceaccount:customer:buildingblock",
    ])
    error_message = "Legacy service-account subjects must be preserved in IAM bindings."
  }
}

run "meshstack_identity_runner_federation" {
  command = apply
  variables {
    service_accounts = {
      deployer = {
        display_name = "Deployer"
        meshstack_buildingblocks = [
          {
            issuer    = "https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"
            audiences = ["dev-audience"]
            subjects  = ["bbd:ceg:1aaa8e5f-8d0d-4679-86dc-cd6740721632"]
          },
          {
            issuer    = "https://id.meshstack.io/realms/metro-saas-workloads"
            audiences = ["prod-audience"]
            subjects  = ["bbd:ceg:29980db7-2a61-4f01-bf6b-18ea61606700"]
          }
        ]
      }
    }
  }

  assert {
    condition = (
      toset(keys(google_iam_workload_identity_pool_provider.meshstack_buildingblocks)) == toset(["https://id-dev.meshstack.io/realms/metro-qa-saas-workloads", "https://id.meshstack.io/realms/metro-saas-workloads"]) &&
      alltrue([for issuer, provider in google_iam_workload_identity_pool_provider.meshstack_buildingblocks : provider.workload_identity_pool_provider_id == md5(issuer) && provider.oidc[0].issuer_uri == issuer && provider.attribute_mapping["google.subject"] == "assertion.sub"]) &&
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"].attribute_condition == "google.subject == \"bbd:ceg:1aaa8e5f-8d0d-4679-86dc-cd6740721632\"" &&
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id.meshstack.io/realms/metro-saas-workloads"].attribute_condition == "google.subject == \"bbd:ceg:29980db7-2a61-4f01-bf6b-18ea61606700\"" &&
      toset(google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"].oidc[0].allowed_audiences) == toset(["dev-audience"]) &&
      toset(google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id.meshstack.io/realms/metro-saas-workloads"].oidc[0].allowed_audiences) == toset(["prod-audience"])
    )
    error_message = "Identity runner providers must retain exact issuer, ID, audience and subject mappings."
  }

  assert {
    condition = toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.workloadIdentityUser"].members) == toset([
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/bbd:ceg:1aaa8e5f-8d0d-4679-86dc-cd6740721632",
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/bbd:ceg:29980db7-2a61-4f01-bf6b-18ea61606700",
    ])
    error_message = "Identity runner subjects must be preserved in IAM bindings."
  }
}

run "meshstack_mixed_federation" {
  command = apply
  override_resource {
    target = google_service_account.service_accounts["other-sa"]
    values = {
      id     = "projects/cf-unit-test/serviceAccounts/other-sa@cf-unit-test.iam.gserviceaccount.com"
      name   = "projects/cf-unit-test/serviceAccounts/other-sa@cf-unit-test.iam.gserviceaccount.com"
      email  = "other-sa@cf-unit-test.iam.gserviceaccount.com"
      member = "serviceAccount:other-sa@cf-unit-test.iam.gserviceaccount.com"
    }
  }

  variables {
    service_accounts = {
      deployer = {
        display_name = "Deployer"
        meshstack_buildingblocks = [
          {
            issuer    = "https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"
            audiences = ["legacy-audience"]
            subjects  = ["system:serviceaccount:customer:buildingblock"]
          },
          {
            issuer    = "https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"
            audiences = ["runner-audience", "runner-audience"]
            subjects  = ["bbd:ceg:1aaa8e5f-8d0d-4679-86dc-cd6740721632"]
          }
        ]
      }
      other-sa = {
        display_name = "Other"
        meshstack_buildingblocks = [{
          issuer    = "https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"
          audiences = ["runner-audience", "other-audience"]
          subjects  = ["bbd:ceg:29980db7-2a61-4f01-bf6b-18ea61606700"]
        }]
      }
    }
  }

  assert {
    condition = (
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://container.googleapis.com/v1/projects/legacy/locations/europe-west1/clusters/buildingblocks"].attribute_condition == "google.subject == \"system:serviceaccount:customer:buildingblock\"" &&
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"].attribute_condition == "google.subject == \"bbd:ceg:1aaa8e5f-8d0d-4679-86dc-cd6740721632\" || google.subject == \"bbd:ceg:29980db7-2a61-4f01-bf6b-18ea61606700\"" &&
      tolist(google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id-dev.meshstack.io/realms/metro-qa-saas-workloads"].oidc[0].allowed_audiences) == tolist(["runner-audience", "other-audience"])
    )
    error_message = "Mixed identities must remain restricted to their configured issuer and audiences."
  }

  assert {
    condition = (
      toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.workloadIdentityUser"].members) == toset([
        "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/system:serviceaccount:customer:buildingblock",
        "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/bbd:ceg:1aaa8e5f-8d0d-4679-86dc-cd6740721632",
      ]) &&
      toset(local.service_accounts_iam_bindings_combined["other-sa"]["roles/iam.workloadIdentityUser"].members) == toset([
        "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/bbd:ceg:29980db7-2a61-4f01-bf6b-18ea61606700",
      ])
    )
    error_message = "Mixed identities must retain their per-service-account IAM scope."
  }
}

run "meshstack_escaped_subject" {
  command = apply
  variables {
    service_accounts = {
      deployer = {
        display_name = "Deployer"
        meshstack_buildingblocks = [{
          issuer    = "https://id.meshstack.io/realms/metro-saas-workloads"
          audiences = ["runner-audience"]
          subjects  = ["runner:'quoted'\\identity"]
        }]
      }
    }
  }

  assert {
    condition = (
      google_iam_workload_identity_pool_provider.meshstack_buildingblocks["https://id.meshstack.io/realms/metro-saas-workloads"].attribute_condition == "google.subject == \"runner:'quoted'\\\\identity\"" &&
      toset(local.service_accounts_iam_bindings_combined["deployer"]["roles/iam.workloadIdentityUser"].members) == toset([
        "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/unit-test/subject/runner:'quoted'\\identity",
      ])
    )
    error_message = "Subject literals must be safely escaped in CEL and preserved unchanged in IAM."
  }
}
