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

variable "manager_group" {
  description = "Name of the manager group to grant the IAM roles to."
  type        = string
}

variable "developer_group" {
  description = "Name of the developer group to grant the IAM roles to."
  type        = string
}

variable "observer_group" {
  description = "Name of the observer group to grant the IAM roles to."
  type        = string
}

variable "project" {
  description = "ID of the GCP project to work on."
  type        = string
}

variable "terraform_sa_name" {
  description = "Name of the terraform serviceaccount to be created (default: terraform-iac-pipeline)."
  type        = string
  default     = "terraform-iac-pipeline"
}

variable "terraform_state_bucket" {
  description = "Prefix of the GCS bucket to store the Terraform state in (default: 'tf-state-<GCP_PROJECT_ID>')."
  type        = string
  default     = "tf-state"
}

variable "time_sleep" {
  description = "Time to sleep after executing IAM changes to wait for GCP sync (default: 5m)."
  type        = string
  default     = "5m"
}

variable "github_repository_iam_role_string" {
  description = "GITHUB_REPOSITORY_IAM_ROLE_STRING (default: empty string)."
  type        = string
  default     = ""
}

variable "github_repository_sa_block_string" {
  description = "GITHUB_REPOSITORY_SA_BLOCK_STRING (default: empty string)."
  type        = string
  default     = ""
}

variable "output_dir" {
  description = "Name of the directory to generate Terraform IaC code in (default: iac-output)"
  type        = string
  default     = "iac-output"
}
