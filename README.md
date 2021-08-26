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

This module requires [terraform] version >0.14

## Features

### VPC Network
A VPC network will be created in the requested regions. [Private Google Access] will be enabled, so you
can connect to Google Services without public IPs. [Private services access] is also configured allowing you
to run services like Cloud SQL with private IPs. It's also possible to configure [Cloud NAT] and [Serverless VPC Access] per region.

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
      "group:example-group@metronom.com",
      "user:example-user@metronom.com",
      "serviceAccount:example-sa@example-prj..iam.gserviceaccount.com"
    ],
    "roles/cloudsql.admin" = [
      "group:another-example-group@metronom.com",
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
| roles | IAM roles and their members.<br><br>Example:<pre>roles = {<br>  "roles/bigquery.admin" = [<br>    "group:example-group@metronom.com",<br>    "user:example-user@metronom.com",<br>    "serviceAccount:exmple-sa@example-prj..iam.gserviceaccount.com"<br>  ],<br>  "roles/cloudsql.admin" = [<br>    "group:another-example-group@metronom.com",<br>  ]<br>}</pre> | `map(list(string))` | n/a | yes |
| custom_roles | Create custom roles and define who gains that role on project level<br><br>Example:<pre>custom_roles = {<br>  "appengine.applicationsCreator" = {<br>    title       = "AppEngine Creator",<br>    description = "Custom role to grant permissions for creating App Engine applications.",<br>    permissions = [<br>      "appengine.applications.create",<br>    ]<br>    members = [<br>      "group:example-grp@metronom.com"<br>    ]<br>  }<br>}</pre> | <pre>map(object({<br>    title       = string<br>    description = string<br>    permissions = list(string)<br>    members     = list(string)<br>  }))</pre> | `{}` | no |
| deprivilege_compute_engine_sa | By default the compute engine service account (*project-number*-compute@developer.gserviceaccount.com) is assigned `roles/editor`<br>If you want to deprivilege the account set this to true, and grant needed permissions via roles variable.<br>Otherwise the module will grant `roles/editor` to the service account. | `bool` | `false` | no |
| enabled_services | List of GCP enabled services / APIs to enable. Dependencies will be enabled automatically.<br>The modules does not provide a way to disable services (again), if you want to disable services<br>you can do this manual using UI or gcloud CLI.<br><br>**Remark**: Google sometimes changes (mostly adding) dependencies and will activate those automatically for your<br>project, means being authoritative on services usually causes a lot of trouble.<br><br>Example:<pre>enabled_services = [<br>  "bigquery.googleapis.com",<br>  "compute.googleapis.com",<br>  "cloudscheduler.googleapis.com",<br>  "iap.googleapis.com"<br>]</pre> | `list(string)` | `[]` | no |
| service_accounts | Service accounts to create for this project.<br><br>**Optional:** IAM permissions assigned to this Service Account as a *resource*. This means who else can do something<br>on this Service Account. An example: if you grant `roles/iam.serviceAccountKeyAdmin` to a group here, this group<br>will be able to maintain Service Account keys for this specific SA. If you want to allow this SA to use BigQuery<br>you need to use the `roles` input to do so.<br><br>Example:<pre>service_accounts = {<br>    deployments = {<br>      display_name = "Deployments"<br>      description  = "Service Account to deploy application"<br>      description  = "<br>      iam          = {<br>        "roles/iam.serviceAccountKeyAdmin" = [<br>          "group:deployment-admins@metronom.com"<br>        ]<br>      }<br>    }<br>    bq-reader = {<br>      display_name = "BigQuery Reader"<br>      description  = "Service Account for BigQuery Reader for App XYZ"<br>      iam          = {} # No special Service Account resource IAM permissions<br>    }<br>  }<br>}</pre> | <pre>map(object({<br>    display_name = string<br>    description  = optional(string)<br>    iam          = map(list(string))<br>  }))</pre> | `{}` | no |
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
  * curl
  * jq
  * dig
  * xargs

## License

This project is licensed under the terms of the [Apache License 2.0](LICENSE)

This [terraform] module depends on providers from HashiCorp, Inc. which are licensed under MPL-2.0. You can obtain the respective source code for these provider here:
  * [`hashicorp/google`](https://github.com/hashicorp/terraform-provider-google)
  * [`hashicorp/google-beta`](https://github.com/hashicorp/terraform-provider-google-beta)
  * [`hashicorp/external`](https://github.com/hashicorp/terraform-provider-external)

This [terraform] module uses pre-commit hooks which are licensed under MPL-2.0. You can obtain the respective source code here:
  * [`terraform-linters/tflint`](https://github.com/terraform-linters/tflint)
  * [`terraform-linters/tflint-ruleset-google`](https://github.com/terraform-linters/tflint-ruleset-google)

[terraform]: https://terraform.io/
[Private Google Access]: https://cloud.google.com/vpc/docs/configure-private-google-access
[Serverless VPC Access]: https://cloud.google.com/vpc/docs/configure-serverless-vpc-access
[Private services access]: https://cloud.google.com/vpc/docs/configure-private-services-access
[service agent roles]: https://cloud.google.com/iam/docs/service-agents
[Cloud NAT]: https://cloud.google.com/nat/docs/overview
[FAQ]: ./docs/FAQ.md
[CONTRIBUTING]: docs/CONTRIBUTING.md
