# Bootstrap

Script to setup a project for the project-cfg module.

```
Cloud Foundation Project config bootstrapper
--
Call: ./bootstrap.sh -m <MODE> -p <GCP_PROJECT_ID> [-s <SA_NAME>] [-s <GCS_BUCKET_NAME>] [-o <DIR_PATH>]
  -m 	MODE can be terraform or terragrunt
  -p	GCP Project ID
  -s	The Service Account name (default: terraform-iac-pipeline)
  -b    The bucket name without gs:// (default: tf-state-<GCP_PROJECT_ID>) to store terraform state files
  -o	(relativ|absolut) path to directory to store genereated terraform/terragrunt code (Default: iac-output)
```