# Copyright 2021 METRO Digital GmbH
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

variable "project_id" {
  description = "GCP project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,30}[a-z0-9]", var.project_id))
    error_message = "The ID of the project. It must be 6 to 30 lowercase letters, digits, or hyphens. It must start with a letter. Trailing hyphens are prohibited."
  }
}

variable "enabled_services" {
  description = <<-EOD
    List of GCP enabled services / APIs to enable. Dependencies will be enabled automatically.
    The modules does not provide a way to disable services (again), if you want to disable services
    you can do this manual using UI or gcloud CLI.

    **Remark**: Google sometimes changes (mostly adding) dependencies and will activate those automatically for your
    project, means being authoritative on services usually causes a lot of trouble.

    Example:
    ```
    enabled_services = [
      "bigquery.googleapis.com",
      "compute.googleapis.com",
      "cloudscheduler.googleapis.com",
      "iap.googleapis.com"
    ]
    ```
  EOD
  type        = list(string)
  default     = []
}

/**************************************************************************************************/
/*                                                                                                */
/* Network                                                                                        */
/*                                                                                                */
/**************************************************************************************************/
variable "skip_default_vpc_creation" {
  description = <<-EOD
    When set to true the module will not create the default VPC or any
    related resource like NAT Gateway or serverless VPC access configuration.
  EOD
  type        = bool
  default     = false
}

variable "vpc_regions" {
  description = <<-EOD
    Enabled regions and configuration

    Example:
    ```
    vpc_regions = {
      europe-west1 = {
        vpcaccess            = true    # Enable serverless VPC access for this region
        nat                  = 2       # Create a Cloud NAT with 2 (static) external IP addresses (IPv4) in this region
        nat_min_ports_per_vm = 64      # Minimum number of ports allocated to a VM from the NAT defined above (Note: this option is optional, but must be defined for all the regions if it is set for at least one)
      },
      europe-west3 = {
        vpcaccess            = false   # Disable serverless VPC access for this region
        nat                  = 0       # No Cloud NAT for this region
        nat_min_ports_per_vm = 0       # Since the `nat_min_ports_per_vm` was set for the region above, its definition is required here.
      },
    }
    ```
  EOD

  type = map(object({
    vpcaccess            = bool
    nat                  = number
    nat_min_ports_per_vm = optional(number)
  }))

  default = {
    europe-west1 = {
      vpcaccess = false
      nat       = 0
    }
  }
}

/**************************************************************************************************/
/*                                                                                                */
/* IAM                                                                                            */
/*                                                                                                */
/**************************************************************************************************/
variable "roles" {
  description = <<-EOD
    IAM roles and their members.

    Example:
    ```
    roles = {
      "roles/bigquery.admin" = [
        "group:example-group@metronom.com",
        "user:example-user@metronom.com",
        "serviceAccount:exmple-sa@example-prj..iam.gserviceaccount.com"
      ],
      "roles/cloudsql.admin" = [
        "group:another-example-group@metronom.com",
      ]
    }
    ```
  EOD

  type = map(list(string))
}

variable "deprivilege_compute_engine_sa" {
  description = <<-EOD
    By default the compute engine service account (*project-number*-compute@developer.gserviceaccount.com) is assigned `roles/editor`
    If you want to deprivilege the account set this to true, and grant needed permissions via roles variable.
    Otherwise the module will grant `roles/editor` to the service account.
  EOD

  type    = bool
  default = false
}

variable "custom_roles" {
  description = <<-EOD
    Create custom roles and define who gains that role on project level

    Example:
    ```
    custom_roles = {
      "appengine.applicationsCreator" = {
        title       = "AppEngine Creator",
        description = "Custom role to grant permissions for creating App Engine applications.",
        permissions = [
          "appengine.applications.create",
        ]
        members = [
          "group:example-grp@metronom.com"
        ]
      }
    }
    ```
  EOD

  type = map(object({
    title       = string
    description = string
    permissions = list(string)
    members     = list(string)
  }))

  default = {}
}

variable "service_accounts" {
  description = <<-EOD
    Service accounts to create for this project.

    **Optional:** IAM permissions assigned to this Service Account as a *resource*. This means who else can do something
    on this Service Account. An example: if you grant `roles/iam.serviceAccountKeyAdmin` to a group here, this group
    will be able to maintain Service Account keys for this specific SA. If you want to allow this SA to use BigQuery
    you need to use the `roles` input to do so.

    Example:
    ```
      service_accounts = {
        deployments = {
          display_name = "Deployments"
          description  = "Service Account to deploy application"
          description  = "
          iam          = {
            "roles/iam.serviceAccountKeyAdmin" = [
              "group:deployment-admins@metronom.com"
            ]
          }
        }
        bq-reader = {
          display_name = "BigQuery Reader"
          description  = "Service Account for BigQuery Reader for App XYZ"
          iam          = {} # No special Service Account resource IAM permissions
        }
      }
    }
    ```
  EOD

  type = map(object({
    display_name = string
    description  = optional(string)
    iam          = map(list(string))
  }))

  default = {}
}

variable "non_authoritative_roles" {
  description = <<-EOD
    List of roles (regex) to exclude from authoritative project IAM handling.
    Roles listed here can have bindings outside of this module.

    Example:
    ```
    non_authoritative_roles = [
      "roles/container.hostServiceAgentUser"
    ]
    ```
  EOD
  type        = list(string)
  default     = []
}
