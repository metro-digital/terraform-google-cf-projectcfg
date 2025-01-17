# Copyright 2025 METRO Digital GmbH
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

# Generating Terraform IaC code for second bootstrapping stage

resource "local_file" "main_tf" {
  content = templatefile("templates/main.tf.in", {
    GCS_BUCKET   = google_storage_bucket.this.name,
    SA_FULL_NAME = google_service_account.this.email
  })
  filename = "../${var.output_dir}/main.tf"
}

resource "local_file" "provider_tf" {
  content = templatefile("templates/provider.tf.in", {
    SA_FULL_NAME = google_service_account.this.email
  })
  filename = "../${var.output_dir}/provider.tf"
}

resource "local_file" "versions_tf" {
  content  = templatefile("templates/versions.tf.in", {})
  filename = "../${var.output_dir}/versions.tf"
}

resource "local_file" "variables_tf" {
  content  = templatefile("templates/variables.tf.in", {})
  filename = "../${var.output_dir}/variables.tf"
}

resource "local_file" "outputs_tf" {
  content  = templatefile("templates/outputs.tf.in", {})
  filename = "../${var.output_dir}/outputs.tf"
}

resource "local_file" "tf_state_bucket_tf" {
  content = templatefile("templates/tf-state-bucket.tf.in", {
    GCS_BUCKET          = google_storage_bucket.this.name
    GCS_BUCKET_LOCATION = google_storage_bucket.this.location
  })
  filename = "../${var.output_dir}/tf-state-bucket.tf"
}

resource "local_file" "project_tf" {
  content = templatefile("templates/project.tf.in", {
    SA_SHORT_NAME                     = var.terraform_sa_name,
    GITHUB_REPOSITORY_IAM_ROLE_STRING = var.github_repository_iam_role_string,
    GITHUB_REPOSITORY_SA_BLOCK_STRING = var.github_repository_sa_block_string,
    MODULE_VERSION                    = local.module_version
  })
  filename = "../${var.output_dir}/project.tf"
}

resource "local_file" "locals_tf" {
  content = templatefile("templates/locals.tf.in", {
    GCP_PROJECT_ID  = var.project,
    MANAGER_GROUP   = var.manager_group,
    DEVELOPER_GROUP = var.developer_group,
    OBSERVER_GROUP  = var.observer_group,
    SA_FULL_NAME    = google_service_account.this.email
  })
  filename = "../${var.output_dir}/local.tf"
}

resource "local_file" "gitignore" {
  content  = templatefile("templates/.gitignore.in", {})
  filename = "../${var.output_dir}/.gitignore"
}

resource "local_file" "imports_tf" {
  content = templatefile("templates/imports.tf.in", {
    SA_FULL_NAME  = google_service_account.this.email,
    SA_SHORT_NAME = var.terraform_sa_name,
    PROJECT       = var.project,
    GCS_BUCKET    = google_storage_bucket.this.id,
  })
  filename = "../${var.output_dir}/imports.tf"
}
