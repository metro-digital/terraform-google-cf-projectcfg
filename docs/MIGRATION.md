# Migration Instructions

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=2 -->

- [`v3` Release](#v3-release)
  - [IAM-Related Changes](#iam-related-changes)
    - [Changes to Input Variables and Attributes](#changes-to-input-variables-and-attributes)
      - [`roles` => `iam_policy`](#roles--iam_policy)
      - [`non_authoritative_roles` => `iam_policy_non_authoritative_roles`](#non_authoritative_roles--iam_policy_non_authoritative_roles)
      - [`custom_roles.members` => `custom_roles.project_iam_policy_members`](#custom_rolesmembers--custom_rolesproject_iam_policy_members)
      - [`service_accounts.iam` => `service_accounts.iam_policy`](#service_accountsiam--service_accountsiam_policy)
      - [`service_accounts.iam_non_authoritative_roles` => `service_accounts.iam_policy_non_authoritative_roles`](#service_accountsiam_non_authoritative_roles--service_accountsiam_policy_non_authoritative_roles)
      - [`service_accounts.project_roles` => `service_accounts.project_iam_policy_roles`](#service_accountsproject_roles--service_accountsproject_iam_policy_roles)
    - [De-Privilege Compute Engine Default Service Account](#de-privilege-compute-engine-default-service-account)
  - [Compute/Network-Related Changes](#computenetwork-related-changes)
    - [Changes to Input Variables and Attributes](#changes-to-input-variables-and-attributes-1)
      - [`vpc_regions[<REGION>].nat` => `vpc_regions[<REGION>].nat.num_ips`](#vpc_regionsregionnat--vpc_regionsregionnatnum_ips)
      - [`vpc_regions[<REGION>].nat_min_ports_per_vm` => `vpc_regions[<REGION>].nat.min_port_per_vm`](#vpc_regionsregionnat_min_ports_per_vm--vpc_regionsregionnatmin_port_per_vm)
      - [`vpc_regions[<REGION>].vpcaccess` => `vpc_regions[<REGION>].serverless_vpc_access`](#vpc_regionsregionvpcaccess--vpc_regionsregionserverless_vpc_access)
    - [Default VPC Creation](#default-vpc-creation)
    - [Removal of `skip_default_vpc_creation` Variable](#removal-of-skip_default_vpc_creation-variable)
    - [Automatic API Enabling](#automatic-api-enabling)
    - [`enabled_services_disable_on_destroy` Changed Default Behaviour](#enabled_services_disable_on_destroy-changed-default-behaviour)
    - [DNS Policy](#dns-policy)
    - [Firewall Rules](#firewall-rules)
  - [Outputs](#outputs)
    - [Changes for `service_accounts`](#changes-for-service_accounts)

<!-- mdformat-toc end -->

## `v3` Release

To prepare for a migration, ensure you have applied your Terraform configuration
with the latest version of the `v2` release series. The latest version can be
found [here][latest-v2-release].

Review the [CHANGELOG] to familiarize yourself with all the changes implemented
since the latest `v2` release.

To avoid unplanned upgrades to the `v3` release series, we took the opportunity
of a breaking release to unify attribute naming between several input variables.
This resulted in a safeguard against automatic upgrades, as previously mandatory
input variables are removed.

> [!WARNING]
> In general, we recommend using the module with a [version constraint] limiting
> potential updates to the currently used major version. See also the
> [FAQ][faq-versioning]. **There is no guarantee such a safeguard will be
> implemented with the next major release.**

**After reviewing all breaking changes below**, perform the following steps to
upgrade to the `v3` release of the module:

1. Within your Terraform code's `project.tf` file, bump the module to version to
   `~> 3.0`:

   ```hcl
   module "projectcfg" {
     source  = "metro-digital/cf-projectcfg/google"
     version = "~> 3.0"

     project_id = "cf-example-project"
     # ...
   }
   ```

   This change also ensures that you automatically receive updates for all
   minor, non-breaking `v3` versions while not automatically upgrading to a
   breaking `v4` version in the future.

1. Then, run `terraform init` within your project to pull in all the required
   dependencies. This will also allow your editor to have proper semantic
   understanding of the no longer working configurations if it has a rich
   Terraform integration.

1. **Perform all the required changes** as outlined below if they affect your
   usage of the module.

1. It's recommended to import the project's existing IAM policy into the state.
   This will allow you to see a potential diff on the project level IAM policy
   in the next step. If you do not import the existing policy, due to the
   underlying implementation in the Google provider and Terraform itself,
   Terraform will assume to create this IAM policy, and therefore will just show
   it as resource that should be created.

   ```shell
   terraform import module.projectcfg.google_project_iam_policy.this <your project id>
   ```

   The import command above assumes that your module's identifier is
   `projectcfg`, as outlined in the example in step 1. If your identifier is
   different, you need to adjust the commend accordingly.

1. Run `terraform plan` to see all changes. **Carefully review them!** You will
   see that some resources will be removed (e.g. no longer compliant firewall
   rules). You should only see changes related to the breaking changes
   introduced below. If you see other changes, make sure to understand where
   those changes originate. Also, ensure that you understand the implications of
   each change on your infrastructure. If you e.g. rely on a firewall rule which
   is removed in `v3` of the module, make sure to replace it with a sensible
   alternative before proceeding! In case you are unsure about a specific
   change, don't hesitate to reach out to the [Cloud Foundation team][support].

1. **After you are sure that all changes are expected and you mitigated
   potentially negative effects on your infrastructure**, run `terraform apply`
   or use your team's roll-out mechanism (e.g. GitHub Actions).

### IAM-Related Changes

The module is now *fully authoritative* on the project's IAM policy. This is a
significant change, as the module was previously only authoritative on roles
matching the pattern `roles/.*` and custom roles generated by the module itself.
Now, the module is also authoritative on all other roles used within the
project-level IAM policy.

Support for **IAM conditions** was added for the project and service account
level IAM policies.

The module no longer uses a `google_project_iam_binding` resource per role but
generates a full IAM policy to be used with `google_project_iam_policy`. This
has several advantages:

- Significant speed-up for bigger project-level IAM policies. Terraform doesn't
  need to refresh the state of each individual binding any more.
- Better handling of permission removal, as no empty
  `google_project_iam_binding` resource is generated for role bindings that
  should not exist. These bindings caused an additional diff in the next
  Terraform execution as the resources got deleted once applied successfully.

#### Changes to Input Variables and Attributes

##### `roles` => `iam_policy`

The input variable was renamed, and additionally, the type was adjusted to
support IAM conditions. Migration requires some adjustments, see below.

**Old Configuration:**

```hcl
# Old type definition:
#
# map(list(string))

roles = {
  "roles/bigquery.admin" = [
    "group:customer.project-role@cloudfoundation.metro.digital",
  ],
  "roles/cloudsql.admin" = [
    "group:customer.project-role@cloudfoundation.metro.digital",
  ]
}

```

**New Configuration:**

```hcl
# New type definition:
#
# list(object({
#   role    = string
#   members = list(string)
#   condition = optional(object({
#     title       = string
#     expression  = string
#     description = optional(string, null)
#   }), null)
# }))

iam_policy = [
  {
    role = "roles/bigquery.admin"
    members = ["group:customer.project-role@cloudfoundation.metro.digital"]
  },
  {
    role = "roles/cloudsql.admin"
    members = ["group:customer.project-role@cloudfoundation.metro.digital"]
  }
]
```

##### `non_authoritative_roles` => `iam_policy_non_authoritative_roles`

Input variable `non_authoritative_roles` was renamed for naming consistency
reasons. Type is unchanged. For migration, simply rename the input variable to
`iam_policy_non_authoritative_roles`.

##### `custom_roles.members` => `custom_roles.project_iam_policy_members`

Attribute `members` for input variable `custom_roles` was renamed for naming
consistency reasons. Type is unchanged. For migration, simply rename the
attribute to `project_iam_policy_members`.

##### `service_accounts.iam` => `service_accounts.iam_policy`

Attribute `iam` for input variable `service_accounts` was renamed for naming
consistency reasons. The type was adjusted to support IAM conditions, similar to
the `iam_policy` input variable.

The same [migration instructions](#roles--iam_policy) apply.

##### `service_accounts.iam_non_authoritative_roles` => `service_accounts.iam_policy_non_authoritative_roles`

Attribute `iam_non_authoritative_roles` for input variable `service_accounts`
was renamed for naming consistency reasons. Type is unchanged. For migration,
simply rename the attribute to `iam_policy_non_authoritative_roles`.

##### `service_accounts.project_roles` => `service_accounts.project_iam_policy_roles`

Attribute `project_roles` for input variable `service_accounts` was renamed for
naming consistency reasons. Type is unchanged. For migration, simply rename the
attribute to `project_iam_policy_roles`.

#### De-Privilege Compute Engine Default Service Account

The module no longer supports the role `roles/editor` role to be granted to the
[Compute Engine default service account]. The old module input variable
`deprivilege_compute_engine_sa` was removed, and the role is now always removed
on project level. A previous announcement mid-2024 already promoted the
deprecation of primitive roles.

When creating a Compute Engine instance, use user-managed service accounts to be
compliant with Cloud Policies:

- To set up a service account during VM creation, see
  [Create a VM that uses a user-managed service account][vm-create-user-sa].
- To set up a service account on an existing VM, see
  [Change the attached service account][vm-update-user-sa].

### Compute/Network-Related Changes

#### Changes to Input Variables and Attributes

##### `vpc_regions[<REGION>].nat` => `vpc_regions[<REGION>].nat.num_ips`

The NAT configuration of a VPC is now bundled under the `nat` attribute of the
`vpc_regions` input variable. For more details on how this change affects you,
see [the section on the default VPC creation](#default-vpc-creation).

##### `vpc_regions[<REGION>].nat_min_ports_per_vm` => `vpc_regions[<REGION>].nat.min_port_per_vm`

The NAT configuration of a VPC is now bundled under the `nat` attribute of the
`vpc_regions` input variable.

##### `vpc_regions[<REGION>].vpcaccess` => `vpc_regions[<REGION>].serverless_vpc_access`

The attribute `vpcaccess` was renamed to `serverless_vpc_access` to better
reflect the official Google Cloud product name. Additionally, the type of the
attribute changed from a boolean (to disable/enable the feature) to a map allows
you to configure the feature.

**Old Configuration Syntax to Disable the Serverless VPC Access**

```hcl
vpc_regions = {
  europe-west1 = {
    vpcaccess = false
  }
}
```

**New Configuration Syntax to Disable the Serverless VPC Access**

```hcl
vpc_regions = {
  europe-west1 = {
    # Not specifying `serverless_vpc_access` or explicitly setting the
    # attribute to `null` disables the feature in the subnet of this region.
  }
}
```

**Old Configuration Syntax to Enable the Serverless VPC Access**

```hcl
vpc_regions = {
  europe-west1 = {
    vpcaccess = true
  }
}
```

**New Configuration Syntax to Enable the Serverless VPC Access**

```hcl
vpc_regions = {
  europe-west1 = {
    # Creates a Serverless VPC Access Connector with the default, minimal
    # configuration.
    serverless_vpc_access = {}
  }
}
```

#### Default VPC Creation

> [!CAUTION]
> If you don't specify any VPC configuration in the `vpc_regions` input
> variable, the module will no longer provision the default VPC and **delete any
> previously provisioned one**.

To mitigate this, ensure to correctly configure the `vpc_regions` input variable
according to your needs. If you never used the provisioned default VPC, you
don't need to modify the variable and the next apply will delete the default
VPC. You should still read the section on
[the automatic API enabling](#automatic-api-enabling) and
[the updated `enabled_services_disable_on_destroy` behaviour](#enabled_services_disable_on_destroy-changed-default-behaviour)!

Every region which is listed in the `vpc_regions` input variable, now also
receives a NAT gateway with automatic IP address allocation and proxy-only
subnetworks for load balancers.

The previous default behaviour was to always create a VPC and subnetwork in
`europe-west1`.

- If you want to continue provisioning a default subnetwork in `europe-west1`
  **without any NAT gateway**, configure the following `vpc_regions` input
  variable:

  ```hcl
  vpc_regions = {
    europe-west1 = {
      nat = {
        mode = "DISABLED"
      }
    }
  }
  ```

- If you want to continue provisioning a default subnetwork in `europe-west1`
  **with a NAT gateway with one static IP**, configure the following
  `vpc_regions` input variable:

  ```hcl
  vpc_regions = {
    europe-west1 = {
      nat = {
        mode    = "MANUAL"
        num_ips = 1
      }
    }
  }
  ```

- If you want to continue provisioning a default subnetwork in `europe-west1`
  **with a default NAT gateway with automatic IP address allocation**, configure
  the following `vpc_regions` input variable:

  ```hcl
  vpc_regions = {
    europe-west1 = {
      # Not specifying the `nat` attribute (which effectively sets it to an
      # empty map) or manually setting it to `{}` configures the NAT gateway to
      # use automatic IP address allocation.
    }
  }
  ```

- If you want to continue provisioning a default subnetwork in `europe-west1`
  **with a customised NAT gateway with automatic IP address allocation**,
  configure the following `vpc_regions` input variable:

  ```hcl
  vpc_regions = {
    europe-west1 = {
      nat = {
        min_port_per_vm = 128 # An example tuning of the NAT gateway.
      }
    }
  }
  ```

Unless you have a good reason for using static NAT gateway IP addresses (e.g.
because you need to allowlist your internet-facing IP address in external
systems), we generally recommend you to switch to use automatic IP address
allocation which allows your NAT gateway to scale better.

We generally recommend you migrate your existing setup first, apply the migrated
code and only then change your configuration to deploy a NAT gateway using
automatic IP address allocation if you plan to use the new automatic IP address
allocation. This will make it easier to understand the diff produced by
Terraform during the v2 -> v3 migration step.

#### Removal of `skip_default_vpc_creation` Variable

The `skip_default_vpc_creation` was removed as an input variable of the module.
If you do not want to create the default VPC (and its default firewall rules),
set the `vpc_regions` input variable to `{}` (the default). Alternatively,
simply don't specify the input variable.

#### Automatic API Enabling

In the previous release, the following Compute Engine-related services were
always enabled in the project managed by the module regardless of whether or not
you created the default VPC using the module:

- `compute.googleapis.com`
- `dns.googleapis.com`
- `iap.googleapis.com`

In this release, Compute Engine-related services are no longer enabled by
default when you don't provision a default VPC using the module.

If you relied on the silent enabling of Compute Engine-related services, don't
plan to continue using the default VPC provisioned by the module and still need
the Compute Engine-related services to be enabled, make sure to list all the
services that you require in the `enabled_services` input variable of the
module.

To completely restore the previous behaviour, include the previously
automatically enabled service in the `enabled_services` input variable:

```hcl
enabled_services = [
  "compute.googleapis.com",
  "dns.googleapis.com",
  "iap.googleapis.com",
  # ...
]
```

#### `enabled_services_disable_on_destroy` Changed Default Behaviour

Services which are enabled via the module are no longer disabled by default when
they are no longer listed in the `enabled_services` input of the module. You can
set the `enabled_services_disable_on_destroy` input variable to `true` to
preserve the behaviour of the previous module version.

This change only becomes effective after the first apply. The first apply after
upgrading to v3 will still be processed by Terraform using the previous default
of disabling services in Google Cloud that are no longer listed. This can cause
a problem in connection with
[the network-related changes](#compute-network-related-changes). See this
section for more information about the recommended mitigation steps.

#### DNS Policy

The module creates a DNS logging policy to be compliant wit latest Cloud
Policies. Therefore, your IaC Account needs the `roles/dns.admin` role on
project level. Please ensure to grant the required role to the service account
used to run the Terraform code against your infrastructure.

#### Firewall Rules

> [!CAUTION]
> **For compliance with the latest Cloud Policies, certain firewall rules were
> removed:**
>
> - All firewall rules related to public ingress:
>
>   The removed firewall rules include IP ranges for networks which are
>   generally owned by METRO but should not automatically be considered trusted.
>   If you need such firewalls, you can still create similar ones. Ensure you
>   are compliant with the latest Cloud Policies.
>
> - The firewall rule allowing all traffic within the VPC:
>
>   If you require traffic to be passed between different Compute Engine
>   instances, regardless of their subnetwork, you should create specific
>   firewall rules allowing this traffic based on a network tag or preferably
>   the service account of the respective workload.

To simplify firewall rule creation, IP address ranges and other details of the
generated VPC are available in the [`vpc` output][terraform-outputs].

Additionally, support for fine-grained configuration of created firewall rules
was added. See the [`firewall_rules` input variable][terraform-inputs].

### Outputs

#### Changes for `service_accounts`

The [`service_accounts` output][terraform-outputs] was adjusted to return more
details about the created service accounts. The `key` remains unchanged, but the
value now contains attributes of the created service account:

- email: The e-mail address of the service account.
- id: An identifier for the resource in the format
  `projects/{{project}}/serviceAccounts/{{email}}`.
- member: The identity of the service account in the form
  `serviceAccount:{email}`. This value is often used to refer to the service
  account when granting IAM permissions.
- unique_id: The unique ID of the service account.

If you used the output to reference the created service account, for example to
assign permissions to it on resources created outside of the module, you need to
update your Terraform code.

**Old Usage of Output Within an IAM Policy**

```hcl
data "google_iam_policy" "admin" {
  binding {
    role = "roles/compute.instanceAdmin"

    members = [
      "serviceAccount:${module.projectcfg.service_accounts["terraform-iac-pipeline"]}",
    ]
  }
}
```

**Updated Usage of Output Within an IAM Policy**

```hcl
data "google_iam_policy" "admin" {
  binding {
    role = "roles/compute.instanceAdmin"

    members = [
      module.projectcfg.service_accounts["terraform-iac-pipeline"].member,
    ]
  }
}
```

[changelog]: CHANGELOG.md
[compute engine default service account]: https://cloud.google.com/compute/docs/access/service-accounts#default_service_account
[faq-versioning]: FAQ.md#versioning
[latest-v2-release]: https://github.com/metro-digital/terraform-google-cf-projectcfg/releases?q=v2&expanded=false
[support]: https://metrodigital.atlassian.net/wiki/x/BwLMBw
[terraform-inputs]: TERRAFORM.md#inputs
[terraform-outputs]: TERRAFORM.md#outputs
[version constraint]: https://developer.hashicorp.com/terraform/language/expressions/version-constraints
[vm-create-user-sa]: https://cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances
[vm-update-user-sa]: https://cloud.google.com/compute/docs/instances/change-service-account
