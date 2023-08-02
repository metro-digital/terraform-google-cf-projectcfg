# Copyright 2023 METRO Digital GmbH
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

# Grant the manager group additional roles for the bootstrapping
# phase. This causes a little "flapping" of the roles assigned to the
# manager group between this execution and the execution of the
# generated Terraform code in later stage, but is still required
# and accepted as a minor inconvenience.
resource "google_project_iam_member" "manager_group" {
  for_each = toset(local.manager_group_iam_roles)

  role    = each.key
  member  = "group:${var.manager_group}"
  project = var.project
}

# Enable GCP project services.
resource "google_project_service" "this" {
  for_each = toset(local.project_services)

  project                    = var.project
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false

  depends_on = [google_project_iam_member.manager_group]
}

# Create the Terraform IaC service account for impersonation
# in the second stage, where generated Terraform code is executed.
resource "google_service_account" "this" {
  account_id   = var.terraform_sa_name
  display_name = "Service account used in IaC pipelines"
  project      = var.project

  depends_on = [
    google_project_iam_member.manager_group,
    google_project_service.this,
  ]
}

# Grant the Terraform IaC service account IAM roles.
resource "google_project_iam_member" "service_account" {
  for_each = toset(local.terraform_service_account_iam_roles)

  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
  project = var.project

  depends_on = [
    google_project_iam_member.manager_group,
    google_project_service.this,
    google_service_account.this,
  ]
}

# Enable service identity for the service networking API.
resource "google_project_service_identity" "this" {
  provider = google-beta

  project = var.project
  service = "servicenetworking.googleapis.com"

  depends_on = [
    google_project_iam_member.manager_group,
    google_project_service.this,
    google_service_account.this,
    google_project_iam_member.service_account,
  ]
}

# Grant the Service Identity service account IAM roles.
resource "google_project_iam_member" "service_account_identity" {
  for_each = toset(local.identity_service_account_iam_roles)

  role    = each.key
  member  = "serviceAccount:${google_project_service_identity.this.email}"
  project = var.project

  depends_on = [
    google_project_iam_member.manager_group,
    google_project_service.this,
    google_service_account.this,
    google_project_iam_member.service_account,
    google_project_service_identity.this,
  ]
}

# Grant the manager group IAM roles for the Terraform IaC
# service account impersonation.
resource "google_service_account_iam_member" "this" {
  for_each = toset(local.manager_group_service_account_iam_roles)

  role               = each.key
  member             = "group:${var.manager_group}"
  service_account_id = google_service_account.this.name

  depends_on = [
    google_project_iam_member.manager_group,
    google_project_service.this,
    google_service_account.this,
    google_project_iam_member.service_account,
    google_project_service_identity.this,
    google_project_iam_member.service_account_identity,
  ]
}

# Create storage bucket for Terraform IaC state.
resource "google_storage_bucket" "this" {
  name          = var.terraform_state_bucket
  location      = "EU"
  force_destroy = true
  project       = var.project

  uniform_bucket_level_access = true

  storage_class = "MULTI_REGIONAL"

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 30
    }
  }

  depends_on = [
    google_service_account_iam_member.this,
  ]
}

# Sleep to give GCP the time to synchronise the IAM changes
# executed earlier to avoid IAM related errors when executing
# the generated Terraform code using Terraform IaC service account.
# Triggers only on change of the roles list and storage bucket creation
# to avoid executing the delay on subsequent executions.
resource "time_sleep" "this" {

  create_duration = var.time_sleep

  triggers = {
    services_md5 = md5(join(",", concat(local.manager_group_iam_roles, tolist([google_storage_bucket.this.id]))))
  }

  depends_on = [
    google_project_iam_member.manager_group,
    google_project_service.this,
    google_service_account.this,
    google_project_iam_member.service_account,
    google_project_service_identity.this,
    google_project_iam_member.service_account_identity,
    google_storage_bucket.this,
  ]
}
