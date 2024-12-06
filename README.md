# Cloud Foundation project setup module

[FAQ] | [CONTRIBUTING] | [CHANGELOG]

This module allows you to configure a Google Cloud Platform project.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [Compatibility](#compatibility)
- [Features](#features)
  - [VPC Network](#vpc-network)
  - [IAM](#iam)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Requirements](#requirements)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Compatibility

This module requires [terraform] version >=1.3.1.

## Features

### VPC Network

A VPC network will be created in the requested regions. [Private Google
Access] will be enabled, so you can connect to Google Services without
public IPs. [Private services access] is also configured allowing you to run
services like Cloud SQL with private IPs. It's also possible to configure
[Cloud NAT] and [Serverless VPC Access] per region.

For more details please check [docs/DEFAULT-VPC.md](docs/DEFAULT-VPC.md),
especially if you plan to extend it by adding custom subnetworks or similar.
Also all used IP address ranges are documented there.

### IAM

This module acts "mostly" authoritative on IAM roles. It aims to configure
all IAM and Service Account related resources in a central place for easy
review and adjustments. All active roles are fetched initially and compared
with the roles given via roles input. If a role shouldn't be set the module
will create an empty resource for this role, means terraform will remove it.
This will result in a module deletion on the next terraform run.

All roles [listed for service agents][service agent roles] (like for example
`roles/dataproc.serviceAgent`) are ignored, so if a service gets enabled the
default permissions granted automatically by Google Cloud Platform to the
related service accounts will stay in place. This excludes are configured
in [data.tf](data.tf) - look for a local variable called `role_excludes`

## Usage

```hcl
module "projectcfg" {
  source  = "metro-digital/cf-projectcfg/google"
  version = "~> 3.0"

  project_id  = "metro-cf-example-ex1-e8v"

  roles = {
    "roles/bigquery.admin" = [
      "group:customer.project-role@cloudfoundation.metro.digital",
      "user:some.user@metro.digital",
      "serviceAccount:exmple-sa@example-prj..iam.gserviceaccount.com"
    ],
    "roles/cloudsql.admin" = [
      "group:customer.project-role@cloudfoundation.metro.digital",
    ]
  }
}
```

Please also take a deeper look into the [FAQ] - there are additional
examples available. Examples how to use Workload Identity Federation with
GitHub and similar things are explained giving simple examples.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| roles | IAM roles and their members.<br/><br/>If you create a service account in this project via the `service_accounts` input, we recommend<br/>to use the `project_roles` attribute of the respective service account to grant it permissions<br/>on the project's IAM policy. This allows you to better re-use your code in staged environments.<br/><br/>Example:<pre>roles = {<br/>  "roles/bigquery.admin" = [<br/>    "group:customer.project-role@cloudfoundation.metro.digital",<br/>    "user:some.user@metro.digital",<br/>  ],<br/>  "roles/cloudsql.admin" = [<br/>    "group:customer.project-role@cloudfoundation.metro.digital",<br/>  ]<br/>}</pre> | `map(list(string))` | n/a | yes |
| custom_roles | Create custom roles and define who gains that role on project level<br/><br/>Example:<pre>custom_roles = {<br/>  "appengine.applicationsCreator" = {<br/>    title       = "AppEngine Creator",<br/>    description = "Custom role to grant permissions for creating App Engine applications.",<br/>    permissions = [<br/>      "appengine.applications.create",<br/>    ]<br/>    members = [<br/>      "group:customer.project-role@cloudfoundation.metro.digital",<br/>    ]<br/>  }<br/>}</pre> | <pre>map(object({<br/>    title       = string<br/>    description = string<br/>    permissions = list(string)<br/>    members     = list(string)<br/>  }))</pre> | `{}` | no |
| enabled_services | List of GCP enabled services / APIs to enable. Dependencies will be enabled automatically.<br/><br/>**Remark**: Google sometimes changes (mostly adding) dependencies and will activate those automatically for your<br/>project. Therefore being authoritative on services usually causes a lot of trouble. The module doesn't provide any<br/>option to be authoritative for this reason. By default we are partly authoritative. This can can be controlled<br/>by the `enabled_services_disable_on_destroy` flag.<br/><br/>Example:<pre>enabled_services = [<br/>  "bigquery.googleapis.com",<br/>  "compute.googleapis.com",<br/>  "cloudscheduler.googleapis.com",<br/>  "iap.googleapis.com"<br/>]</pre> | `list(string)` | `[]` | no |
| enabled_services_disable_on_destroy | If true, try to disable a service given via `enabled_services` after its removal from from the list.<br/>Defaults to true. May be useful in the event that a project is long-lived but the infrastructure running in<br/>that project changes frequently.<br/><br/>Can result in failing terraform runs if the removed service is a dependency for any other active service. | `bool` | `true` | no |
| essential_contacts | Essential contacts receive configurable notifications from Google Cloud Platform<br/>based on selected categories.<br/><br/>**`language`:** The preferred language for notifications, as an ISO 639-1 language code.<br/>See [documentation](https://cloud.google.com/resource-manager/docs/managing-notification-contacts#supported-languages)<br/>for a list of supported languages.<br/><br/>**`categories`:** The categories of notifications that the contact will receive communications for.<br/>See [documentation](https://cloud.google.com/resource-manager/docs/managing-notification-contacts#notification-categories)<br/>for a list of supported categories.<br/><br/>**Remark:** The module will enable the essential contacts API automatically once one contact is configured.<br/>You still need to grant the role `roles/essentialcontacts.admin` to the principle that is executing<br/>the terraform code (most likely your service account used in your pipeline) if you plan to use<br/>`github_action_repositories`.<br/><br/>Example:<pre>essential_contacts = {<br/>  "some-group-mailing-list@metro.digital" = {<br/>    language   = "en"<br/>    categories = ["ALL"]<br/>  }<br/>  "some-other-group-list@metro.digital" = {<br/>    language   = "en"<br/>    categories = [<br/>      "SUSPENSION",<br/>      "TECHNICAL"<br/>    ]<br/>  }<br/>}</pre> | <pre>map(object({<br/>    language   = string<br/>    categories = list(string)<br/>  }))</pre> | `{}` | no |
| firewall_rules | The module will create default firewall rules unless `skip_default_vpc_creation` is set to `true`<br/><br/>The following rules are created by default:<br/>  - **`allow_ssh_iap`:** A firewall rule allowing SSH via IAP if the network tag `fw-allow-ssh-iap`<br/>    is set on an Compute Instance<br/>  - **`allow_rdp_iap`:** A firewall rule allowing SSH via IAP if the network tag `fw-allow-rdp-iap`<br/>    is set on an Compute Instance<br/><br/>The following additional rules are available if explicitly enabled:<br/>  - **`all_internal`:** A firewall rule allowing all kinds of traffic inside the VPC<br/><br/>Example:<pre># Disable IAP RDP rule rule, keep default for all other rules<br/>firewall_rules = {<br/>  allow_rdp_iap = false<br/>}</pre> | <pre>object({<br/>    all_internal  = optional(bool, false)<br/>    allow_ssh_iap = optional(bool, true)<br/>    allow_rdp_iap = optional(bool, true)<br/>  })</pre> | `{}` | no |
| non_authoritative_roles | List of roles (regex) to exclude from authoritative project IAM handling.<br/>Roles listed here can have bindings outside of this module.<br/><br/>Example:<pre>non_authoritative_roles = [<br/>  "roles/container.hostServiceAgentUser"<br/>]</pre> | `list(string)` | `[]` | no |
| service_accounts | Service accounts to create for this project.<br/><br/>**`display_name`:** Human-readable name shown in Google Cloud Console<br/><br/>**`description` (optional):** Human-readable description shown in Google Cloud Console<br/><br/>**`iam` (optional):** IAM permissions assigned to this Service Account as a *resource*. This defines which principal<br/>can do something on this Service Account. An example: If you grant `roles/iam.serviceAccountKeyAdmin` to a group<br/>here, this group will be able to maintain Service Account keys for this specific SA. If you want to allow this SA to<br/>use BigQuery, you need to use the project-wide `roles` input or, even better, use the `project_roles` attribute to<br/>do so.<br/><br/>**`project_roles` (optional):** IAM permissions assigned to this Service Account on *project level*.<br/>This parameter is merged with whatever is provided as the project's IAM policy via the `roles` input.<br/><br/>**`iam_non_authoritative_roles` (optional):** Any role given in this list will be added to the authoritative policy<br/>with its current value as defined in the Google Cloud Platform. Example use case: Composer 2 adds values to<br/>`roles/iam.workloadIdentityUser` binding when an environment is created or updated. Thus, you might want to<br/>automatically import those permissions.<br/><br/>**`runtime_service_accounts` (optional):** You can list Kubernetes Service Accounts within Cloud Native Runtime<br/>clusters here. For details on the format, see the example below. A Workload Identity Pool and a Workload Identity<br/>Provider needed for Workload Identity Federation will be created automatically. Each service account given gains<br/>permissions to authenticate as this service account using Workload Identity Federation. This allows workloads running<br/>in Cloud Native Runtime clusters to use this service account without the need for service account keys. A detailed<br/>example can be found within the [FAQ].<br/><br/>**`github_action_repositories` (optional):** You can list GitHub repositories (format: `user/repo`) here.<br/>A Workload Identity Pool and a Workload Identity Provider needed for Workload Identity Federation will be<br/>created automatically. Each repository given gains permissions to authenticate as this service account using<br/>Workload Identity Federation. This allows any GitHub Action pipeline to use this service account without the need<br/>for service account keys. An example can be found within the [FAQ].<br/><br/>For more details, see the documentation for Google's GitHub action for authentication:<br/>[`google-github-actions/auth`](https://github.com/google-github-actions/auth).<br/><br/>**Remark:** If you configure `github_action_repositories`, the module binds a member for each repository to the role<br/>`roles/iam.workloadIdentityUser` inside the service account's IAM policy. This is done *regardless of whether<br/>or not* you list this role in the `iam_non_authoritative_roles` key. The same happens if you use<br/>`runtime_service_accounts`. A member per runtime service account is added to the service account's IAM policy.<br/><br/>**Remark:** You need to grant the role `roles/iam.workloadIdentityPoolAdmin` to the principal that is<br/>executing the terraform code (most likely a service account used in a pipeline) if you plan to use<br/>`github_action_repositories` or `runtime_service_accounts`.<br/><br/>Example:<pre>service_accounts = {<br/>    runtime-sa = {<br/>      display_name  = "My Runtime Workload"<br/>      description   = "Workload running in Cloud Native Runtime Cluster"<br/><br/>      # Grant this service account to execute BigQuery jobs<br/>      # access to certain datasets is configured in dataset IAM policy<br/>      project_roles = [<br/>        "roles/bigquery.jobUser"<br/>      ]<br/>      runtime_service_accounts = [<br/>        # You can specify multiple of the following objects if needed<br/>        {<br/>          cluster_id      = "mycluster-id-1"<br/>          namespace       = "some-namespace"<br/>          service_account = "some-service-account-name"<br/>        }<br/>      ]<br/>    }<br/>    deployments = {<br/>      display_name  = "Deployments"<br/>      description   = "Service Account to deploy application"<br/><br/>      # Grant this service account Cloud Run Admin on project level<br/>      project_roles = [<br/>        "roles/run.admin"<br/>      ]<br/><br/>      # Allow specific group to create keys for this Service Account only<br/>      iam = {<br/>        "roles/iam.serviceAccountKeyAdmin" = [<br/>          "group:customer.project-role@cloudfoundation.metro.digital",<br/>        ]<br/>      }<br/><br/>      # This service account will be used by GitHub Action deployments in the given repository<br/>      github_action_repositories = [<br/>        "my-user-or-organisation/my-great-repo"<br/>      ]<br/>    }<br/>    bq-reader = {<br/>      display_name = "BigQuery Reader"<br/>      description  = "Service Account for BigQuery Reader for App XYZ"<br/>      iam          = {} # No special Service Account resource IAM permissions<br/>    }<br/>    composer = {<br/>      display_name                = "Composer"<br/>      description                 = "Service Account to run Composer 2"<br/>      iam                         = {} # No special Service Account resource IAM permissions<br/>      iam_non_authoritative_roles = [<br/>        # maintained by Composer service automatically - imports any existing value<br/>        "roles/iam.workloadIdentityUser"<br/>      ]<br/>    }<br/>  }<br/>}</pre> | <pre>map(object({<br/>    display_name                = string<br/>    description                 = optional(string)<br/>    iam                         = map(list(string))<br/>    project_roles               = optional(list(string))<br/>    iam_non_authoritative_roles = optional(list(string))<br/>    github_action_repositories  = optional(list(string), [])<br/>    runtime_service_accounts = optional(list(object({<br/>      cluster_id      = string<br/>      namespace       = string<br/>      service_account = string<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| skip_default_vpc_creation | When set to true the module will not create the default VPC or any<br/>related resource like NAT Gateway, firewall rules or Serverless VPC access configuration. | `bool` | `false` | no |
| vpc_regions | Enabled regions and configuration<br/><br/>Example:<pre>vpc_regions = {<br/>  europe-west1 = {  # Create a subnetwork in europe-west1<br/>    vpcaccess            = true    # Enable serverless VPC access for this region<br/>    nat                  = 2       # Create a Cloud NAT with 2 (static) external IP addresses (IPv4) in this region<br/>    nat_min_ports_per_vm = 64      # Minimum number of ports allocated to a VM from the NAT defined above (Note: this option is optional, but must be defined for all the regions if it is set for at least one)<br/>    gke_secondary_ranges = true    # Create secondary IP ranges used by GKE with VPC-native clusters (gke-services & gke-pods)<br/>    proxy_only           = true    # Create an additional "proxy-only" network in this region used by L7 load balancers<br/>  },<br/>  europe-west4 = {  # Create a subnetwork in europe-west4<br/>    vpcaccess            = false   # Disable serverless VPC access for this region<br/>    nat                  = 0       # No Cloud NAT for this region<br/>    nat_min_ports_per_vm = 0       # Since the `nat_min_ports_per_vm` was set for the region above, its definition is required here.<br/>    gke_secondary_ranges = false   # Since the `gke_secondary_ranges` was set for the region above, its definition is required here.<br/>    proxy_only           = false   # Since the `proxy_only` was set for the region above, its definition is required here.<br/>  },<br/>}</pre>By default the module will create a subnetwork in europe-west1 but do not launch any additional features like<br/>NAT or VPC access. Secondary ranges for GKE are disabled, too. | <pre>map(object({<br/>    vpcaccess            = bool<br/>    nat                  = number<br/>    nat_min_ports_per_vm = optional(number)<br/>    gke_secondary_ranges = optional(bool)<br/>    proxy_only           = optional(bool)<br/>  }))</pre> | <pre>{<br/>  "europe-west1": {<br/>    "nat": 0,<br/>    "vpcaccess": false<br/>  }<br/>}</pre> | no |
| workload_identity_pool_attribute_condition | A Common Expression Language (CEL) expression to restrict what otherwise<br/>valid authentication credentials issued by the provider should not be<br/>accepted.<br/><br/>By default, credentials issued by GitHub within any organisation/user owning a repository given<br/>via `github_action_repositories` property of a any service account are accepted.<br/><br/>You should never only rely on this condition to limit the principals who<br/>can get access to Google Cloud resources but e.g. explicitly limit the<br/>repository using the `attribute.repository` attribute of your principal<br/>set. This is done automatically if you use the `github_action_repositories`<br/>property of a service account managed by this module.<br/><br/>If the repository of your GitHub workflow runs in a different GitHub<br/>organisation, make sure to provide a valid CEL expression which allows<br/>workflows from your organisation. A list of all METRO-owned organisations<br/>can be obtained from [METRO's GitHub Enterprise](https://github.com/enterprises/metro-digital/organizations). | `string` | `null` | no |
| workload_identity_pool_attribute_mapping | Maps attributes from authentication credentials issued by an external identity provider<br/>to Google Cloud attributes<br/><br/>**Note** Teams must be cautious before modifying the attribute mapping as it may cause<br/>undesired permission issues. See [documentation](https://cloud.google.com/iam/docs/configuring-workload-identity-federation#github-actions)<br/>Example:<pre>{<br/>  "google.subject"             = "assertion.sub"<br/>  "attribute.actor"            = "assertion.actor"<br/>  "attribute.aud"              = "assertion.aud"<br/>  "attribute.repository"       = "assertion.repository"<br/>  "attribute.repository_owner" = "assertion.repository_owner"<br/>}</pre> | `map(any)` | <pre>{<br/>  "attribute.repository": "assertion.repository",<br/>  "google.subject": "assertion.sub"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | GCP project ID |
| service_accounts | List of service accounts created |
<!-- END_TF_DOCS -->

## Requirements

This module needs some command line utils to be installed:

- curl
- jq
- dig
- xargs

## License

This project is licensed under the terms of the [Apache License 2.0](LICENSE)

This [terraform] module depends on providers from HashiCorp, Inc. which are
licensed under MPL-2.0. You can obtain the respective source code for these
provider here:

- [`hashicorp/google`](https://github.com/hashicorp/terraform-provider-google)
- [`hashicorp/external`](https://github.com/hashicorp/terraform-provider-external)

This [terraform] module uses pre-commit hooks which are licensed under MPL-2.0.
You can obtain the respective source code here:

- [`terraform-linters/tflint`](https://github.com/terraform-linters/tflint)
- [`terraform-linters/tflint-ruleset-google`](https://github.com/terraform-linters/tflint-ruleset-google)

[cloud nat]: https://cloud.google.com/nat/docs/overview
[contributing]: docs/CONTRIBUTING.md
[faq]: ./docs/FAQ.md
[changelog]: CHANGELOG.md
[private google access]: https://cloud.google.com/vpc/docs/configure-private-google-access
[private services access]: https://cloud.google.com/vpc/docs/configure-private-services-access
[serverless vpc access]: https://cloud.google.com/vpc/docs/configure-serverless-vpc-access
[service agent roles]: https://cloud.google.com/iam/docs/service-agents
[terraform]: https://terraform.io/
