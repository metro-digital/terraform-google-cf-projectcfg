#!/usr/bin/env bash

# Copyright 2022 METRO Digital GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -u

# Helpers
TEXT_BOLD="$(tput bold)"
TEXT_COLOR_RED="$(tput setaf 1)"
TEXT_COLOR_YELLOW="$(tput setaf 3)"
TEXT_COLOR_MAGENTA="$(tput setaf 5)"
TEXT_ALL_OFF="$(tput sgr0)"

function log_error() {
	echo "${TEXT_BOLD}${TEXT_COLOR_RED}ERROR:${TEXT_ALL_OFF}${TEXT_COLOR_RED} ${1}${TEXT_ALL_OFF}" 2>&1 | fold -s -w 80
}

function check_program() {
	PRG=$(command -v "${1}" 2>/dev/null || true)
	if [ -z "${PRG}" ]; then
		log_error "Program \"$1\" not found"
		exit 1
	fi
}

function print_usage_and_exit() {
	cat <<-END_OF_DOC
		Cloud Foundation Project Configuration Bootstrapper

		Usage:
		  $0 -p [GCP_PROJECT_ID]

		Options:
		  -p (required) GCP Project ID
		  -s (optional) Name of the service account that will be used to execute
		                Terraform changes (default: terraform-iac-pipeline).
		  -b (optional) Bucket name without 'gs://' which will store the Terraform
		                state files (default: 'tf-state-<GCP_PROJECT_ID>').
		  -o (optional) relativ or absolute path to directory that will store the
		                generated Terraform code (default: 'iac-output').
		  -g (optional) GitHub repository in the format '<owner/org>/<reponame>'. If
		                given, the Terraform code will be configured to enable the Workload
		                Identity Federation support for GitHub Workflows. This is
		                required for keyless authentication from GitHub Workflows which
		                is strongly recommended. This can also be set up later.
		  -n (optional) If set, no Terraform code is generated. Only the service
		                account and state bucket are cretaed. In addition the needed
		                APIs are enabled. Only use this option if you use a different
		                template for newly created GCP projects.
	END_OF_DOC
	exit
}

function print_command_output_if_failure() {
	EXITCODE=$?
	cat <<-END_OF_ERROR
		${TEXT_COLOR_RED}The bootstrap script encountered an error. Please check the command
		output:${TEXT_ALL_OFF}
		---
		${COMMAND_OUTPUT}
		---
		If you are unsure about how to procced, feel free to reach out to the Cloud
		Foundation team. Please also provide the command output from above!
	END_OF_ERROR
	exit $EXITCODE
}

function set_command_output_trap() {
	trap print_command_output_if_failure INT TERM EXIT
	clear_command_output_buffer
}

function reset_command_output_trap() {
	trap - INT TERM EXIT
	clear_command_output_buffer
}

function clear_command_output_buffer() {
	COMMAND_OUTPUT=""
}

# Parameter parsing
while getopts ":p:s:b:o:g:nh" OPT; do
	case $OPT in
	p)
		GCP_PROJECT_ID="${OPTARG}"
		;;
	s)
		SA_NAME_PARAM="${OPTARG}"
		;;
	b)
		GCS_BUCKET_PARAM="${OPTARG}"
		;;
	o)
		OUTPUT_DIR_PARAM="${OPTARG}"
		;;
	g)
		GITHUB_REPOSITORY_PARAM="${OPTARG}"
		;;
	n)
		NO_CODE_GEN='true'
		;;
	:)
		log_error "Option -${OPTARG} requires an argument"
		exit 1
		;;
	\?)
		log_error "Invalid Option: -${OPTARG}"
		exit 1
		;;
	h)
		print_usage_and_exit
		;;
	esac
done

check_program gcloud
check_program gsutil
check_program jq
check_program find
check_program realpath
check_program terraform
check_program openssl
check_program xxd
check_program fold

