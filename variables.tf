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

variable "project_id" {
  description = <<-EOD
    Google Cloud project ID. The module can only be used with projects managed via the Cloud FFoundation Panel.
  EOD
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,30}[a-z0-9]", var.project_id))
    error_message = <<-EOM
      It must be 6 to 30 lowercase letters, digits, or hyphens. It must start with a letter.
      Trailing hyphens are prohibited.
    EOM
  }
}

variable "enabled_services" {
  description = <<-EOD
    List of GCP enabled services / APIs to enable. Dependencies will be enabled automatically.

    **Remark**: Google sometimes changes (mostly adding) dependencies and will activate those automatically for your
    project. Therefore being authoritative on services usually causes a lot of trouble. The module doesn't provide any
    option to be authoritative for this reason. By default it is partly authoritative, means a removed service is
    disabled when removed from this list. This can can be controlled by the `enabled_services_disable_on_destroy` flag.

    Example:
    ```
    enabled_services = [
      "bigquery.googleapis.com",
      "cloudscheduler.googleapis.com",
    ]
    ```
  EOD
  type        = list(string)
  default     = []
}

variable "enabled_services_disable_on_destroy" {
  description = <<-EOD
    If true, try to disable a service given via `enabled_services` after its removal from from the list.
    As this can result in failing terraform runs or outages, if the removed service is a dependency for any other
    actively used service the module doesn't disable any service by default.
  EOD
  type        = bool
  default     = false
}

variable "non_cf_panel_project" {
  description = <<-EOD
    By default, the module assumes that the managed project is a project created and managed via the Cloud Foundation
    Panel. It checks if certain labels (controlled by the panel) are set, and validates certain inputs like regions
    against landing zones. Additionally the module automatically authorises the Google Cloud Identity groups managed
    by the panel within the Google Cloud project's IAM policy. This ensures that there cannot be a drift between the
    authorisations enforced via the panel and the ones provisioned via this module.

    Set this input variable to `true` if you use this module to manage a Google Cloud project which was not provisioned
    by the Cloud Foundation Panel.
  EOD
  type        = bool
  default     = false
  nullable    = false
}

/**************************************************************************************************/
/*                                                                                                */
/* Network                                                                                        */
/*                                                                                                */
/**************************************************************************************************/
variable "skip_default_vpc_dns_logging_policy" {
  description = <<-EOD
    When set to true, the module will not create a DNS policy to enable DNS logging.
    As DNS logging is mandatory, you should only disable the policy creation if you plan
    to implement your own policy for further adjustments.
  EOD
  type        = bool
  default     = false
  nullable    = false
}

variable "firewall_rules" {
  description = <<-EOD
    The module will create default firewall rules if the default VPC is configured to be used within any region.

    The following rules are created by default:
      - **`allow_ssh_iap`:** A firewall rule allowing SSH via IAP if the network tag `fw-allow-ssh-iap`
        is set on an Compute Instance
      - **`allow_rdp_iap`:** A firewall rule allowing SSH via IAP if the network tag `fw-allow-rdp-iap`
        is set on an Compute Instance

    Example:
    ```
    # Disable IAP RDP rule rule, keep default for all other rules
    firewall_rules = {
      allow_rdp_iap = false
    }
    ```
  EOD
  type = object({
    allow_ssh_iap = optional(bool, true)
    allow_rdp_iap = optional(bool, true)
  })
  default = {}
}

