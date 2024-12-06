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

    **Remark**: Google sometimes changes (mostly adding) dependencies and will activate those automatically for your
    project. Therefore being authoritative on services usually causes a lot of trouble. The module doesn't provide any
    option to be authoritative for this reason. By default we are partly authoritative. This can can be controlled
    by the `enabled_services_disable_on_destroy` flag.

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

variable "enabled_services_disable_on_destroy" {
  description = <<-EOD
    If true, try to disable a service given via `enabled_services` after its removal from from the list.
    Defaults to true. May be useful in the event that a project is long-lived but the infrastructure running in
    that project changes frequently.

    Can result in failing terraform runs if the removed service is a dependency for any other active service.
  EOD
  type        = bool
  default     = true
}

/**************************************************************************************************/
/*                                                                                                */
/* Network                                                                                        */
/*                                                                                                */
/**************************************************************************************************/
variable "skip_default_vpc_creation" {
  description = <<-EOD
    When set to true the module will not create the default VPC or any
    related resource like NAT Gateway, firewall rules or Serverless VPC access configuration.
  EOD
  type        = bool
  default     = false
}

variable "firewall_rules" {
  description = <<-EOD
    The module will create default firewall rules unless `skip_default_vpc_creation` is set to `true`

    The following rules are created by default:
      - **`allow_ssh_iap`:** A firewall rule allowing SSH via IAP if the network tag `fw-allow-ssh-iap`
        is set on an Compute Instance
      - **`allow_rdp_iap`:** A firewall rule allowing SSH via IAP if the network tag `fw-allow-rdp-iap`
        is set on an Compute Instance

    The following additional rules are available if explicitly enabled:
      - **`all_internal`:** A firewall rule allowing all kinds of traffic inside the VPC

    Example:
    ```
    # Disable IAP RDP rule rule, keep default for all other rules
    firewall_rules = {
      allow_rdp_iap = false
    }
    ```
  EOD
  type = object({
    all_internal  = optional(bool, false)
    allow_ssh_iap = optional(bool, true)
    allow_rdp_iap = optional(bool, true)
  })
  default = {}
}

