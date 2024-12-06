#!/usr/bin/env bash

# Copyright 2023 METRO Digital GmbH
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
		  -o (optional) relative or absolute path to directory that will store the
		                generated Terraform code (default: 'iac-output').
		  -g (optional) GitHub repository in the format '<owner/org>/<reponame>'. If
		                given, the Terraform code will be configured to enable the Workload
		                Identity Federation support for GitHub Workflows. This is
		                required for keyless authentication from GitHub Workflows which
		                is strongly recommended. This can also be set up later.
		  -t (optional) Time to sleep for in between bootstrap stages exectution,
		      required for GCP IAM changes to propagate (default: '5m').
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

function gsutil_err_handling() {
	cat <<-END_OF_ERROR
		${TEXT_COLOR_RED}Caught unexpected output!${TEXT_ALL_OFF}
		Please review the command output and fix the root cause:
		==============================================
		${1}"
		==============================================

	END_OF_ERROR
	echo "You can hold this script on pause and fix the root cause in a separate terminal session"
	echo "Or you can stop it here and rerun the script after the root cause is fixed."
	read -p "Proceed (y/n)? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		log_error "Aborted."
		exit 1
	fi
}

# Parameter parsing
while getopts ":p:s:b:o:g::t:h" OPT; do
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
	t)
		TIME_SLEEP_PARAM="${OPTARG}"
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
check_program dig

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
	GITHUB_REPOSITORY_IAM_ROLE_STRING="\"roles/iam.workloadIdentityPoolAdmin\","
else
	GITHUB_REPOSITORY_SA_BLOCK_STRING=""
	GITHUB_REPOSITORY_IAM_ROLE_STRING=""
fi

TIME_SLEEP="${TIME_SLEEP_PARAM:-5m}"

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
	GCP_PROJECT_NAME="$(gcloud projects describe "${GCP_PROJECT_ID}" --format='value(name)')"
	if [ "${GCP_PROJECT_NAME}" = "" ]; then
		log_error "Unable to find a project with the given project ID '${GCP_PROJECT_ID}'!"
		log_error "Your active gcloud CLI account is '${ACTIVE_GCLOUD_ACCOUNT}'. Is the manager role (or a role with comparable permissions) assigned to this account inside the project?"
		exit 1
	fi
fi

#Getting project number
GCP_PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT_ID}" --format='value(project_number)')"
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
IAM_OBSERVER_GROUP="${IAM_MANAGER_GROUP/-manager@/-observer@}"

# Variables used for output and inside terraform templates
MANAGER_GROUP="${IAM_MANAGER_GROUP#group:}"
DEVELOPER_GROUP="${IAM_DEVELOPER_GROUP#group:}"
OBSERVER_GROUP="${IAM_OBSERVER_GROUP#group:}"

OUTPUT_HINT=$(echo "The generated Terraform code will be written to '${OUTPUT_DIR}'." | fold -s -w 80)

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

# Ensure Terraform adjusts its output to avoid suggesting specific commands to run next.
export TF_IN_AUTOMATION=yes
# Set the DATA_DIR to a project specific one to avoid any issue if the directory is not cleaned
# between bootstrapping different projects
export TF_DATA_DIR=".terraform-${GCP_PROJECT_ID}"
# also use the project ID as workspace for the same reason
export TF_WORKSPACE="${GCP_PROJECT_ID}"

echo "Starting first stage terraform init." | fold -s -w 80

terraform -chdir=terraform init

echo "Starting first stage terraform apply." | fold -s -w 80

terraform -chdir=terraform apply -auto-approve \
	-var="project=${GCP_PROJECT_ID}" \
	-var="manager_group=${MANAGER_GROUP}" \
	-var="developer_group=${DEVELOPER_GROUP}" \
	-var="observer_group=${OBSERVER_GROUP}" \
	-var="terraform_sa_name=${SA_NAME}" \
	-var="terraform_state_bucket=${GCS_BUCKET}" \
	-var="github_repository_iam_role_string=${GITHUB_REPOSITORY_IAM_ROLE_STRING}" \
	-var="github_repository_sa_block_string=${GITHUB_REPOSITORY_SA_BLOCK_STRING}" \
	-var="time_sleep=${TIME_SLEEP}" \
	-var="output_dir=${OUTPUT_DIR}"

echo "Finished first stage terraform apply." | fold -s -w 80

# Unset TF_DATA_DIR to fall back to normal .terraform folder
unset TF_DATA_DIR
# also unset the workspace as we now operate on the bootstrap code that doesnt know about workspaces
unset TF_WORKSPACE

echo "Starting second stage terraform init with state migration using generated code." | fold -s -w 80

terraform -chdir="${OUTPUT_DIR}" init -migrate-state

echo "Finished second stage terraform init with state migration using generated code." | fold -s -w 80

echo "Starting second stage terraform apply using generated code." | fold -s -w 80

terraform -chdir="${OUTPUT_DIR}" apply -auto-approve

echo "Finished second stage terraform apply using generated code." | fold -s -w 80

echo "Your project bootstrapping is completed! Copy the contents of ${OUTPUT_DIR} into a Git repository (if it isn't already part of one) and commit them. See https://confluence.metrosystems.net/x/XJKtG for more information about Infrastructure as Code (e.g. how to automate its rollout using GitHub Workflows)." | fold -s -w 80

echo "On consecutive executions you will see roles being added and then removed to the manager group between the first and second stages. THIS IS NORMAL. DON'T PANIC." | fold -s -w 80
