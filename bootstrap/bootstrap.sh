#!/usr/bin/env bash

# Copyright 2025 METRO Digital GmbH
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
TEXT_COLOR_GREEN="$(tput setaf 2)"
TEXT_COLOR_MAGENTA="$(tput setaf 5)"
TEXT_ALL_OFF="$(tput sgr0)"

function log_error() {
	echo "${TEXT_BOLD}${TEXT_COLOR_RED}ERROR:${TEXT_ALL_OFF} ${1}${TEXT_ALL_OFF}"
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
		  $0 -p [GCP_PROJECT_ID] [ADDITIONAL OPTIONS]

		Options:
		  -p <string> (required) GCP Project ID
		  -s <string> (optional) Name of the service account that will be used to execute
		                         Terraform changes (default: terraform-iac-pipeline).
		  -b <string> (optional) Bucket name without 'gs://' which will store the Terraform
		                         state files (default: 'tf-state-<GCP_PROJECT_ID>').
		  -o <string> (optional) relative or absolute path to directory that will store the
		                         generated Terraform code (default: 'iac-output').
		  -g <string> (optional) GitHub repository in the format '<owner/org>/<reponame>'. If
		                         given, the Terraform code will be configured to enable the Workload
		                         Identity Federation support for GitHub Workflows. This is
		                         required for keyless authentication from GitHub Workflows which
		                         is strongly recommended. This can also be set up later.
		  -t <string> (optional) Time to sleep for in between bootstrap stages execution,
		                         required for GCP IAM changes to propagate (default: '5m').
		  -i          (optional) Stop after initial creation of Service Account, bucket and permissions.
		                         Bootstrap will still create write to output directory, but will
		                         not apply any generated code.
	END_OF_DOC
	exit
}

# Parameter parsing
while getopts ":p:s:b:l:o:g::t:hi" OPT; do
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
	l)
		GCS_BUCKET_LOCATION_PARAM="${OPTARG}"
		;;
	o)
		OUTPUT_DIR_PARAM="${OPTARG}"
		;;
	g)
		GITHUB_REPOSITORY_PARAM="${OPTARG}"
		;;
	t)
		TIME_SLEEP_PARAM="${OPTARG}"
		;;
	i)
		INIT_ONLY_PARAM="yes"
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
check_program jq
check_program terraform

# parameter validation / defaulting
SA_NAME="${SA_NAME_PARAM:-terraform-iac-pipeline}"
OUTPUT_DIR="${OUTPUT_DIR_PARAM:-iac-output}"

if [ "${GCS_BUCKET_PARAM:-notset}" = "notset" ]; then
	GCS_BUCKET="tf-state-${GCP_PROJECT_ID:-notset}"
else
	GCS_BUCKET="${GCS_BUCKET_PARAM}"
fi

if [ "${GITHUB_REPOSITORY_PARAM:-notset}" != "notset" ]; then
	# Trim trailing .git from repositories
	GITHUB_REPOSITORY="${GITHUB_REPOSITORY_PARAM%.git}"
else
	GITHUB_REPOSITORY=""
fi

TIME_SLEEP="${TIME_SLEEP_PARAM:-5m}"
INIT_ONLY="${INIT_ONLY_PARAM:-no}"

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
	PROJECT_DATA=$(gcloud projects describe "${GCP_PROJECT_ID}" --format 'json' || true)
	if [ "${PROJECT_DATA}" = "" ]; then
		log_error "Unable to find a project with the given project ID '${GCP_PROJECT_ID}'!"
		log_error "Please check:"
		log_error " - Is the project ID correct?"
		log_error " - Your active gcloud CLI account is '${ACTIVE_GCLOUD_ACCOUNT}'. Is the manager role assigned to this account inside the project?"
		exit 1
	fi

	VARIABLES_EXTRACTED=$(echo "${PROJECT_DATA}" | jq -r '@sh "GCP_PROJECT_NAME=\(.name) GCP_PROJECT_NUMBER=\(.projectNumber) GCP_PROJECT_LIFECYCLE=\(.lifecycleState) GCP_PROJECT_LANDING_ZONE=\(.labels.cf_landing_zone)"')
	eval "${VARIABLES_EXTRACTED}"

	if [ "${GCP_PROJECT_LIFECYCLE}" != "ACTIVE" ]; then
		log_error "Invalid '${GCP_PROJECT_ID}'! Given project is in lifecycle state '${GCP_PROJECT_LIFECYCLE}' - expected 'ACTIVE'"
		exit 1
	fi

	if [ "${GCP_PROJECT_LANDING_ZONE}" = "null" ]; then
		log_error "Invalid '${GCP_PROJECT_ID}'! Label 'cf_landing_zone' - does not exists. Is this a Cloud Foundation project?"
		exit 1
	fi

	if [ "${GCS_BUCKET_LOCATION_PARAM:-notset}" = "notset" ]; then
		case $GCP_PROJECT_LANDING_ZONE in
		"applications_non-prod_eu" | "applications_prod_eu")
			GCS_BUCKET_LOCATION="EU"
			;;
		"applications_non-prod_asia" | "applications_prod_asia")
			GCS_BUCKET_LOCATION="ASIA"
			;;
		*)
			log_error "Landing zone '${GCP_PROJECT_LANDING_ZONE}' is unknown. Please reach out to the Cloud Foundation team to report this error."
			exit 1
			;;
		esac
	else
		GCS_BUCKET_LOCATION="${GCS_BUCKET_LOCATION_PARAM}"
	fi