# parameter validation / defaulting
SA_NAME="${SA_NAME_PARAM:-terraform-iac-pipeline}"
OUTPUT_DIR="${OUTPUT_DIR_PARAM:-iac-output}"

if [ "${GCS_BUCKET_PARAM:-notset}" = "notset" ]; then
	GCS_BUCKET="tf-state-${GCP_PROJECT_ID:-notset}"
else
	GCS_BUCKET="${GCS_BUCKET_PARAM}"
fi

if [ "${GITHUB_REPOSITORY_PARAM:-notset}" != "notset" ]; then
	GITHUB_REPOSITORY_SA_BLOCK_STRING="github_action_repositories = [ \"${GITHUB_REPOSITORY_PARAM}\" ]"
	GITHUB_REPOSITORY_IAM_BLOCK_STRING="\"roles/iam.workloadIdentityPoolAdmin\" = [ local.iam_iac_service_account ]"
else
	GITHUB_REPOSITORY_SA_BLOCK_STRING=""
	GITHUB_REPOSITORY_IAM_BLOCK_STRING=""
fi

echo "Fetching project details..."
# determinate active gcloud account
ACTIVE_GCLOUD_ACCOUNT="$(gcloud --quiet auth list --format json | jq -r '.[] | select(.status == "ACTIVE") | .account')"
if [ "${ACTIVE_GCLOUD_ACCOUNT:-notset}" = "notset" ]; then
	log_error "Unable to detect an active gcloud account! Please configure your gcloud CLI. See https://cloud.google.com/sdk/docs/install-sdk for more details."
	exit 1
fi

# check given gcp project
if [ "${GCP_PROJECT_ID:-notset}" = "notset" ]; then
	log_error "Missing GCP_PROJECT_ID! Make sure the '-p' parameter is correctly set." 1>&2
	exit 1
else
	GCP_PROJECT_NAME="$(gcloud projects list --format='value(name)' --filter="'$GCP_PROJECT_ID'")"
	if [ "${GCP_PROJECT_NAME}" = "" ]; then
		log_error "Unable to find a project with the given project ID '${GCP_PROJECT_ID}'!"
		log_error "Your active gcloud CLI account is '${ACTIVE_GCLOUD_ACCOUNT}'. Is the manager role (or a role with comparable permissions) assigned to this account inside the project?"
		exit 1
	fi
fi

#Getting project number
GCP_PROJECT_NUMBER="$(gcloud projects list --format='value(project_number)' --filter="'$GCP_PROJECT_ID'")"
if [ "${GCP_PROJECT_NUMBER}" = "" ]; then
	log_error "Unable to determine a project number with the given project ID '${GCP_PROJECT_ID}'!"
	log_error "Your active gcloud CLI account is '${ACTIVE_GCLOUD_ACCOUNT}'. Is the manager role (or a role with comparable permissions) assigned to this account inside the project?"
	exit 1
fi

# try to find Cloud Foundation Panel groups in IAM permissions
IAM_MANAGER_GROUP=$(gcloud --quiet projects get-iam-policy "${GCP_PROJECT_ID}" --format json | jq -r '.bindings[] | select(.role == "organizations/1049006825317/roles/CF_Project_Manager") | .members[] | select ( . | test("^group:.*-manager@(metrosystems\\.net|cloudfoundation\\.metro\\.digital)$"))')
if [ "${IAM_MANAGER_GROUP:-notset}" = "notset" ]; then
	log_error "Unable to find the manager group for the project ID '${GCP_PROJECT_NAME}'! Are you trying to bootstrap a Cloud Foundation project? Ensure that the 'CF Project Manager' role is assigned to the manager group inside the project."
	exit 1
fi
IAM_DEVELOPER_GROUP="${IAM_MANAGER_GROUP/-manager@/-developer@}"

# Variables used for output and inside terraform templates
DEVELOPER_GROUP="${IAM_DEVELOPER_GROUP#group:}"
MANAGER_GROUP="${IAM_MANAGER_GROUP#group:}"

