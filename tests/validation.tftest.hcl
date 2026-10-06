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

run "invalid_project_id" {
  command = plan
  variables { project_id = "INVALID" }
  expect_failures = [var.project_id]
}

run "missing_panel_labels" {
  command = plan
  override_data {
    target = data.google_project.this
    values = { labels = {} }
  }
  expect_failures = [data.google_project.this]
}

run "unknown_panel_environment" {
  command = plan
  override_data {
    target = data.google_project.this
    values = {
      labels = {
        cf_mesh_env        = "unknown"
        cf_customer_id     = "customer"
        cf_project_id      = "application"
        cf_landing_zone_id = "applications-prod-eu"
      }
    }
  }
  expect_failures = [data.google_project.this]
}

run "region_outside_landing_zone" {
  command = plan
  variables { vpc_regions = { asia-east1 = {} } }
  expect_failures = [var.vpc_regions]
}

run "invalid_nat_mode" {
  command = plan
  variables { vpc_regions = { europe-west1 = { nat = { mode = "INVALID" } } } }
  expect_failures = [var.vpc_regions]
}

run "manual_nat_without_ips" {
  command = plan
  variables { vpc_regions = { europe-west1 = { nat = { mode = "MANUAL", num_ips = 0 } } } }
  expect_failures = [var.vpc_regions]
}

run "manual_nat_too_many_ips" {
  command = plan
  variables { vpc_regions = { europe-west1 = { nat = { mode = "MANUAL", num_ips = 301 } } } }
  expect_failures = [var.vpc_regions]
}

run "invalid_github_repository" {
  command = plan
  variables {
    service_accounts = {
      deployer = {
        display_name               = "Deployer"
        github_action_repositories = ["invalid-repository"]
      }
    }
  }
  expect_failures = [google_service_account.service_accounts["deployer"]]
}