fi

# try to find Cloud Foundation Panel groups in IAM permissions
IAM_MANAGER_GROUP=$(gcloud --quiet projects get-iam-policy "${GCP_PROJECT_ID}" --format json | jq -r '.bindings[] | select(.role == "organizations/1049006825317/roles/CF_Project_Manager") | .members[] | select ( . | test("^group:.*-manager@(metrosystems\\.net|cloudfoundation\\.metro\\.digital)$"))')
if [ "${IAM_MANAGER_GROUP:-notset}" = "notset" ]; then
	log_error "Unable to find the manager group for the project ID '${GCP_PROJECT_NAME}'! Are you trying to bootstrap a Cloud Foundation project? Ensure that the 'CF Project Manager' role is assigned to the manager group inside the project."
	exit 1
fi
IAM_DEVELOPER_GROUP="${IAM_MANAGER_GROUP/-manager@/-developer@}"
IAM_OBSERVER_GROUP="${IAM_MANAGER_GROUP/-manager@/-observer@}"

# Variables used for output and inside terraform templates
MANAGER_GROUP="${IAM_MANAGER_GROUP#group:}"
DEVELOPER_GROUP="${IAM_DEVELOPER_GROUP#group:}"
OBSERVER_GROUP="${IAM_OBSERVER_GROUP#group:}"

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
	${TEXT_BOLD}Detected observer group:${TEXT_ALL_OFF} ${OBSERVER_GROUP}
	${TEXT_BOLD}Detected landing zone:${TEXT_ALL_OFF} ${GCP_PROJECT_LANDING_ZONE}

	The following resources will be created (if they don't already exist):
	  * ${TEXT_BOLD}Service Account:${TEXT_ALL_OFF}
	      ${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
	  * ${TEXT_BOLD}GCS Bucket:${TEXT_ALL_OFF}
	      gs://$GCS_BUCKET - Location: '${GCS_BUCKET_LOCATION}'

	The generated Terraform code will be written to '${OUTPUT_DIR}'.
	${TEXT_BOLD}${TEXT_COLOR_MAGENTA}
	The active account needs the project manager role inside the Cloud Foundation
	Panel (or similar permissions). We assume that the permissions are granted to
	your active account, most likely by beeing member of the group
	'${MANAGER_GROUP}'.${TEXT_ALL_OFF}
	${TEXT_BOLD}
	Please also check the guide for this script if you are unsure about how to use
	it: https://metrodigital.atlassian.net/wiki/x/5gHMBw
	${TEXT_ALL_OFF}
EOF

if [ "${INIT_ONLY}" = "yes" ]; then
	cat <<-EOF
		${TEXT_BOLD}${TEXT_COLOR_MAGENTA}Bootstrap will run in 'init-only mode', means it create the Service Account
		and Bucket, generate the terraform code to output directory and then terminate
		without applying the generated code.
		${TEXT_ALL_OFF}
	EOF
fi

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
		log_error "Error occurred during Application Default Credentials setup ... can't proceed"
		exit 1
	fi
	echo
fi

if [[ ! -d "${OUTPUT_DIR}" ]]; then
	read -p "Output directory '${OUTPUT_DIR}' does not exist. Create it (y/n)? " -n 1 -r
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
		cat <<-EOF
			${TEXT_BOLD}Warning: Output directory '${OUTPUT_DIR}' is not empty!${TEXT_ALL_OFF}
			This can cause issues if it contains terraform configuration or cache.
			${TEXT_BOLD}${TEXT_COLOR_RED}   ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
			The bootstrap script will recursively delete the existing directory.
			${TEXT_ALL_OFF}
		EOF
		read -p "Continue (y/n)? " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			log_error "Aborted."
			exit 1
		fi
		if ! rm -R -f "${OUTPUT_DIR}"; then
			log_error "Could not delete existing output directory... can't proceed"
			exit 1
		fi
		if ! mkdir -p "${OUTPUT_DIR}"; then
			log_error "Could not create output directory... can't proceed"
			exit 1
		fi
	fi
fi

# Ensure Terraform adjusts its output to avoid suggesting specific commands to run next.
export TF_IN_AUTOMATION=yes
# Set the DATA_DIR to a project specific one to avoid any issue if the directory is not cleaned
# between bootstrapping different projects
export TF_DATA_DIR=".terraform-${GCP_PROJECT_ID}"
# also use the project ID as workspace for the same reason
export TF_WORKSPACE="${GCP_PROJECT_ID}"

cat <<-EOF >"terraform/generated-${GCP_PROJECT_ID}.tfvars"
	project="${GCP_PROJECT_ID}"
	manager_group="${MANAGER_GROUP}"
	developer_group="${DEVELOPER_GROUP}"
	observer_group="${OBSERVER_GROUP}"
	terraform_sa_name="${SA_NAME}"
	terraform_state_bucket="${GCS_BUCKET}"
	terraform_state_bucket_location="${GCS_BUCKET_LOCATION}"
	github_repository="${GITHUB_REPOSITORY}"
	time_sleep="${TIME_SLEEP}"
	output_dir="${OUTPUT_DIR}"
EOF

echo "Removing .terraform.lock.hcl file if it exists"
rm -f terraform/.terraform.lock.hcl

echo "Starting first stage terraform init."
terraform -chdir=terraform init

echo "Running import commands for Service Account and Bucket."
terraform -chdir=terraform import \
	-var-file="generated-${GCP_PROJECT_ID}.tfvars" \
	google_storage_bucket.this \
	"${GCP_PROJECT_ID}/${GCS_BUCKET}" ||
	echo "${TEXT_BOLD}${TEXT_COLOR_GREEN}Import failed, expected!${TEXT_ALL_OFF}"

terraform -chdir=terraform import \
	-var-file="generated-${GCP_PROJECT_ID}.tfvars" \
	google_service_account.this \
	"projects/${GCP_PROJECT_ID}/serviceAccounts/${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" ||
	echo "${TEXT_BOLD}${TEXT_COLOR_GREEN}Import failed, expected!${TEXT_ALL_OFF}"

echo "Starting first stage terraform apply."
terraform -chdir=terraform apply -auto-approve \
	-var-file="generated-${GCP_PROJECT_ID}.tfvars"

echo "Finished first stage terraform apply."

# Unset TF_DATA_DIR to fall back to normal .terraform folder
unset TF_DATA_DIR
# also unset the workspace as we now operate on the bootstrap code that doesnt know about workspaces
unset TF_WORKSPACE

terraform -chdir="${OUTPUT_DIR}" fmt

if [ "${INIT_ONLY}" = "yes" ]; then
	cat <<-EOF
		${TEXT_BOLD}${TEXT_COLOR_RED}
		Bootstrap in 'init-only mode', not applying the generated terraform code!${TEXT_ALL_OFF}

		The script would have executed the following command to ensure the state
		moved to the generated Google Cloud Storage bucket:

		terraform -chdir="${OUTPUT_DIR}" init -migrate-state

		And then apply the generated code:

		terraform -chdir="${OUTPUT_DIR}" apply
	EOF
	exit 0
fi

echo "Starting second stage terraform init with state migration using generated code."

terraform -chdir="${OUTPUT_DIR}" init -migrate-state

echo "Finished second stage terraform init with state migration using generated code."

echo "Starting second stage terraform apply using generated code."

terraform -chdir="${OUTPUT_DIR}" apply

cat <<-EOF
	${TEXT_BOLD}${TEXT_COLOR_GREEN}
	Finished second stage terraform apply using generated code.
	${TEXT_ALL_OFF}
	Your project bootstrapping is completed! Copy the contents of ${OUTPUT_DIR}
	into a Git repository (if it isn't already part of one) and commit them.

	See https://metrodigital.atlassian.net/wiki/x/SwLMBw for more information
	about Infrastructure as Code (e.g. how to automate its rollout
	using GitHub Workflows).
EOF