variable "vpc_regions" {
  description = <<-EOD
    Enabled regions and configuration.

    When set to an empty map (`{}`) the module **will not** create the default VPC or any related resource
    like NAT Gateway, firewall rules or Serverless VPC Access connectors.

    For each region (key) you can configure the following optional attributes:

      **`serverless_vpc_access`:** Allows to create Serverless VPC Access Connector in in the give region.
      If set to `null` no connector is created, if set to an empty object (`serverless_vpc_access = {}`) a
      very minimal connector is created.
      The sizing can be configured via the object:

      **`serverless_vpc_access.min_instances`:** Minimum value of instances in autoscaling group underlying the
      connector. Value must be between 2 and 9, inclusive. Must be lower than the value specified by max_instances.
      Defaults to 2.

      **`serverless_vpc_access.max_instances`:** Maximum value of instances in autoscaling group underlying the
      connector. Value must be between 3 and 10, inclusive. Must be higher than the value specified by min_instances.
       Defaults to 3.

      **`serverless_vpc_access.machine_type`:** Machine type of VM Instance underlying connector. Default is `f1-micro`

      **`nat`:** Allows you to finetune your NAT configuration. Defaults to a NAT Gateway per region in automatic IP
      address allocation mode resulting in dynamic external IP addresses.
      Behavior can be configured:

      **`nat.mode`:** IP allocation mode of the NAT gateway. Can be set to `AUTO` for automatic IP allocation mode,
      `MANUAL` for static IP allocation and `DISABLED` to not configure a NAT gateway for this region.

      **`nat.num_ips`:** Number of external IP addresses to reserve for the NAT gateway. The number must be <= 300
      and > 0. The value defaults to 1 and is only considered when the `mode` attribute is set to `MANUAL`.

      **`nat.min_ports_per_vm`:** Minimum number of ports allocated to a VM from this NAT. Defaults to `null` resulting
      in 64 for static port allocation and 32 dynamic port allocation.

      **`gke_secondary_ranges`:** Create secondary ranges for GKE. Defaults to true. See [DEFAULT-VPC] documentation.

      **`proxy_only`:** Create additional proxy-only subnetwork. Defaults to true. See [DEFAULT-VPC] documentation.

    Example:
    ```
    vpc_regions = {
      # Create a subnetwork in europe-west1 with defaults
      europe-west1 = {},
      # Create a subnetwork in europe-west4 with defaults, but enable Serverless VPC Access
      europe-west4 = {
        serverless_vpc_access = {}
      },
    }
    ```
  EOD

  type = map(object({
    serverless_vpc_access = optional(object({
      min_instances = optional(number, 2)
      max_instances = optional(number, 3)
      machine_type  = optional(string, "f1-micro")
    }), null)
    nat = optional(object({
      mode             = optional(string, "AUTO")
      num_ips          = optional(number, 1)
      min_ports_per_vm = optional(number, null)
    }), {})
    gke_secondary_ranges = optional(bool, true)
    proxy_only           = optional(bool, true)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for region, conf in var.vpc_regions : contains(["AUTO", "MANUAL", "DISABLED"], conf.nat.mode)])
    error_message = <<-EOM
      Invalid NAT configuration for the following regions:
        ${indent(2, join("\n", formatlist("- %s", [for region, conf in var.vpc_regions : region if !contains(["AUTO", "MANUAL", "DISABLED"], conf.nat.mode)])))}

      nat.mode needs to be 'AUTO', 'MANUAL' or 'DISABLED'.
    EOM
  }

  validation {
    condition     = alltrue([for region, conf in var.vpc_regions : (conf.nat.mode != "MANUAL" || (conf.nat.num_ips >= 1 && conf.nat.num_ips <= 300))])
    error_message = <<-EOM
      Invalid NAT configuration for the following regions:
        ${indent(2, join("\n", formatlist("- %s", [for region, conf in var.vpc_regions : region if !(conf.nat.mode != "MANUAL" || (conf.nat.num_ips >= 1 && conf.nat.num_ips <= 300))])))}

      nat.num_ips needs to be between 1 and 300 inclusive for Gateways in MANUAL mode.
    EOM
  }

  validation {
    condition     = length(setsubtract(keys(var.vpc_regions), local.landing_zone_regions[local.cf_landing_zone_id])) == 0
    error_message = <<-EOM
      Invalid region given, your project is in landing zone '${local.cf_landing_zone_id}',
      so it must be any of the following regions:
        ${indent(2, join("\n", formatlist("- %s", local.landing_zone_regions[local.cf_landing_zone_id])))}

      Invalid region(s) given:
        ${indent(2, join("\n", formatlist("- %s", setsubtract(keys(var.vpc_regions), local.landing_zone_regions[local.cf_landing_zone_id]))))}

      Please reach out to the Cloud Foundation team if you believe this is an error. This can also be caused
      by a new region added in Google Cloud that is not yet supported by this module.
    EOM
  }
}

/**************************************************************************************************/
/*                                                                                                */
/* IAM                                                                                            */
/*                                                                                                */
/**************************************************************************************************/
variable "iam_policy" {
  description = <<-EOD
    IAM roles and their members.

    If you create a service account in this project via the `service_accounts` input variable, it's recommend
    to use the `project_iam_policy_roles` attribute of the respective service account to grant it permissions
    on the project's IAM policy. This allows better re-use your code in staged environments.

    Expected input is a list of IAM binding objects with the following attributes:

    **`role`:** The role to be granted with the binding. Can be any pre-defined or custom role. If the custom role is
    created via the `custom_roles` input variable of this module, use this variable's `project_iam_policy_members`
    attribute to assign principals to that role on project level.

    **`members`:** A list of principals the given role should be granted to.

    **`condition` (optional):**  An optional condition to be assigned to the IAM binding. For details on the condition's
    attributes see: https://cloud.google.com/iam/docs/conditions-overview#structure

    Example:
    ```
    iam_policy = [
      # Allow a group to use this project
      # as billing project for BigQuery jobs
      {
        role = "roles/bigquery.jobUser"
        members = [
          "group:group1@cloudfoundation.metro.digital",
        ]
      },
      # Same for another group, but only during working days from 07:00 till 18:59
      {
        role = "roles/bigquery.jobUser"
        members = [
          "group:group2@cloudfoundation.metro.digital",
        ]
        condition = {
          title       = "Working Hours"
          description = "Allow during working hours (Monday-Friday, 7:00 to 18:59)"
          expression  = <<-EOC
            request.time.getHours('Europe/Berlin') >= 7 &&
            request.time.getHours('Europe/Berlin') < 19 &&
            // Days of the week range from 0 to 6, where 0 == Sunday and 6 == Saturday.
            request.time.getDayOfWeek('Europe/Berlin') >= 1 &&
            request.time.getDayOfWeek('Europe/Berlin') <= 5
          EOC
        }
      }
    ]
    ```
  EOD

  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      expression  = string
      description = optional(string, null)
    }), null)
  }))

  default = []
}

