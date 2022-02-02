# Frequently Asked Questions

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [IAM](#iam)
  - [How to grant project level permissions to a service account](#how-to-grant-project-level-permissions-to-a-service-account)
  - [Can I use GKE Workload Identify with this module?](#can-i-use-gke-workload-identify-with-this-module)
- [terraform](#terraform)
  - [How to prepare a new generated project for this module?](#how-to-prepare-a-new-generated-project-for-this-module)
  - [Error creating Network: googleapi: Error 409: The resource 'projects/<projectid>/global/networks/default' already exists](#error-creating-network-googleapi-error-409-the-resource-projectsprojectidglobalnetworksdefault-already-exists)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## IAM

### How to grant project level permissions to a service account

You can grant project level permissions to a service account using the `roles` input

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8S SA to use it for WorkLoad Identity
  service_accounts = {
    # ...
    bq-reader = {
      display_name = "BigQuery Reader"
      iam = {}    # see comment below!
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

Please note the empty `iam` parameter inside the Service Account definition. This is used for IAM rules applied to the
Service Account as resource. See [GKE Workload Identify example](#can-i-use-gke-workload-identify-with-this-module) how
to use this.

### Can I use GKE Workload Identify with this module?

Yes you can! Just create the Service Account(s) with correct IAM permissions and map them to your Kubernetes
Service Account. If you configure this Service Account for a pod, the pod will run with permissions of that GCP
Service Account.

Example:

```hcl
module "project-cfg" {
  source     = "git@github.com:metro-digital-inner-source/terraform-google-metrocf-projectcfg.git"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8S SA to use it for WorkLoad Identity
  service_accounts = {
    # ...
    bq-reader = {
      display_name = "BigQuery Reader"
      iam = {
        "roles/iam.workloadIdentityUser" = [
          "serviceAccount:metro-cf-example-ex1-e8v.svc.id.goog[default/bq]"
        ]
      }
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

Option A: Delete the network: terraform state import

Option B: Import the network into your terraform state (may also result in a delete at next terraform run depending on the networks configuration)