variable "vpc_regions" {
  description = <<-EOD
    Enabled regions and configuration

    Example:
    ```
    vpc_regions = {
      europe-west1 = {  # Create a subnetwork in europe-west1
        vpcaccess            = true    # Enable serverless VPC access for this region
        nat                  = 2       # Create a Cloud NAT with 2 (static) external IP addresses (IPv4) in this region
        nat_min_ports_per_vm = 64      # Minimum number of ports allocated to a VM from the NAT defined above (Note: this option is optional, but must be defined for all the regions if it is set for at least one)
        gke_secondary_ranges = true    # Create secondary IP ranges used by GKE with VPC-native clusters (gke-services & gke-pods)
        proxy_only           = true    # Create an additional "proxy-only" network in this region used by L7 load balancers
      },
      europe-west4 = {  # Create a subnetwork in europe-west4
        vpcaccess            = false   # Disable serverless VPC access for this region
        nat                  = 0       # No Cloud NAT for this region
        nat_min_ports_per_vm = 0       # Since the `nat_min_ports_per_vm` was set for the region above, its definition is required here.
        gke_secondary_ranges = false   # Since the `gke_secondary_ranges` was set for the region above, its definition is required here.
        proxy_only           = false   # Since the `proxy_only` was set for the region above, its definition is required here.
      },
    }
    ```

    By default the module will create a subnetwork in europe-west1 but do not launch any additional features like
    NAT or VPC access. Secondary ranges for GKE are disabled, too.
  EOD

  type = map(object({
    vpcaccess            = bool
    nat                  = number
    nat_min_ports_per_vm = optional(number)
    gke_secondary_ranges = optional(bool)
    proxy_only           = optional(bool)
  }))

  default = {
    europe-west1 = {
      vpcaccess = false
      nat       = 0
    }
  }

  validation {
    condition = length(setsubtract(keys(var.vpc_regions), [
      "europe-west1",
      "europe-west3",
      "europe-west4",
      "europe-west8",
      "europe-west9",
      "europe-north1",
      "europe-central2",
      "europe-southwest1"
    ])) == 0
    error_message = "Invalid region given, must be any of: europe-west1, europe-west3, europe-west4, europe-west8, europe-west9, europe-north1, europe-central2 or europe-southwest1."
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

    If you create a service account in this project via the `service_accounts` input, we recommend
    to use the `project_roles` attribute of the respective service account to grant it permissions
    on the project's IAM policy. This allows you to better re-use your code in staged environments.

    Example:
    ```
    roles = {
      "roles/bigquery.admin" = [
        "group:customer.project-role@cloudfoundation.metro.digital",
        "user:some.user@metro.digital",
      ],
      "roles/cloudsql.admin" = [
        "group:customer.project-role@cloudfoundation.metro.digital",
      ]
    }
    ```
  EOD

  type = map(list(string))
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
          "group:customer.project-role@cloudfoundation.metro.digital",
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

    **`display_name`:** Human-readable name shown in Google Cloud Console

    **`description` (optional):** Human-readable description shown in Google Cloud Console

    **`iam` (optional):** IAM permissions assigned to this Service Account as a *resource*. This defines which principal
    can do something on this Service Account. An example: If you grant `roles/iam.serviceAccountKeyAdmin` to a group
    here, this group will be able to maintain Service Account keys for this specific SA. If you want to allow this SA to
    use BigQuery, you need to use the project-wide `roles` input or, even better, use the `project_roles` attribute to
    do so.

    **`project_roles` (optional):** IAM permissions assigned to this Service Account on *project level*.
    This parameter is merged with whatever is provided as the project's IAM policy via the `roles` input.

    **`iam_non_authoritative_roles` (optional):** Any role given in this list will be added to the authoritative policy
    with its current value as defined in the Google Cloud Platform. Example use case: Composer 2 adds values to
    `roles/iam.workloadIdentityUser` binding when an environment is created or updated. Thus, you might want to
    automatically import those permissions.

    **`runtime_service_accounts` (optional):** You can list Kubernetes Service Accounts within Cloud Native Runtime
    clusters here. For details on the format, see the example below. A Workload Identity Pool and a Workload Identity
    Provider needed for Workload Identity Federation will be created automatically. Each service account given gains
    permissions to authenticate as this service account using Workload Identity Federation. This allows workloads running
    in Cloud Native Runtime clusters to use this service account without the need for service account keys. A detailed
    example can be found within the [FAQ].

    **`github_action_repositories` (optional):** You can list GitHub repositories (format: `user/repo`) here.
    A Workload Identity Pool and a Workload Identity Provider needed for Workload Identity Federation will be
    created automatically. Each repository given gains permissions to authenticate as this service account using
    Workload Identity Federation. This allows any GitHub Action pipeline to use this service account without the need
    for service account keys. An example can be found within the [FAQ].

    For more details, see the documentation for Google's GitHub action for authentication:
    [`google-github-actions/auth`](https://github.com/google-github-actions/auth).

    **Remark:** If you configure `github_action_repositories`, the module binds a member for each repository to the role
    `roles/iam.workloadIdentityUser` inside the service account's IAM policy. This is done *regardless of whether
    or not* you list this role in the `iam_non_authoritative_roles` key. The same happens if you use
    `runtime_service_accounts`. A member per runtime service account is added to the service account's IAM policy.

    **Remark:** You need to grant the role `roles/iam.workloadIdentityPoolAdmin` to the principal that is
    executing the terraform code (most likely a service account used in a pipeline) if you plan to use
    `github_action_repositories` or `runtime_service_accounts`.

    Example:
    ```
      service_accounts = {
        runtime-sa = {
          display_name  = "My Runtime Workload"
          description   = "Workload running in Cloud Native Runtime Cluster"

          # Grant this service account to execute BigQuery jobs
          # access to certain datasets is configured in dataset IAM policy
          project_roles = [
            "roles/bigquery.jobUser"
          ]
          runtime_service_accounts = [
            # You can specify multiple of the following objects if needed
            {
              cluster_id      = "mycluster-id-1"
              namespace       = "some-namespace"
              service_account = "some-service-account-name"
            }
          ]
        }
        deployments = {
          display_name  = "Deployments"
          description   = "Service Account to deploy application"

          # Grant this service account Cloud Run Admin on project level
          project_roles = [
            "roles/run.admin"
          ]

          # Allow specific group to create keys for this Service Account only
          iam = {
            "roles/iam.serviceAccountKeyAdmin" = [
              "group:customer.project-role@cloudfoundation.metro.digital",
            ]
          }

          # This service account will be used by GitHub Action deployments in the given repository
          github_action_repositories = [
            "my-user-or-organisation/my-great-repo"
          ]
        }
        bq-reader = {
          display_name = "BigQuery Reader"
          description  = "Service Account for BigQuery Reader for App XYZ"
          iam          = {} # No special Service Account resource IAM permissions
        }
        composer = {
          display_name                = "Composer"
          description                 = "Service Account to run Composer 2"
          iam                         = {} # No special Service Account resource IAM permissions
          iam_non_authoritative_roles = [
            # maintained by Composer service automatically - imports any existing value
            "roles/iam.workloadIdentityUser"
          ]
        }
      }
    }
    ```
  EOD

  type = map(object({
    display_name                = string
    description                 = optional(string)
    iam                         = optional(map(list(string)), {})
    project_roles               = optional(list(string))
    iam_non_authoritative_roles = optional(list(string))
    github_action_repositories  = optional(list(string), [])
    runtime_service_accounts = optional(list(object({
      cluster_id      = string
      namespace       = string
      service_account = string
    })), [])
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

variable "essential_contacts" {
  description = <<-EOD
    Essential contacts receive configurable notifications from Google Cloud Platform
    based on selected categories.

    **`language`:** The preferred language for notifications, as an ISO 639-1 language code.
    See [documentation](https://cloud.google.com/resource-manager/docs/managing-notification-contacts#supported-languages)
    for a list of supported languages.

    **`categories`:** The categories of notifications that the contact will receive communications for.
    See [documentation](https://cloud.google.com/resource-manager/docs/managing-notification-contacts#notification-categories)
    for a list of supported categories.

    **Remark:** The module will enable the essential contacts API automatically once one contact is configured.
    You still need to grant the role `roles/essentialcontacts.admin` to the principle that is executing
    the terraform code (most likely your service account used in your pipeline) if you plan to use
    `github_action_repositories`.

    Example:
    ```
    essential_contacts = {
      "some-group-mailing-list@metro.digital" = {
        language   = "en"
        categories = ["ALL"]
      }
      "some-other-group-list@metro.digital" = {
        language   = "en"
        categories = [
          "SUSPENSION",
          "TECHNICAL"
        ]
      }
    }
    ```
    EOD
  type = map(object({
    language   = string
    categories = list(string)
  }))
  default = {}
}

variable "workload_identity_pool_attribute_mapping" {
  description = <<-EOD
    Maps attributes from authentication credentials issued by an external identity provider
    to Google Cloud attributes

    **Note** Teams must be cautious before modifying the attribute mapping as it may cause
    undesired permission issues. See [documentation](https://cloud.google.com/iam/docs/configuring-workload-identity-federation#github-actions)
    Example:
    ```
    {
      "google.subject"             = "assertion.sub"
      "attribute.actor"            = "assertion.actor"
      "attribute.aud"              = "assertion.aud"
      "attribute.repository"       = "assertion.repository"
      "attribute.repository_owner" = "assertion.repository_owner"
    }
    ```

  EOD
  type        = map(any)
  default = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
}

variable "workload_identity_pool_attribute_condition" {
  description = <<-EOD
    A Common Expression Language (CEL) expression to restrict what otherwise
    valid authentication credentials issued by the provider should not be
    accepted.

    By default, credentials issued by GitHub within any organisation/user owning a repository given
    via `github_action_repositories` property of a any service account are accepted.

    You should never only rely on this condition to limit the principals who
    can get access to Google Cloud resources but e.g. explicitly limit the
    repository using the `attribute.repository` attribute of your principal
    set. This is done automatically if you use the `github_action_repositories`
    property of a service account managed by this module.

    If the repository of your GitHub workflow runs in a different GitHub
    organisation, make sure to provide a valid CEL expression which allows
    workflows from your organisation. A list of all METRO-owned organisations
    can be obtained from [METRO's GitHub Enterprise](https://github.com/enterprises/metro-digital/organizations).
  EOD

  type     = string
  nullable = true
  default  = null
}
