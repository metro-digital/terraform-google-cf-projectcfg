# Cloud Foundation project setup module
[FAQ] | [CONTRIBUTING]

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

This module requires [terraform] version >1.0

## Features

### VPC Network

A VPC network will be created in the requested regions. [Private Google Access] will be enabled, so you
can connect to Google Services without public IPs. [Private services access] is also configured allowing you
to run services like Cloud SQL with private IPs. It's also possible to configure [Cloud NAT] and [Serverless VPC Access] per region.

For more details please check [docs/DEFAULT-VPC.md](docs/DEFAULT-VPC.md)

### IAM

This module acts "mostly" authoritative on IAM roles. It aims to configure all IAM and Service Account related resources in a central
place for easy review and adjustments. All active roles are fetched initially and compared with the roles given via roles input. If a
role shouldn't be set the module will create an empty resource for this role, means terraform will remove it. This will result in a
module deletion on the next terraform run.

All roles [listed for service agents][service agent roles] (like for example `roles/dataproc.serviceAgent`) are ignored, so if a service
get's enabled the default permissions granted automatically by Google Cloud Platform to the related service accounts will stay in place.
Those excludes are configured in [data.tf](data.tf) - look for a local variable called `role_excludes`

## Usage

```hcl
module "project-cfg" {
  source      = "metro-digital/cf-projectcfg/google"
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

Please also take a deeper look into the [FAQ] - there are additional examples available.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| roles | IAM roles and their members.<br><br>Example:<pre>roles = {<br>  "roles/bigquery.admin" = [<br>    "group:customer.project-role@cloudfoundation.metro.digital",<br>    "user:some.user@metro.digital",<br>    "serviceAccount:exmple-sa@example-prj..iam.gserviceaccount.com"<br>  ],<br>  "roles/cloudsql.admin" = [<br>    "group:customer.project-role@cloudfoundation.metro.digital",<br>  ]<br>}</pre> | `map(list(string))` | n/a | yes |
| custom_roles | Create custom roles and define who gains that role on project level<br><br>Example:<pre>custom_roles = {<br>  "appengine.applicationsCreator" = {<br>    title       = "AppEngine Creator",<br>    description = "Custom role to grant permissions for creating App Engine applications.",<br>    permissions = [<br>      "appengine.applications.create",<br>    ]<br>    members = [<br>      "group:customer.project-role@cloudfoundation.metro.digital",<br>    ]<br>  }<br>}</pre> | <pre>map(object({<br>    title       = string<br>    description = string<br>    permissions = list(string)<br>    members     = list(string)<br>  }))</pre> | `{}` | no |
| deprivilege_compute_engine_sa | By default the compute engine service account (*project-number*-compute@developer.gserviceaccount.com) is assigned `roles/editor`<br>If you want to deprivilege the account set this to true, and grant needed permissions via roles variable.<br>Otherwise the module will grant `roles/editor` to the service account. | `bool` | `false` | no |
| enabled_services | List of GCP enabled services / APIs to enable. Dependencies will be enabled automatically.<br>The modules does not provide a way to disable services (again), if you want to disable services<br>you can do this manual using UI or gcloud CLI.<br><br>**Remark**: Google sometimes changes (mostly adding) dependencies and will activate those automatically for your<br>project, means being authoritative on services usually causes a lot of trouble.<br><br>Example:<pre>enabled_services = [<br>  "bigquery.googleapis.com",<br>  "compute.googleapis.com",<br>  "cloudscheduler.googleapis.com",<br>  "iap.googleapis.com"<br>]</pre> | `list(string)` | `[]` | no |
| non_authoritative_roles | List of roles (regex) to exclude from authoritative project IAM handling.<br>Roles listed here can have bindings outside of this module.<br><br>Example:<pre>non_authoritative_roles = [<br>  "roles/container.hostServiceAgentUser"<br>]</pre> | `list(string)` | `[]` | no |
| service_accounts | Service accounts to create for this project.<br><br>**`display_name`:** Human-readable name shown in Google Cloud Console<br><br>**`description` (optional):** Human-readable description shown in Google Cloud Console<br><br>**`iam` (optional):** IAM permissions assigned to this Service Account as a *resource*. This means who else can do something<br>on this Service Account. An example: if you grant `roles/iam.serviceAccountKeyAdmin` to a group here, this group<br>will be able to maintain Service Account keys for this specific SA. If you want to allow this SA to use BigQuery<br>you need to use the project-wide `roles` input to do so.<br><br>**`iam_non_authoritative_roles` (optional):** Any role given in this list will be added to the authoritative policy with<br>its current value as defined in the Google Cloud Platform. Example use case: Composer 2 adds values to<br>`roles/iam.workloadIdentityUser` binding when environment is created or updated. Thus, you might want to automatically<br>import those permissions.<br><br>**`github_action_repositories` (optional):** You can list GitHub repositories (format: user/repo) here. Each repository<br>given gains permissions to authenticate as this service account using Workload Identity Federation.<br>This allows any GitHub Action pipeline to use this service account without the need for service account keys.<br>For details see documentation for action [`google-github-actions/auth`](https://github.com/google-github-actions/auth).<br><br>**Remark:** If you configure `github_action_repositories`, the module binds a member for each repository to the role<br>`roles/iam.workloadIdentityUser` inside the service account's IAM policy. This is done *regardless of weather<br>or not* you list this role in the `iam_non_authoritative_roles` key.<br><br>Example:<pre>service_accounts = {<br>    deployments = {<br>      display_name = "Deployments"<br>      description  = "Service Account to deploy application"<br>      description  = "<br>      iam          = {<br>        "roles/iam.serviceAccountKeyAdmin" = [<br>          "group:customer.project-role@cloudfoundation.metro.digital",<br>        ]<br>      }<br>      github_action_repositories = [<br>        "my-user-or-organisation/my-great-repo"<br>      ]<br>    }<br>    bq-reader = {<br>      display_name = "BigQuery Reader"<br>      description  = "Service Account for BigQuery Reader for App XYZ"<br>      iam          = {} # No special Service Account resource IAM permissions<br>    }<br>    composer = {<br>      display_name                = "Composer"<br>      description                 = "Service Account to run Composer 2"<br>      iam                         = {} # No special Service Account resource IAM permissions<br>      iam_non_authoritative_roles = [<br>        # maintained by Composer service - imports any existing value<br>        "roles/iam.workloadIdentityUser"<br>      ]<br>    }<br>  }<br>}</pre> | <pre>map(object({<br>    display_name                = string<br>    description                 = optional(string)<br>    iam                         = map(list(string))<br>    iam_non_authoritative_roles = optional(list(string))<br>    github_action_repositories  = optional(list(string))<br>  }))</pre> | `{}` | no |
| skip_default_vpc_creation | When set to true the module will not create the default VPC or any<br>related resource like NAT Gateway or serverless VPC access configuration. | `bool` | `false` | no |
| vpc_regions | Enabled regions and configuration<br><br>Example:<pre>vpc_regions = {<br>  europe-west1 = {<br>    vpcaccess            = true    # Enable serverless VPC access for this region<br>    nat                  = 2       # Create a Cloud NAT with 2 (static) external IP addresses (IPv4) in this region<br>    nat_min_ports_per_vm = 64      # Minimum number of ports allocated to a VM from the NAT defined above (Note: this option is optional, but must be defined for all the regions if it is set for at least one)<br>  },<br>  europe-west3 = {<br>    vpcaccess            = false   # Disable serverless VPC access for this region<br>    nat                  = 0       # No Cloud NAT for this region<br>    nat_min_ports_per_vm = 0       # Since the `nat_min_ports_per_vm` was set for the region above, its definition is required here.<br>  },<br>}</pre> | <pre>map(object({<br>    vpcaccess            = bool<br>    nat                  = number<br>    nat_min_ports_per_vm = optional(number)<br>  }))</pre> | <pre>{<br>  "europe-west1": {<br>    "nat": 0,<br>    "vpcaccess": false<br>  }<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | GCP project ID |
| service_accounts | List of service accounts created |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

This module needs some command line utils to be installed:

- curl
- jq
- dig
- xargs

## License

This project is licensed under the terms of the [Apache License 2.0](LICENSE)

This [terraform] module depends on providers from HashiCorp, Inc. which are licensed under MPL-2.0. You can obtain the respective source code for these provider here:
  * [`hashicorp/google`](https://github.com/hashicorp/terraform-provider-google)
  * [`hashicorp/external`](https://github.com/hashicorp/terraform-provider-external)

This [terraform] module uses pre-commit hooks which are licensed under MPL-2.0. You can obtain the respective source code here:

- [`terraform-linters/tflint`](https://github.com/terraform-linters/tflint)
- [`terraform-linters/tflint-ruleset-google`](https://github.com/terraform-linters/tflint-ruleset-google)

[cloud nat]: https://cloud.google.com/nat/docs/overview
[contributing]: docs/CONTRIBUTING.md
[faq]: ./docs/FAQ.md
[private google access]: https://cloud.google.com/vpc/docs/configure-private-google-access
[private services access]: https://cloud.google.com/vpc/docs/configure-private-services-access
[serverless vpc access]: https://cloud.google.com/vpc/docs/configure-serverless-vpc-access
[service agent roles]: https://cloud.google.com/iam/docs/service-agents
[terraform]: https://terraform.io/
