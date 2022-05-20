# Frequently Asked Questions

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [IAM](#iam)
  - [How to grant project level permissions to a service account](#how-to-grant-project-level-permissions-to-a-service-account)
  - [How can I allow Service Account impersonation?](#how-can-i-allow-service-account-impersonation)
  - [Can I use GKE Workload Identify with this module?](#can-i-use-gke-workload-identify-with-this-module)
- [terraform](#terraform)
  - [How to prepare a new generated project for this module?](#how-to-prepare-a-new-generated-project-for-this-module)
  - [Error creating Network: googleapi: Error 409: The resource 'projects/<projectid>/global/networks/default' already exists](#error-creating-network-googleapi-error-409-the-resource-projectsprojectidglobalnetworksdefault-already-exists)
- [GitHub](#github)
  - [How to use Workload Identity Federation with GitHub Actions](#how-to-use-workload-identity-federation-with-github-actions)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## IAM

### How to grant project level permissions to a service account

You can grant project level permissions to a service account using the `roles` input

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account
  service_accounts = {
    # ...
    bq-reader = {
      display_name = "BigQuery Reader"
      iam          = {}    # see comment below!
    }
    # ...
  }

  # Grant BigQuery permissions to SA
  "roles" = {
    # ...
    "roles/bigquery.user" = [
      # ...
      "serviceAccount:bq-reader@metro-cf-example-ex1-e8v.iam.gserviceaccount.com"
      # ...
    ]
    # ...
  }
  # ...
}
```

Please note the empty `iam` parameter inside the Service Account definition.
This is used for IAM rules applied to the Service Account as resource. See
[How can I allow Service Account impersonation?](#how-can-i-allow-service-account-impersonation)
or [Can I use GKE Workload Identify with this module?](#can-i-use-gke-workload-identify-with-this-module) how to use this.

### How can I allow Service Account impersonation?

You can grant some other member permissions to impersonate a specific service account by granting the role `roles/iam.serviceAccountTokenCreator`.

This role can be granted on

- project level IAM policy
- resource level IAM policy

Resource level IAM policy means the IAM policy assigned to a specific
service account threading the service account as a resource. **It's
recommended to grant the role on resource level** to ensure the given member
can only impersonate specific service accounts. Granting it on project level
will allow the member to impersonate all service accounts within the project!

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8S SA to use it for WorkLoad Identity
  service_accounts = {
    # ...
    some-sa = {
      display_name = "Some example Service Account"
      iam          = {
        "roles/iam.serviceAccountTokenCreator" = [
          "group:example-group@metronom.com"
        ]
      }
    }
    # ...
  }

  # ...
}
```

### Can I use GKE Workload Identify with this module?

Yes you can! Just create the Service Account(s) with correct IAM permissions
and map them to your Kubernetes Service Account. If you configure this
Service Account for a pod, the pod will run with permissions of that GCP
Service Account.

Example:

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8S SA to use it for WorkLoad Identity
  service_accounts = {
    # ...
    some-pipeline-account = {
      display_name = "Used for GitHub Action pipeline in repository <someorg>/<somerepo>"
      iam          = {}
    }
    # ...
  }

  # Grant BigQuery permissions to SA
  "roles" = {
    # ...
    "roles/bigquery.user" = [
      # ...
      "serviceAccount:bq-reader@metro-cf-example-ex1-e8v.iam.gserviceaccount.com"
      # ...
    ]
    # ...
  }
  # ...
}
```

## terraform

### How to prepare a new generated project for this module?

See our [bootstrap](../bootstrap/README.md)

### Error creating Network: googleapi: Error 409: The resource 'projects/<projectid>/global/networks/default' already exists

For some reason there's already a network called default in your project.

*Option A:* Delete the network using the UI or via `gcloud` CLI

*Option B:* Import the network into your terraform state (may also result
into a deletion at next terraform run depending on the networks configuration)

See also:

- [terraform network import]
- [terraform subnetwork import]

## GitHub

### How to use Workload Identity Federation with GitHub Actions

The module allows you to configure the authentication within GitHub actions using Workload Identity Federation. To allow
the the use of a service account within a GitHub workflow run, you need to set the repository as a parameter for the service
account:

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8S SA to use it for WorkLoad Identity
  service_accounts = {
    # ...
    terraform-iac-pipeline = {
      display_name = "Service account used in IaC pipelines"
      iam = {}
    }
    github_action_repositories = [
      "metro-digital-inner-source/<your repository>"
    ]
    # ...
  }
  # ...
}
```

Setting the `github_action_repositories` parameter will create a default A Workload Identity Pool named "github-actions" and a Workload Identity Pool provider, named "GitHub". This is reflected in the code snipped below under `workload_identity_provider`<br>
You need to set the `permissions` block to grant your id-token the intended permissions.
After that, you can use this [GitHub action](https://github.com/google-github-actions/auth) to authenticate inside your flow:

```yaml
jobs:
  terraform:
    name: terraform
    runs-on: ubuntu-latest

    defaults:
      run:
        shell: bash
        working-directory: dev

    permissions:
      contents: 'read'
      id-token: 'write'

    steps:
      # ...
      - id: 'auth'
        name: 'Authenticate to Google Cloud'
        # Make sure to reference the most recent commit!
        uses: 'google-github-actions/auth@v0'
        with:
          workload_identity_provider: 'projects/<project number>/locations/global/workloadIdentityPools/github-actions/providers/github'
          service_account: 'terraform-iac-pipeline@metro-cf-example-ex1-e8v.iam.gserviceaccount.com'
      # ...
```

[terraform network import]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network#import
[terraform subnetwork import]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork#import
