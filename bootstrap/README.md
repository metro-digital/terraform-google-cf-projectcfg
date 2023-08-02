# Bootstrap

A Shell script (and Terraform module) to prepare given GCP project as expected by the Cloud Foundation.

## Usage

As absolute minimum only one parameter is required with the ID of the GCP project to work on:

```sh
root in ~/terraform-google-cf-projectcfg/bootstrap
# ./bootstrap.sh -p cf-metrocf-bartek-test-1-18
```

There are other optional parameters that can alter the behaviour of the script:

```sh
    Cloud Foundation Project Configuration Bootstrapper

    Usage:
      $0 -p [GCP_PROJECT_ID]

    Options:
      -p (required) GCP Project ID
      -s (optional) Name of the service account that will be used to execute
                    Terraform changes (default: terraform-iac-pipeline).
      -b (optional) Bucket name without 'gs://' which will store the Terraform
                    state files (default: 'tf-state-<GCP_PROJECT_ID>').
      -o (optional) relative or absolute path to directory that will store the
                    generated Terraform code (default: 'iac-output').
      -g (optional) GitHub repository in the format '<owner/org>/<reponame>'. If
                    given, the Terraform code will be configured to enable the Workload
                    Identity Federation support for GitHub Workflows. This is
                    required for keyless authentication from GitHub Workflows which
                    is strongly recommended. This can also be set up later.
      -t (optional) Time to sleep for in between bootstrap stages exectution,
              required for GCP IAM changes to propagate (default: '5m').
      -n (optional) If set, no Terraform code is generated. Only the service
                    account and state bucket are created. In addition the needed
                    APIs are enabled. Only use this option if you use a different
                    template for newly created GCP projects.
```

## How it works

The `bootstrap.sh` script is using [Terraform](https://www.terraform.io/) to execute set of actions on a given [GCP project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) in order to prepare it for further usage with Terraform and [Service Account impersonation](https://cloud.google.com/docs/authentication/use-service-account-impersonation) in a standardised way, as expected and recommended by the Cloud Foundation.

The whole bootstrapping process is happening in two stages:

1. Terraform code from the `terraform` directory is being run using the executing user access to the [GCP IAM](https://cloud.google.com/iam/docs/groups-in-cloud-console) `manager_group` and does the following (in a nutshell):

   - Grants the `manager_group` additional roles needed to perform the whole process
   - Creates a service account intended for future use with Terraform IaC (also used in second stage)
   - Creates a [GCP storage bucket](https://cloud.google.com/storage/docs/buckets) for Terraform [state file](https://developer.hashicorp.com/terraform/language/settings/backends/gcs)
   - Generates Terraform code in output directory (by default: `iac-output`) to be used in second stage and further by the project users
   - Sleeps for a given duration (by default: 5m) to give GCP time to [synchronize the IAM changes](https://cloud.google.com/iam/docs/access-change-propagation) to the groups, service accounts, etc.

1. Terraform code from the `iac-output` (or a different one, if the `-o` parameter was used) is being run using the service account created in the first stage and does the following (in a nutshell):

   - Sets up Terraform backend to use the GCP bucket created in the first stage
   - Migrates the state to the GCP bucket
   - [Imports the existing resources](https://developer.hashicorp.com/terraform/language/import) in the project (created in the first stage) into the remote stage to match the code generated in the `iac-output` directory
   - Sets up the project (using the `metro-digital/cf-projectcfg/google` module)

Once the script exited without any errors the project is ready to use and the `iac-output` directory can be used as a base for the Terraform IaC for the given project. The file `imports.tf` is no longer needed and can be deleted from the repository.

### Caveats

#### IAM roles flapping

The script can be run subsequently and should cause no issues that way, but given the way the first stage is working, one can observe a minor 'flapping' in the Terraform execution outputs, where first stage grants additional roles to the `manager_group` and the second stage removes them:

```sh
    (output stripped)

      # google_project_iam_member.manager_group["roles/iam.serviceAccountAdmin"] will be created
      + resource "google_project_iam_member" "manager_group" {
          + etag    = (known after apply)
          + id      = (known after apply)
          + member  = "group:metrocf.bartek-test-1-manager@metrosystems.net"
          + project = "cf-metrocf-bartek-test-1-18"
          + role    = "roles/iam.serviceAccountAdmin"
        }

      # google_project_iam_member.manager_group["roles/serviceusage.serviceUsageAdmin"] will be created
      + resource "google_project_iam_member" "manager_group" {
          + etag    = (known after apply)
          + id      = (known after apply)
          + member  = "group:metrocf.bartek-test-1-manager@metrosystems.net"
          + project = "cf-metrocf-bartek-test-1-18"
          + role    = "roles/serviceusage.serviceUsageAdmin"
        }

      # google_project_iam_member.manager_group["roles/storage.admin"] will be created
      + resource "google_project_iam_member" "manager_group" {
          + etag    = (known after apply)
          + id      = (known after apply)
          + member  = "group:metrocf.bartek-test-1-manager@metrosystems.net"
          + project = "cf-metrocf-bartek-test-1-18"
          + role    = "roles/storage.admin"
        }

    (output stripped)
```

And second stage execution:

```sh
    (output stripped)

      # module.project-cfg.google_project_iam_binding.roles["roles/iam.serviceAccountAdmin"] will be updated in-place
      ~ resource "google_project_iam_binding" "roles" {
            id      = "cf-metrocf-bartek-test-1-18/roles/iam.serviceAccountAdmin"
          ~ members = [
              - "group:metrocf.bartek-test-1-manager@metrosystems.net",
                # (1 unchanged element hidden)
            ]
            # (3 unchanged attributes hidden)
        }

      # module.project-cfg.google_project_iam_binding.roles["roles/serviceusage.serviceUsageAdmin"] will be updated in-place
      ~ resource "google_project_iam_binding" "roles" {
            id      = "cf-metrocf-bartek-test-1-18/roles/serviceusage.serviceUsageAdmin"
          ~ members = [
              - "group:metrocf.bartek-test-1-manager@metrosystems.net",
                # (1 unchanged element hidden)
            ]
            # (3 unchanged attributes hidden)
        }

      # module.project-cfg.google_project_iam_binding.roles["roles/storage.admin"] will be updated in-place
      ~ resource "google_project_iam_binding" "roles" {
            id      = "cf-metrocf-bartek-test-1-18/roles/storage.admin"
          ~ members = [
              - "group:metrocf.bartek-test-1-manager@metrosystems.net",
                # (1 unchanged element hidden)
            ]
            # (3 unchanged attributes hidden)
        }

    (output stripped)
```

This is expected behaviour and should not cause any issues.

#### Subsequent executions

The script can also be run by another user who didn't run it initially, granted they are also provided the local Terraform state file generated by the fist stage and the access to the `manager_group` for the second stage.

If needed, it is also possible to run the first and second stage separately, by manually calling relevant Terraform commands from either the `terraform` or `iac-output` directory.

#### Terraform state file importance

**When working on Terraform state files it is strongly recommended to always make a copy of local or remote state file.**

In case where the local Terraform state for the first stage would be lost and another execution would be needed, either recovering the state file from backup or removing the resources created by the first stage (most importantly the service account and the storage bucket) would make it possible to run it again.

## Requirements

- Google [Cloud SDK](https://cloud.google.com/sdk/docs/install-sdk)
- Terraform [1.5.0 or newer](https://developer.hashicorp.com/terraform/downloads) (for import functionality)
- [jq](https://jqlang.github.io/jq/) JSON processor