if [ "${NO_CODE_GEN:-notset}" = 'true' ]; then
	OUTPUT_HINT="No Terraform code will be generated."
else
	OUTPUT_HINT=$(echo "The generated Terraform code will be written to '${OUTPUT_DIR}'." | fold -s -w 80)
fi

# all set - print details to user and ask to continue
cat <<-EOF

	+------------------------------------------------------------------------------+
	|                       PLEASE REVIEW YOUR CONFIGURATION                       |
	+------------------------------------------------------------------------------+

	This script will bootstrap the project '${GCP_PROJECT_NAME}'
	with ID '${GCP_PROJECT_ID}'.

	${TEXT_BOLD}Currently active gcloud account:${TEXT_ALL_OFF} ${ACTIVE_GCLOUD_ACCOUNT}
	${TEXT_BOLD}Detected manager group:${TEXT_ALL_OFF} ${MANAGER_GROUP}
	${TEXT_BOLD}Detected developer group:${TEXT_ALL_OFF} ${DEVELOPER_GROUP}

	The following ressources will be created (if they don't already exist):
	  * ${TEXT_BOLD}Service Account:${TEXT_ALL_OFF}
	      ${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
	  * ${TEXT_BOLD}GCS Bucket:${TEXT_ALL_OFF}
	      gs://$GCS_BUCKET

	${OUTPUT_HINT}
	${TEXT_BOLD}${TEXT_COLOR_MAGENTA}
	The active account needs the project manager role inside the Cloud Foundation
	Panel (or similar permissions). We assume that the permissions are granted to
	your active account, most likely by beeing member of the group
	'${MANAGER_GROUP}'.${TEXT_ALL_OFF}
	${TEXT_BOLD}
	Please also check the guide for this script if you are unsure about how to use
	it: https://confluence.metrosystems.net/x/rZOtG
	${TEXT_ALL_OFF}
EOF

read -p "Proceed (y/n)? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	log_error "Aborted."
	exit 1
fi

# Check application default credential setup
# 1. no env variable
if [ "${GOOGLE_APPLICATION_CREDENTIALS:-notset}" != "notset" ]; then
	log_error "You configured the Application Default Credentials using the 'GOOGLE_APPLICATION_CREDENTIALS' environment variable. This is not supported by the bootstrap script! Please unset the environment variable." 1>&2
	exit 1
fi

# 2. ensure credentials use currently active gcloud user
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
	echo "${TEXT_COLOR_RED}Application Default Credentials are not set up!${TEXT_ALL_OFF}"
	read -p "Configure them for the account '${ACTIVE_GCLOUD_ACCOUNT}' (y/n)? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		log_error "Aborted."
		exit 1
	fi
	echo
	if ! gcloud auth application-default login; then
		log_error "Error occured during Application Default Credentials setup ... can't proceed"
		exit 1
	fi
	echo
fi

# skip all tests for the output directory in case no output should be generated
if [[ "${NO_CODE_GEN:-notset}" != 'true' ]]; then
	if [[ ! -d "${OUTPUT_DIR}" ]]; then
		read -p "$(echo "Output directory '${OUTPUT_DIR}' does not exist. Create it (y/n)? " | fold -s -w 80)" -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			echo "Creating '${OUTPUT_DIR}'"
			if ! mkdir -p "${OUTPUT_DIR}"; then
				log_error "Could not create output directory... can't proceed"
				exit 1
			fi
		else
			log_error "Aborted."
			exit 1
		fi
	else
		if [ "$(ls -A "${OUTPUT_DIR}")" ]; then
			read -p "$(echo "Output directory '${OUTPUT_DIR}' is not empty. Continue anyway (y/n)? " | fold -s -w 80)" -n 1 -r
			echo
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				log_error "Aborted."
				exit 1
			fi
		fi
	fi
fi

# ensure we print the error stored in COMMAND_OUTPUT before exiting the script
set_command_output_trap

echo "Binding roles to manager group '${IAM_MANAGER_GROUP}'..." | fold -s -w 80
for role in roles/iam.serviceAccountAdmin roles/serviceusage.serviceUsageAdmin; do
	echo "  * Binding $role..."
	COMMAND_OUTPUT=$(gcloud --quiet projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
		--member="${IAM_MANAGER_GROUP}" \
		--role="$role" 2>&1)
done

echo "Enabling required APIs..."
# compute is enabled during bootstrap as it creates service account
# that needs permissions on project level. The "role only" apply
# may fail if this account doesnt exist, and the targeted apply
# ignores the dependencies
#
# servicenetworking is enabled as it needs a long preperation time,
# and as this is an async action terraform sometimes fails at initial
# runs (service not yet ready...)
REQUIRED_APIS=(
	"iam.googleapis.com"
	"cloudresourcemanager.googleapis.com"
	"serviceusage.googleapis.com"
	"compute.googleapis.com"
	"servicenetworking.googleapis.com"
)
for API in "${REQUIRED_APIS[@]}"; do
	echo "  * Enabling ${API}..."
	COMMAND_OUTPUT=$(gcloud --quiet services enable "${API}" --project "${GCP_PROJECT_ID}" 2>&1)
done

SA_FULL_NAME="${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# pipeline service account
SERVICE_ACCOUNT_CHECK=$(gcloud iam service-accounts list --project "${GCP_PROJECT_ID}" --filter "email=${SA_FULL_NAME}" --format "value(disabled)" 2>/dev/null)
if [ "${SERVICE_ACCOUNT_CHECK:-notset}" = "notset" ]; then # account does not exist
	echo "Creating service account ${SA_FULL_NAME}..." | fold -s -w 80
	COMMAND_OUTPUT=$(gcloud iam service-accounts create "${SA_NAME}" \
		--display-name "Service account used in IaC pipelines" \
		--project "${GCP_PROJECT_ID}" 2>&1)
elif [ "${SERVICE_ACCOUNT_CHECK}" = "True" ]; then
	log_error "Service account '${SA_FULL_NAME}' exists but seems to be disabled! Ensure that the service account is enabled."
	reset_command_output_trap
	exit 1
elif [ "${SERVICE_ACCOUNT_CHECK}" = "False" ]; then
	echo "${TEXT_COLOR_YELLOW}Service account '${SA_NAME}' already exists. Skipping creation.${TEXT_ALL_OFF}" | fold -s -w 80
else # whatever may happen else...
	log_error "Encountered an unknown error while checking the service account '${SA_FULL_NAME}'!"
	reset_command_output_trap
	exit 1
fi

REQUIRED_ROLES=(
	"roles/compute.networkAdmin"
	"roles/compute.securityAdmin"
	"roles/storage.admin"
	"roles/storage.objectAdmin"
	"roles/iam.serviceAccountKeyAdmin"
	"roles/iam.serviceAccountAdmin"
	"roles/iam.securityAdmin"
	"roles/iam.roleAdmin"
	"roles/serviceusage.serviceUsageAdmin"
)
echo "Binding roles to service account '${SA_FULL_NAME}'..." | fold -s -w 80
for ROLE in "${REQUIRED_ROLES[@]}"; do
	echo "  * Binding ${ROLE}..."
	COMMAND_OUTPUT=$(gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
		--member="serviceAccount:${SA_FULL_NAME}" \
		--role="${ROLE}" 2>&1)
done

# Creating the service networking service account and granting the needed service agent role
# to avoid issues. Sometimes this permissions are missing, leading to a very hard to track down
# error for users when running terraform.
echo "Ensuring Service Networking service account exists with permissions..."
COMMAND_OUTPUT=$(gcloud beta services identity create \
	--service=servicenetworking.googleapis.com \
	--project "${GCP_PROJECT_ID}" 2>&1)

COMMAND_OUTPUT=$(gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
	--member="serviceAccount:service-${GCP_PROJECT_NUMBER}@service-networking.iam.gserviceaccount.com" \
	--role="roles/servicenetworking.serviceAgent" 2>&1)

echo "Ensuring manager group can impersonate the service account..."
COMMAND_OUTPUT=$(gcloud iam service-accounts add-iam-policy-binding "${SA_FULL_NAME}" \
	--member="${IAM_MANAGER_GROUP}" --role="roles/iam.serviceAccountTokenCreator" \
	--project "${GCP_PROJECT_ID}" 2>&1)

# reset command output trap to avoid confusing error if gsutil fails with some error
reset_command_output_trap

echo "Waiting for GCP to pick up recent IAM changes..."
IAM_TEST_BUCKET_NAME="cf-bootstrap-$(date | openssl dgst -sha1 -binary | xxd -p)"
until GSUTIL_OUTPUT=$( (gsutil -i "${SA_FULL_NAME}" mb -c standard -b on -l EU -p "${GCP_PROJECT_ID}" "gs://${IAM_TEST_BUCKET_NAME}") 2>&1); do
	if [[ $GSUTIL_OUTPUT != *"AccessDeniedException: 403 $SA_FULL_NAME does not have storage.buckets.create access to the Google Cloud project."* ]]; then
		echo "${TEXT_COLOR_RED}Caught unexpected output!${TEXT_ALL_OFF}"
		echo "Please review the command output and fix the root cause:"
		echo "=============================================="
		echo "$GSUTIL_OUTPUT"
		echo "=============================================="
		echo
	fi
	echo "  * IAM permissions not propagated yet. Waiting another 5 seconds..."
	sleep 5
done

echo "Permissions propagated, cleaning up GCS test resource..."
until GSUTIL_OUTPUT=$( (gsutil -i "${SA_FULL_NAME}" rb "gs://${IAM_TEST_BUCKET_NAME}") 2>&1); do
	if [[ $GSUTIL_OUTPUT != *"Removing gs://${IAM_TEST_BUCKET_NAME}/..."* ]]; then
		echo "${TEXT_COLOR_RED}Caught unexpected output!${TEXT_ALL_OFF}"
		echo "Please review the command output and fix the root cause:"
		echo "=============================================="
		echo "$GSUTIL_OUTPUT"
		echo "=============================================="
		echo
	fi
	echo "  * Still cleaning up. Waiting another 5 seconds..."
	sleep 5
done

if GSUTIL_OUTPUT=$( (gsutil -i "${SA_FULL_NAME}" -q ls "gs://${GCS_BUCKET}") 2>&1); then
	if [[ $GSUTIL_OUTPUT != *"gs://${GCS_BUCKET}/"* ]]; then
		echo "${TEXT_COLOR_RED}Caught unexpected output!${TEXT_ALL_OFF}"
		echo "Please review the command output and fix the root cause:"
		echo "=============================================="
		echo "$GSUTIL_OUTPUT"
		echo "=============================================="
		echo
	fi
	echo "${TEXT_COLOR_YELLOW}GCS bucket ${GCS_BUCKET} already exists. Skipping creation.${TEXT_ALL_OFF}" | fold -s -w 80
else
	echo "Creating GCS bucket for Terraform state..."
	if ! gsutil -i "${SA_FULL_NAME}" mb -c standard -b on -l EU -p "${GCP_PROJECT_ID}" "gs://${GCS_BUCKET}"; then
		log_error "Error occured during GCS bucket creation ... can't proceed"
		exit 1
	fi
fi
set_command_output_trap

# Create IaC code from template
TEMPLATE_BASEDIR=$(dirname "${BASH_SOURCE[0]}")
TEMPLATE_DIR="${TEMPLATE_BASEDIR}/templates/"

if [ "${NO_CODE_GEN:-notset}" = 'true' ]; then
	echo "${TEXT_COLOR_MAGENTA}${TEXT_BOLD}Not generating any Terraform code. Stopping the bootstrap process...${TEXT_ALL_OFF}"
	reset_command_output_trap
	exit
fi

# export variables to make them accessible for envsubst
export GCP_PROJECT_ID
export GCS_BUCKET
export SA_FULL_NAME
export SA_SHORT_NAME="${SA_NAME}"
export MANAGER_GROUP
export DEVELOPER_GROUP
export GITHUB_REPOSITORY_SA_BLOCK_STRING
export GITHUB_REPOSITORY_IAM_BLOCK_STRING

echo "Generating Terraform code..."
while IFS= read -r -d '' SOURCE_FILE; do
	TARGET_FILE_BASE=$(basename "${SOURCE_FILE}" .in)
	TARGET_FILE="${OUTPUT_DIR}/${TARGET_FILE_BASE}"
	envsubst <"$SOURCE_FILE" >"$TARGET_FILE"
done < <(find "${TEMPLATE_DIR}" -name '*.in' -print0)

echo "Ensuring generated files are correctly formatted..."
COMMAND_OUTPUT=$(cd "${OUTPUT_DIR}" && terraform fmt -recursive 2>&1)

cat <<-END_OF_DOC
	${TEXT_COLOR_MAGENTA}
	$(echo "The generated Terraform code files are now located inside '${OUTPUT_DIR}'. Please review them now!" | fold -s -w 80)

	${TEXT_BOLD}Please check the generated code carefully, expecially if you bootstrap an
	already used project. It may need adjustments to reflect your already existing
	configuration.${TEXT_ALL_OFF}

	Once you reviewed the generated Infrastructure as Code configuration, the
	script can automatically import the resources that were generated during the
	bootstrapping into the Terraform state. This includes the following resouces:
	  * The service account that was created to roll out Terraform code changes
	  * The Google Cloud Storage bucket that was created to store your remote state

	You can also cancel the import if you use a non-standard bootstrap process.
	However, ${TEXT_BOLD}depending on your project setup this can lead to errors when trying to
	apply the Terraform code. Thus, using the automatic import is recommended,
	especially if you are working with a brand new project.${TEXT_ALL_OFF}

END_OF_DOC
read -p "Proceed with import (y/n)? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	cat <<-END_OF_DOC

		${TEXT_BOLD}Caution:${TEXT_ALL_OFF} You may need to import the resources manually into your state:
		${TEXT_COLOR_MAGENTA}
		terraform import \\
		  'module.project-cfg.google_service_account.service_accounts["${SA_NAME}"]' \\
		  'projects/${GCP_PROJECT_ID}/serviceAccounts/${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com'
		terraform import \\
		  'module.tf-state-bucket.google_storage_bucket.bucket' \\
		  '${GCP_PROJECT_ID}/${GCS_BUCKET}'${TEXT_ALL_OFF}

		After the import, you can run 'terraform plan' and 'terraform apply' as usual.
	END_OF_DOC
	reset_command_output_trap
	exit
else
	OLD_PWD="${PWD}"
	cd "${OUTPUT_DIR}"

	echo "Initializing output directory..."
	COMMAND_OUTPUT=$(terraform init -upgrade 2>&1)

	echo "Ensuring token for impersonation is ready..."
	COMMAND_OUTPUT=$(terraform apply -target data.google_service_account_access_token.iac_sa_token 2>&1)

	# reset command output buffer to avoid confusing error if state check fails...
	clear_command_output_buffer
	if terraform state list | grep -F -q "module.project-cfg.google_service_account.service_accounts[\"${SA_NAME}\"]"; then
		echo "${TEXT_COLOR_YELLOW}Service account already exists in state. Skipping import.${TEXT_ALL_OFF}" | fold -s -w 80
	else
		echo "Importing service account into state..."
		COMMAND_OUTPUT=$(terraform import "module.project-cfg.google_service_account.service_accounts[\"${SA_NAME}\"]" "projects/${GCP_PROJECT_ID}/serviceAccounts/${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" 2>&1)
	fi

	# reset command output buffer to avoid confusing error if state check fails...
	clear_command_output_buffer
	if terraform state list | grep -F -q 'module.tf-state-bucket.google_storage_bucket.bucket'; then
		echo "${TEXT_COLOR_YELLOW}GCS bucket already exists in state. Skipping import.${TEXT_ALL_OFF}"
	else
		echo "Importing GCS bucket into state..."
		COMMAND_OUTPUT=$(terraform import 'module.tf-state-bucket.google_storage_bucket.bucket' "${GCP_PROJECT_ID}/${GCS_BUCKET}" 2>&1)
	fi

	# we send command output to user again, no need to use the trap any longer
	reset_command_output_trap

	# Build roles only plan
	echo "Building a plan to roll out all IAM changes..."
	(rm -f bootstrap.tfplan && terraform plan -target module.project-cfg.google_project_iam_binding.roles -out bootstrap.tfplan >/dev/null 2>&1)
	TF_PLAN=$(terraform show bootstrap.tfplan)
	cat <<-END_OF_DOC

		The script has done all the initial bootstrapping to execute Terraform for the
		first time! To avoid and problems based on missing permissions, we will roll out
		the needed IAM permissions only:

		---
		${TF_PLAN}
		---

		${TEXT_BOLD}${TEXT_COLOR_MAGENTA}Please check the above plan carefully, expecially if you are bootstrapping a
		project that was already used previously (e.g. it already contains IAM policy
		bindings). The Terraform code may remove IAM permissions.

		If you are using afresh (newly created project) it is most likely safe to accept
		the changes.${TEXT_ALL_OFF}

	END_OF_DOC
	read -p "Execute 'terraform apply' for plan above (y/n)? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Exiting bootstrap without executing 'terraform apply' for the first time. Your project is now bootstrapped but may still miss resources that are defined in the generated Terraform code. Execute 'terraform apply' from within ${OUTPUT_DIR} to roll the missing resources." | fold -s -w 80
		rm "bootstrap.tfplan"
	else
		echo "Applying the Terraform changes..."
		terraform apply -auto-approve bootstrap.tfplan
		rm "bootstrap.tfplan"
	fi

	echo "Building an initial full rollout plan..."
	(rm -f bootstrap.tfplan && terraform plan -out bootstrap.tfplan >/dev/null 2>&1)
	TF_PLAN=$(terraform show bootstrap.tfplan)
	cat <<-END_OF_DOC

		The script has done all needed steps to execute Terraform for the first time
		managing your complete project resources! Depending on your configuration,
		the module will create several additional resources (e.g. IAM bindings)
		during the first run:

		---
		${TF_PLAN}
		---

		${TEXT_BOLD}${TEXT_COLOR_MAGENTA}Please check the above plan carefully, expecially if you are bootstrapping a
		project that was already used previously (e.g. it already contains IAM policy
		bindings). The Terraform code may removes IAM permissions.

		If you are using afresh (newly created project) it is most likely safe to accept
		the changes.${TEXT_ALL_OFF}

	END_OF_DOC

	read -p "Execute 'terraform apply' for plan above (y/n)? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Exiting bootstrap without executing 'terraform apply' with full apply. Your project is now bootstrapped but may still miss resources that are defined in the generated Terraform code. Execute 'terraform apply' from within ${OUTPUT_DIR} to roll the missing resources." | fold -s -w 80
		rm "bootstrap.tfplan"
	else
		echo "Applying the Terraform changes..."
		terraform apply -auto-approve bootstrap.tfplan
		rm "bootstrap.tfplan"
	fi
	cd "${OLD_PWD}"
	echo
	echo "Your project bootstrapping is completed! Copy the contents of ${OUTPUT_DIR} into a Git repository (if it isn't already part of one) and commit them. See https://confluence.metrosystems.net/x/XJKtG for more information about Infrastructure as Code (e.g. how to automate its rollout using GitHub Workflows)." | fold -s -w 80
fi
