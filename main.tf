# Copyright 2024 METRO Digital GmbH
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

# Get project details based on project ID and verify its a Cloud Foundation project
data "google_project" "this" {
  provider   = google
  project_id = var.project_id

  lifecycle {
    # Ensure the cf_mesh_env is set for project
    postcondition {
      condition     = contains(keys(self.labels), "cf_mesh_env")
      error_message = <<-EOE
        Missing label 'cf_mesh_env' on project '${self.project_id}'!

        Currently configured labels:
          ${indent(2, join("\n", formatlist("- %s", keys(self.labels))))}

        This module only works with Google Projects managed within the
        Cloud Foundation panel.
      EOE
    }

    postcondition {
      condition     = contains(keys(self.labels), "cf_customer_id")
      error_message = <<-EOE
        Missing label 'cf_customer_id' on project '${self.project_id}'!

        Currently configured labels:
          ${indent(2, join("\n", formatlist("- %s", keys(self.labels))))}

        This module only works with Google Projects managed within the
        Cloud Foundation panel.
      EOE
    }

    postcondition {
      condition     = contains(keys(self.labels), "cf_project_id")
      error_message = <<-EOE
        Missing label 'cf_project_id' on project '${self.project_id}'!

        Currently configured labels:
          ${indent(2, join("\n", formatlist("- %s", keys(self.labels))))}

        This module only works with Google Projects managed within the
        Cloud Foundation panel.
      EOE
    }

    postcondition {
      condition     = contains(keys(local.env_group_domain), self.labels["cf_mesh_env"])
      error_message = <<-EOE
        Unknown enviroment set in label 'cf_mesh_env' on project '${self.project_id}'!

        Currently known enviroments:
          ${indent(2, join("\n", formatlist("- %s", keys(local.env_group_domain))))}

        Please reach out to the Cloud Foundation team to report this error.
      EOE
    }
  }
}