variable "iam_policy_non_authoritative_roles" {
  description = <<-EOD
    List of roles (regex) to exclude from authoritative project IAM handling.
    Roles listed here can have bindings outside of this module.

    Example:
    ```
    iam_policy_non_authoritative_roles = [
      "roles/container.hostServiceAgentUser"
    ]
    ```
  EOD
  type        = list(string)
  default     = []
}

variable "iam_policy_keep_pam_bindings" {
  description = <<-EOD
    When set to true, the module will keep any PAM-related binding in the project's IAM policy.
  EOD
  type        = bool
  default     = true
  nullable    = false
}

variable "custom_roles" {
  description = <<-EOD
    Create custom roles and define who gains that role on project level. If your project level IAM binding needs to set
    a condition, use the `iam_policy` input variable of this module while referencing the full name of your custom role.

    Example:
    ```
    custom_roles = {
      "appengine.applicationsCreator" = {
        title       = "AppEngine Creator",
        description = "Custom role to grant permissions for creating App Engine applications.",
        permissions = [
          "appengine.applications.create",
        ]
        project_iam_policy_members = [
          "group:customer.project-role@cloudfoundation.metro.digital",
        ]
      }
    }
    ```
  EOD

  type = map(object({
    title                      = string
    description                = string
    permissions                = list(string)
    project_iam_policy_members = list(string)
  }))

  default = {}
}

variable "service_accounts" {
  description = <<-EOD
    Service accounts to create for this project.

    **`display_name`:** Human-readable name shown in Google Cloud Console

    **`description` (optional):** Human-readable description shown in Google Cloud Console

    **`iam_policy` (optional):** IAM permissions assigned to this service account as a *resource*. This defines which
    principal can do something on this service account. An example: If you grant `roles/iam.serviceAccountKeyAdmin` to a
    group here, this group will be able to maintain service account keys for this specific SA. If you want to allow this
    SA to use BigQuery, you should use the `project_iam_policy_roles` attribute to do so. If your IAM binding requires a
    condition, use the `iam_policy` input variable of this module while referencing the full name of your custom role.

    **`iam_policy_non_authoritative_roles` (optional):** Any role given in this list will be added to the authoritative
    IAM policy of this service account with its current value as defined in the Google Cloud Platform. Can contain regex
    patterns. Example use case: Composer 2 adds values to `roles/iam.workloadIdentityUser` binding when an environment is
    created or updated. Thus, you might want to automatically import those permissions.

    **`project_iam_policy_roles` (optional):** IAM permissions assigned to this service account on *project level*.
    This parameter is merged with whatever is provided as the project's IAM policy via the `iam_policy` input variable.

    **`runtime_service_accounts` (optional):** You can list Kubernetes service accounts within Cloud Native Runtime
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

    **`tags` (optional):** You can list tag values here. For each tag value a tag binding will be created.

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
          display_name = "My Runtime Workload"
          description  = "Workload running in Cloud Native Runtime Cluster"

          # Grant this service account to execute BigQuery jobs
          # access to certain datasets is configured in dataset IAM policy
          project_iam_policy_roles = [
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
          tags = [
            "tagValues/123456789"
          ]
        }
        deployments = {
          display_name  = "Deployments"
          description   = "Service account to deploy application"

          # Grant this service account Cloud Run Admin on project level
          project_iam_policy_roles = [
            "roles/run.admin"
          ]

          # Allow specific group to impersonate this service account only
          iam_policy = [
            {
              role    = "roles/iam.serviceAccountUser"
              members = [
                "group:customer.project-role@cloudfoundation.metro.digital",
              ]
            }
          ]

          # This service account will be used by GitHub Action deployments in the given repository
          github_action_repositories = [
            "my-user-or-organisation/my-great-repo"
          ]
        }
        bq-reader = {
          display_name = "BigQuery Reader"
          description  = "Service account for BigQuery Reader for App XYZ"
        }
        composer = {
          display_name                       = "Composer"
          description                        = "Service account to run Composer 2"
          iam_policy_non_authoritative_roles = [
            # maintained by Composer service automatically - imports any existing value
            "roles/iam.workloadIdentityUser"
          ]
        }
      }
    }
    ```
  EOD

  type = map(object({
    display_name = string
    description  = optional(string)
    iam_policy = optional(list(object({
      role    = string
      members = list(string)
      condition = optional(object({
        title       = string
        expression  = string
        description = optional(string, null)
      }), null)
    })), [])
    iam_policy_non_authoritative_roles = optional(list(string), [])
    project_iam_policy_roles           = optional(list(string), [])
    github_action_repositories         = optional(list(string), [])
    runtime_service_accounts = optional(list(object({
      cluster_id      = string
      namespace       = string
      service_account = string
    })), [])
    tags = optional(list(string), [])
  }))

  default = {}
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
