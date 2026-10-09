# Cloud Foundation Project Configuration Module

[FAQ] | [CONTRIBUTING] | [CHANGELOG] | [MIGRATION]

This module allows you to configure a Google Cloud Platform project created via the Cloud Foundation
Panel. It aims to provide reasonable defaults for certain network-related resources, Workload
Identity Federation Pools for authentication from One Platform and GitHub and provides a centralized
management for service accounts and the project-level IAM policy. Using this module will make it
easier for you to be compliant with METRO's Cloud Policies.

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=2 -->

- [Getting Started](#getting-started)
- [Usage](#usage)
- [Features](#features)
  - [VPC Network](#vpc-network)
  - [IAM](#iam)
- [License](#license)

<!-- mdformat-toc end -->

## Getting Started

The easiest way to get started it to use the module's bootstrapping functionality. Bootstrapping a
project leverages the Google principal you are locally authenticated as to provision the minimum
amount of resources required for Terraform to take over the project's management and generate
Terraform code which you can use as the basis for all further project management.

To find out how to bootstrap a project, check out the dedicated
[bootstrapping documentation][bootstrap].

## Usage

```hcl
module "projectcfg" {
  source  = "metro-digital/cf-projectcfg/google"
  version = "~> 3.7"

  project_id = "cf-example-project"
}
```

> [!TIP]
> A detailed description of input variables and output values can be found
> [here](./docs/TERRAFORM.md).

See the [FAQ] for simple examples of using Workload Identity Federation with GitHub and other tools.

## Features

### VPC Network

A VPC network will be created in the requested regions. [Private Google Access] will be enabled, so
you can connect to Google Services without public IPs. [Private Services Access] is also configured
allowing you to run services like Cloud SQL with private IPs. It's also possible to configure
[Cloud NAT] and [Serverless VPC Access] per region.

For more details please check the `vpc_regions` input parameter and
[docs/DEFAULT-VPC.md](docs/DEFAULT-VPC.md), especially if you plan to extend it by adding custom
subnetworks or similar. Also, all used IP address ranges are documented there.

### IAM

This module acts authoritative on the project IAM policy. It aims to configure the project-level IAM
policy and service account (including the IAM policy on the service account itself) related
resources in a central place for easy review and adjustments. All active roles are fetched initially
and compared with the roles given via roles input.

> [!IMPORTANT]
> Roles enforced by the Cloud Foundation Panel are automatically injected into the projects IAM
> policy.

All roles [listed for service agents][service agent roles] (like for example
`roles/dataproc.serviceAgent`) are ignored, so if a service gets enabled the default permissions
granted automatically by Google Cloud Platform to the related service accounts will stay in place.
This excludes are configured in [project-iam.tf](./project-iam.tf) - look for a local variable
called `project_iam_non_authoritative_roles`.

The module warns during plan and apply if it finds project service accounts that are not configured
in `service_accounts`. The warning lists the accounts for review; it does not change or delete them.
Google service agents and the project's default Compute Engine service account are excluded. The App
Engine default account remains subject to the check because it is user-managed. The Terraform
principal needs `iam.serviceAccounts.list`; an API lookup failure is a normal data-source error. Set
`disable_unmanaged_service_accounts_check = true` to skip the check and its API lookup.

## License

This project is licensed under the terms of the [Apache License 2.0](LICENSE)

This [terraform] module depends on providers from HashiCorp, Inc. which are licensed under MPL-2.0.
You can obtain the respective source code for these provider here:

- [`hashicorp/google`](https://github.com/hashicorp/terraform-provider-google)
- [`hashicorp/external`](https://github.com/hashicorp/terraform-provider-external)

This [terraform] module uses pre-commit hooks which are licensed under MPL-2.0. You can obtain the
respective source code here:

- [`terraform-linters/tflint`](https://github.com/terraform-linters/tflint)
- [`terraform-linters/tflint-ruleset-google`](https://github.com/terraform-linters/tflint-ruleset-google)

[bootstrap]: ./bootstrap/README.md
[changelog]: ./docs/CHANGELOG.md
[cloud nat]: https://cloud.google.com/nat/docs/overview
[contributing]: docs/CONTRIBUTING.md
[faq]: ./docs/FAQ.md
[migration]: ./docs/MIGRATION.md
[private google access]: https://cloud.google.com/vpc/docs/configure-private-google-access
[private services access]: https://cloud.google.com/vpc/docs/configure-private-services-access
[serverless vpc access]: https://cloud.google.com/vpc/docs/configure-serverless-vpc-access
[service agent roles]: https://cloud.google.com/iam/docs/service-agents
[terraform]: https://terraform.io/
