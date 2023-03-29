# Frequently Asked Questions

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [IAM](#iam)
  - [How to grant project level permissions to a service account](#how-to-grant-project-level-permissions-to-a-service-account)
  - [How can I allow Service Account impersonation?](#how-can-i-allow-service-account-impersonation)
  - [Can I use GKE Workload Identity with this module?](#can-i-use-gke-workload-identity-with-this-module)
- [terraform](#terraform)
  - [How to prepare a new generated project for this module?](#how-to-prepare-a-new-generated-project-for-this-module)
  - [Error creating Network: googleapi: Error 409: The resource 'projects/<projectid>/global/networks/default' already exists](#error-creating-network-googleapi-error-409-the-resource-projectsprojectidglobalnetworksdefault-already-exists)
  - [Error: Error waiting for Create Service Networking Connection: Error code 7, message: Required 'compute.globalAddresses.list' permission for 'projects/<project_number>'](#error-error-waiting-for-create-service-networking-connection-error-code-7-message-required-computeglobaladdresseslist-permission-for-projectsproject_number)
- [GitHub](#github)
  - [How to use Workload Identity Federation with GitHub Actions](#how-to-use-workload-identity-federation-with-github-actions)
  - [Error creating WorkloadIdentityPool - Error 403: Permission 'iam.workloadIdentityPools.create' denied on resource](#error-creating-workloadidentitypool---error-403-permission-iamworkloadidentitypoolscreate-denied-on-resource)
  - [Error creating WorkloadIdentityPool - Error 409: Requested entity already exists](#error-creating-workloadidentitypool---error-409-requested-entity-already-exists)
- [Cloud Native Runtime Kubernetes Clusters](#cloud-native-runtime-kubernetes-clusters)
  - [How to use Workload Identity Federation](#how-to-use-workload-identity-federation)

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
    bq-reader = {
      display_name = "BigQuery Reader"
      iam          = {} # see comment below!
      # Grant this service account the BigQuery user role on project level.
      project_roles = [
        "roles/bigquery.user"
      ]
    }

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
service account, considering the service account as a resource. **It's
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

### Can I use GKE Workload Identity with this module?

Yes you can! Just create the Service Account(s) with correct IAM permissions
and map them to your Kubernetes Service Account. If you configure this
Service Account for a pod, the pod will run with permissions of that GCP
Service Account.

In the following example, the service account `bq` inside the Kubernetes
namespace `default` is mapped to the IAM service account `bq-reader`.

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8S SA to use it for WorkLoad Identity
  service_accounts = {
    bq-reader = {
      display_name = "BigQuery Reader"
      description  = "Used to read data from my dataset."
      iam          = {
        "roles/iam.workloadIdentityUser" = [
          "serviceAccount:metro-cf-example-ex1-e8v.svc.id.goog[default/bq]"
        ]
      }
      project_roles = [
        "roles/bigquery.jobUser",
        "roles/bigquery.dataViewer"
      ]
    }

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

### Error: Error waiting for Create Service Networking Connection: Error code 7, message: Required 'compute.globalAddresses.list' permission for 'projects/<project_number>'

This module makes sure that the `servicenetworking.googleapis.com` service is enabled. Our bootstrap script also activates the service. Activating this service creates an internal google service account `service-<project_number>@service-networking.iam.gserviceaccount.com` binded to a `servicenetworking.serviceAgent` role. This service and its properly configured internal service account are crucial for many parts of the code around network operations.

For some reasons like, for example, a human error or a faulty terraform code, sometimes you might end up in a situation when terraform fails with an error from above due to missing needed role binding. In some cases errors might look a bit different and hard to track to exact problems as you might try to make sure that your IAC account has permissions from the error message and it would have it, leaving you with no clue what is wrong.

If you encounter such cases please make sure the service's internal service account has proper binding. Add needed role in UI or with help of `gcloud`:
`gcloud projects add-iam-policy-binding <project_id> --member='serviceAccount:service-<project_number>@service-networking.iam.gserviceaccount.com' --role='roles/servicenetworking.serviceAgent'`


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
      github_action_repositories = [
        "metro-digital-inner-source/<your repository>"
      ]
    }
    # ...
  }
  # ...
}
```

**Remark:** You need to grant the role `roles/iam.workloadIdentityPoolAdmin` to the principal that is
executing the terraform code (most likely your service account used in your pipeline) if you plan to use
`github_action_repositories`.

Setting the `github_action_repositories` parameter will create a default Workload Identity Pool named
"github-actions" and a Workload Identity Pool provider, named "GitHub". This is reflected in the code snippet
below under `workload_identity_provider`. You need to set the `permissions` block to grant your id-token the
intended permissions. After that, you can use this [GitHub action](https://github.com/google-github-actions/auth)
to authenticate inside your flow:

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

### Error creating WorkloadIdentityPool - Error 403: Permission 'iam.workloadIdentityPools.create' denied on resource

If you are facing an error similar to this:
```
Error creating WorkloadIdentityPool: googleapi: Error 403: Permission 'iam.workloadIdentityPools.create' denied on resource '//iam.googleapis.com/projects/<GCP PROJECT>/locations/global' (or it may not exist).
```

You may need to grant `roles/iam.workloadIdentityPoolAdmin` to your service account. This is also the case if you
grant the role via this module; even if the pool itself has some dependency on the IAM permission, terraform may not wait long enough.
Please be aware Google Cloud Platform may need a few minutes to pick up this IAM change; if you still see the error after granting the role, please wait a few minutes and try again. If the error persists, feel free to reach out to the Cloud Foundation team if needed.

### Error creating WorkloadIdentityPool - Error 409: Requested entity already exists

This usually happens if you created the pool via terraform and destroyed it again. To solve the issue you need to:

1. Grant yourself `roles/iam.workloadIdentityPoolAdmin` on the project, and navigate to [workload identity pools].
1. Enable `Show deleted pools and providers`
1. Restore the pool with ID `github-actions`
1. Restore the pool provider with ID `github`

After you restored your pool and provider, you need to import them into your terraform state:
```shell
export GCP_PROJECT_ID="<YOUR GOOGLE PROJECT ID>"
terraform import 'module.project-cfg.google_iam_workload_identity_pool.github-actions[0]' $GCP_PROJECT_ID/github-actions
terraform import 'module.project-cfg.google_iam_workload_identity_pool_provider.github[0]' $GCP_PROJECT_ID/github-actions/github
```

## Cloud Native Runtime Kubernetes Clusters

### How to use Workload Identity Federation
Cloud Native Runtime clusters support [Workload Identity Federation via OIDC provider](https://confluence.metrosystems.net/x/rLT3Ig).
For details on the Kubernetes-related configuration, please see the documentation provided by the Runtime team. Within
your Cloud Foundation project, you need to set up a Workload Identity Pool and attach an OIDC provider per cluster.
This is done by this module automatically, if you configure a Service Account to be used from a Runtime kubernetes cluster:

```hcl
module "project-cfg" {
  source     = "metro-digital/cf-projectcfg/google"
  project_id = "metro-cf-example-ex1-e8v"

  # ...

  # Create a Service Account and allow a K8s SA to use it via WorkLoad Identity Federation
  service_accounts = {
    # ...
    runtime-sa = {
      display_name  = "My Runtime Workload"
      description   = "Workload running in Cloud Native Runtime Cluster"

      # No special permissions in the Service Accounts IAM policy
      iam = {}

      # Allow this Service Account to execute BigQuery jobs
      # Access to certain datasets is configured in the dataset's IAM policy, so no project level
      # access is required (least privileges approach)
      project_roles = [
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
    }
    # ...
  }
  # ...
}
```

Within your Kubernetes configuration, adjust the Service Account definition like this:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    cloud.google.com/audience: cf.metro.cloud/wif-cloud-native-runtime
    cloud.google.com/service-account-email: <GCP Service Account Email>
    cloud.google.com/token-expiration: "3600"
    cloud.google.com/workload-identity-provider: projects/<GCP Project Number>/locations/global/workloadIdentityPools/<MD5 Sum of Runtime Cluster ID>/providers/kubernetes
  name: <K8s Service Account Name>
```

Ensure you replace Service Account E-Mail, Project Number and MD5 Sum of Runtime Cluster ID with the correct values.

You can get the project number using the UI by navigating to your [project's dashboard](https://console.cloud.google.com/home/dashboard)
or via the following gcloud command:

```shell
gcloud projects describe YOUR_GCP_PROJECT_ID --format='value(projectNumber)'
```

The Workload Identity Provider Pool can be found via the UI by navigating to the [IAM and admin -> Workload Identity Federation section](https://console.cloud.google.com/iam-admin/workload-identity-pools).
Alternatively, you can list the Pool via the following gcloud command:

```shell
gcloud iam workload-identity-pools list --project YOUR_GCP_PROJECT_ID --location global
```

[workload identity pools]: https://console.cloud.google.com/iam-admin/workload-identity-pools
[terraform network import]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network#import
[terraform subnetwork import]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork#import
