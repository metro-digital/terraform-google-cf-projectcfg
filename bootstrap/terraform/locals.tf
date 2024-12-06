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

locals {
  # manager_group_iam_roles is a list of GCP IAM roles required for
  # the members of manager_group to have the privileges allowing
  # execution of the bootstrapping step as users, without the
  # Terraform service account impersionation.
  manager_group_iam_roles = [
    "roles/iam.serviceAccountAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ]

  # project_services is a list of GCP services to be enabled
  # in every bootstrapped project by default.
  project_services = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage-component.googleapis.com",
  ]

  # terraform_service_account_iam_roles is a list of GCP IAM roles
  # required for the Terraform IaC service account to have the privileges
  # allowing management of the GCP project and resources.
  terraform_service_account_iam_roles = [
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/storage.admin",
    "roles/storage.objectAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.securityAdmin",
    "roles/iam.roleAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ]

  # identity_service_account_iam_roles is a list of GCP IAM roles
  # required for the identity service account to have the privileges
  # allowing management of the GCP project networking.
  identity_service_account_iam_roles = [
    "roles/servicenetworking.serviceAgent",
  ]

  # manager_group_service_account_iam_roles is a list of GCP IAM roles
  # required for the management group to impersonate the Terraform IaC
  # service account allowing management of the GCP project and resources.
  manager_group_service_account_iam_roles = [
    "roles/iam.serviceAccountTokenCreator",
  ]

  # We build the version string to be passed to the generated terraform
  # code here based on information updated by release-please
  # We have to do it within this terraform code, as the Generic updated
  # (see https://github.com/googleapis/release-please/blob/main/docs/customizing.md)
  # does not support updating the version directly in the template. It can only update single parts of
  # a version per line, or replace the version with the full new version. As we are using the pessimistic version
  # operator, the do not want to include the patch version. So we build it here with some helper variables and
  # pass it into the template
  module_major_version = 3 # x-release-please-major
  module_minor_version = 0 # x-release-please-minor
  module_version       = "${local.module_major_version}.${local.module_minor_version}"
}
