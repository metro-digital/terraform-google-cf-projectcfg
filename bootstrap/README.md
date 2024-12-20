# Google Cloud Project Bootstrapping

You can use this project bootstrapping script to start managing your Google
Cloud project via Terraform. Bootstrapping a project leverages the Google
principal you are locally authenticated as to provision the minimum amount of
resources required for Terraform to take over the project's management and
generate Terraform code which you can use as the basis for all further project
management.

Bootstrapping a project is idempotent. You can run it multiple times without
worrying about _bricking_ the project.

> [!WARNING]
> The bootstrapping functionality is designed to be executed on freshly created
> Google Cloud projects. However, you can also run it on projects that were
> previously managed by hand or a different Terraform setup. In this case, we
> recommend you to run the bootstrap script with the `-i` parameter which
> ensures that the generated code is not automatically applied and can be
> reviewed.

## Requirements

Make sure that you have installed the following dependencies on your machine.

- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install-sdk)
- [Terraform v1.5.0 or newer](https://developer.hashicorp.com/terraform/downloads)
- [jq](https://jqlang.github.io/jq/)

## Getting Started

1. **Ensure `gcloud` is configured and authenticated:**

   As the bootstrap script uses your locally authenticated Google principal,
   ensure that you are authenticated as a user that is *inside the manager group
   of the project that you want to bootstrap*. Your application-default
   credentials must also be valid.

   ```sh
   gcloud auth login --update-adc
   ```

1. **Clone the repository:**

   Make sure to replace `<LATEST RELEASE TAG>` with the latest release tag which
   can be found
   [here](https://github.com/metro-digital/terraform-google-cf-projectcfg/releases).

   ```sh
   git clone https://github.com/metro-digital/terraform-google-cf-projectcfg.git terraform-projectcfg \
     --depth 1 --branch <LATEST RELEASE TAG>

   cd terraform-projectcfg/bootstrap
   ```

1. **Bootstrap your project:**

   As absolute minimum only one parameter is required with the ID of the Google
   Cloud project that should be bootstrapped. Make sure to replace
   `<GOOGLE CLOUD PROJECT ID>` with your project ID.

   ```sh
   ./bootstrap.sh -p <GOOGLE CLOUD PROJECT ID>
   ```

   Your generated and applied Terraform code can now be found in the
   `iac-output` directory. This is also a good time to set up your own Git
   repository and copy the outputs of the `iac-output` directory to it. It
   doesn't contain any sensitive values.

## Usage

There are other, optional parameters that can alter the behaviour of the
bootstrap script. Run the script with the `-h` flag for more information:

```sh
./bootstrap.sh -h
```

## How It Works

The `bootstrap.sh` script is using [Terraform](https://www.terraform.io/) to
execute set of actions on a given
[GCP project](https://cloud.google.com/resource-manager/docs/creating-managing-projects)
in order to prepare it for further usage with Terraform and
[Service Account impersonation](https://cloud.google.com/docs/authentication/use-service-account-impersonation)
in a standardised way, as expected and recommended by Cloud Foundation.

The whole bootstrapping process is happening in two stages:

1. Terraform code from the `terraform` directory is run using a user who is a
   member of the *manager group* of the given Google Cloud project. The code
   does the following (in a nutshell):

   - Grants the *manager group* additional roles needed to perform the whole
     process.
   - Creates a service account intended for future use with Terraform IaC (also
     used in second stage).
   - Creates a
     [GCP storage bucket](https://cloud.google.com/storage/docs/buckets) for
     Terraform
     [state file](https://developer.hashicorp.com/terraform/language/settings/backends/gcs).
   - Generates Terraform code in output directory (by default: `iac-output`) to
     be used in second stage and further by the project users.
   - Sleeps for a given duration (by default: 5m) to give GCP time to
     [synchronize the IAM changes](https://cloud.google.com/iam/docs/access-change-propagation)
     to the groups, service accounts, etc. This is unfortunately required
     because Google heavily caches IAM policy changes.

1. Terraform code from the `iac-output` (or a different one, if the `-o`
   parameter was used) is run using the service account created in the first
   stage and does the following (in a nutshell):

   - Sets up Terraform backend to use the GCP bucket created in the first stage.
   - Migrates the state to the GCP bucket.
   - [Imports the existing resources](https://developer.hashicorp.com/terraform/language/import)
     in the project (created in the first stage) into the remote stage to match
     the code generated in the `iac-output` directory.
   - Sets up the project (using the `metro-digital/cf-projectcfg/google`
     module).

Once the script exited without any errors the project is ready to use and the
`iac-output` directory can be used as a base for the Terraform IaC for the given
project. The file `imports.tf` is no longer needed and can be deleted from the
repository.

### Caveats

#### IAM roles flapping

The script can be run subsequently and should cause no issues that way, but
given the way the first stage is working, one can observe a minor 'flapping' in
the Terraform execution outputs, where first stage grants additional roles to
the *manager group* and the second stage removes them:

```text
(output stripped)

  # google_project_iam_member.manager_group["roles/iam.serviceAccountAdmin"] will be created
  + resource "google_project_iam_member" "manager_group" {
      + etag    = (known after apply)
      + id      = (known after apply)
      + member  = "group:customer.example-manager@metrosystems.net"
      + project = "cf-customer-example-18"
      + role    = "roles/iam.serviceAccountAdmin"
    }

  # google_project_iam_member.manager_group["roles/serviceusage.serviceUsageAdmin"] will be created
  + resource "google_project_iam_member" "manager_group" {
      + etag    = (known after apply)
      + id      = (known after apply)
      + member  = "group:customer.example-manager@metrosystems.net"
      + project = "cf-customer-example-18"
      + role    = "roles/serviceusage.serviceUsageAdmin"
    }

  # google_project_iam_member.manager_group["roles/storage.admin"] will be created
  + resource "google_project_iam_member" "manager_group" {
      + etag    = (known after apply)
      + id      = (known after apply)
      + member  = "group:customer.example-manager@metrosystems.net"
      + project = "cf-customer-example-18"
      + role    = "roles/storage.admin"
    }

(output stripped)
```

And second stage execution:

```text
(output stripped)

# module.projectcfg.google_project_iam_policy.this will be updated in-place
~ resource "google_project_iam_policy" "this" {
      id          = "cf-customer-example-18"
    ~ policy_data = jsonencode(
        ~ {
            ~ bindings = [
                ~ {
                    ~ members = [
                        - "group:customer.example-manager@metrosystems.net",
                          "serviceAccount:terraform-iac-pipeline@cf-customer-example-18.iam.gserviceaccount.com",
                      ]
                      # (1 unchanged attribute hidden)
                  },
                ~ {
                    ~ members = [
                        - "group:customer.example-manager@metrosystems.net",
                          "serviceAccount:terraform-iac-pipeline@cf-customer-example-18.iam.gserviceaccount.com",
                      ]
                      # (1 unchanged attribute hidden)
                  },
                ~ {
                    ~ members = [
                        - "group:customer.example-manager@metrosystems.net",
                          "serviceAccount:terraform-iac-pipeline@cf-customer-example-18.iam.gserviceaccount.com",
                      ]
                      # (1 unchanged attribute hidden)
                  },

(output stripped)
```

This is expected behaviour and should not cause any issues.
