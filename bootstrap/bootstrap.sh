#!/usr/bin/env bash
# Copyright 2021 METRO Digital GmbH
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

function log_error()
{
    echo "${TEXT_BOLD}${TEXT_COLOR_RED}ERROR:${TEXT_ALL_OFF}${TEXT_COLOR_RED} ${1}${TEXT_ALL_OFF}" 2>&1
}

function check_program()
{
    PRG=$(which $1 2>/dev/null || true)
    if [ -z "${PRG}" ]
	then
        log_error "Program \"$1\" not found"
        exit 1
    fi
}

function print_usage_and_exit()
{
    cat <<-END_OF_DOC
		Cloud Foundation Project config bootstrapper
		--
		Call: $0 -m <MODE> -p <GCP_PROJECT_ID> [-s <SA_NAME>] [-b <GCS_BUCKET_NAME>] [-o <DIR_PATH>]
		  -m 	MODE can be terraform or terragrunt
		  -p	GCP Project ID
		  -s	The Service Account name (default: terraform-iac-pipeline)
		  -b    The bucket name without gs:// (default: tf-state-<GCP_PROJECT_ID>) to store terraform state files
		  -o	(relativ|absolut) path to directory to store genereated terraform/terragrunt code (Default: iac-output)
	END_OF_DOC
	exit
}

function reset_gcloud_auth()
{
    EXITCODE=$?
	gcloud --quiet config set account "${ACTIVE_GCLOUD_ACCOUNT}" >/dev/null 2>&1
	gcloud --quiet auth revoke "${SA_FULL_NAME}" >/dev/null 2>&1
    exit $EXITCODE
}

# Parameter parsing
while getopts ":m:p:s:b:o:h" OPT
do
	case $OPT in
		m )
			MODE="$OPTARG"
		;;
		p )
			GCP_PROJECT_ID="$OPTARG"
		;;
		s )
		   SA_NAME_PARAM="${OPTARG}"
		;;
		b )
		   GCS_BUCKET_PARAM="$OPTARG"
		;;
		o )
		   OUTPUT_DIR_PARAM="$OPTARG"
		;;
		: )
			log_error "Option -$OPTARG requires an argument"
			exit 1
		;;
		\? )
      		log_error "Invalid Option: -$OPTARG"
      		exit 1
      	;;
		h )
			print_usage_and_exit
		;;
	esac
done

check_program gcloud
check_program gsutil
check_program jq
check_program find
check_program realpath

# parameter validation / defaulting
SA_NAME="${SA_NAME_PARAM:-terraform-iac-pipeline}"
OUTPUT_DIR="${OUTPUT_DIR_PARAM:-iac-output}"

if [[ ! -d "${OUTPUT_DIR}" ]]
then
	read -p "Directory '${OUTPUT_DIR}' does not exist - create (y/n)?" -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		echo "Creating '${OUTPUT_DIR}'"
		mkdir -p "${OUTPUT_DIR}"
	else
		log_error "Aborted."
		exit 1
	fi
else
	if [ "$(ls -A ${OUTPUT_DIR})" ]
	then
		read -p "Directory '${OUTPUT_DIR}' is not empty - continue (y/n)?" -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]
		then
			log_error "Aborted."
			exit 1
		fi
	fi
fi

if [ "${GCS_BUCKET_PARAM:-notset}" = "notset" ]
then
	GCS_BUCKET="tf-state-${GCP_PROJECT_ID:-notset}"
else
	GCS_BUCKET="${GCS_BUCKET_PARAM}"
fi

if [ "${MODE:-notset}" = "notset" ]
then
	log_error "Missing MODE - Set -m parameter!"
	exit 1
else
	if [ "$MODE" = "terraform" ]
	then
		check_program terraform
	elif [ "$MODE" = "terragrunt" ]
	then
		check_program terraform
		check_program terragrunt
	else
		log_error "You need to set the mode to 'terraform' or 'terragrunt'"
    	exit 1
	fi
fi

echo "Determinating project details..."
# determinate active gcloud account
ACTIVE_GCLOUD_ACCOUNT="$(gcloud --quiet auth list --format json | jq -r '.[] | select(.status == "ACTIVE") | .account')"
if [ "${ACTIVE_GCLOUD_ACCOUNT:-notset}" = "notset" ]
then
	log_error "Unable to detect active gcloud account! Please configure your gcloud CLI."
	exit 1
fi

# check given gcp project
if [ "${GCP_PROJECT_ID:-notset}" = "notset" ]
then
	log_error "Missing GCP_PROJECT_ID - Set -p parameter!" 1>&2
	exit 1
else
	GCP_PROJECT_NAME="$(gcloud projects list --format='value(name)' --filter=\"$GCP_PROJECT_ID\")"
	if [ "${GCP_PROJECT_NAME}" = "" ]
	then
		log_error "Unable to find project with given project ID '${GCP_PROJECT_NAME}'!"
		log_error "Your active gcloud CLI account is '${ACTIVE_GCLOUD_ACCOUNT}' - does this account have the manager role on the project?"
		exit 1
	fi
fi

# try to find cloud foundation panel groups in IAM permissions
IAM_MANAGER_GROUP=$(gcloud --quiet projects get-iam-policy $GCP_PROJECT_ID --format json | jq -r '.bindings[] | select(.role == "organizations/1049006825317/roles/CF_Project_Manager") | .members[] | select ( . | test("^group:.*-manager@(metrosystems\\.net|cloudfoundation\\.metro\\.digital)$"))')
if [ "${IAM_MANAGER_GROUP:-notset}" = "notset" ]
then
	log_error "Unable to detect IAM group for project! Ensure the manager group created by Cloud Foundation Panel has the CF Project Manager role assigned."
	exit 1
fi
IAM_DEVELOPER_GROUP="${IAM_MANAGER_GROUP/-manager@/-developer@}"

# all set - print details to user and ask to continue
cat <<-EOF

	+-------------------------------------------------------------------------------------------------------+
	| Project configuration bootstrap                                                                       |
	+-------------------------------------------------------------------------------------------------------+

	This script will bootstrap the project '${GCP_PROJECT_NAME}' (ID: ${GCP_PROJECT_ID}) for $MODE

	Currently active gcloud account: ${ACTIVE_GCLOUD_ACCOUNT}
	Detected Manager group: ${IAM_MANAGER_GROUP#group:}
	Detected Developer group: ${IAM_DEVELOPER_GROUP#group:}

	The following ressources will be created (if not existing):
	    Service Account: ${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
	    GCS Bucket: gs://$GCS_BUCKET

	IaC output will be written to '${OUTPUT_DIR}'
	${TEXT_BOLD}${TEXT_COLOR_MAGENTA}
	The active account needs the Project Manager role via Cloud Foundation Panel (or simiar permissions)
	We assume the permissions are granted to this account via group '${IAM_MANAGER_GROUP#group:}'
	${TEXT_ALL_OFF}${TEXT_BOLD}
	Please also check the HowTo if unsure how to use this script: https://confluence.metrosystems.net/x/rZOtG
	${TEXT_ALL_OFF}
EOF

read -p "Please review configuration - proceed (y/n)?" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	log_error "Aborted."
	exit 1
fi

echo "Granting needed permissions to group '${IAM_MANAGER_GROUP}'"
for role in roles/iam.serviceAccountKeyAdmin roles/iam.serviceAccountAdmin roles/serviceusage.serviceUsageAdmin
do
	echo "* granting $role to ${IAM_MANAGER_GROUP}"
	gcloud --quiet projects add-iam-policy-binding $GCP_PROJECT_ID \
		--member="${IAM_MANAGER_GROUP}" \
		--role="$role" >/dev/null
done

echo "Enabling needed APIs..."
gcloud --quiet services enable iam.googleapis.com --project $GCP_PROJECT_ID
gcloud --quiet services enable cloudresourcemanager.googleapis.com --project $GCP_PROJECT_ID
gcloud --quiet services enable serviceusage.googleapis.com --project $GCP_PROJECT_ID

# pipeline service account
SERVICE_ACCOUNT_CHECK=$(gcloud iam service-accounts list --project $GCP_PROJECT_ID --filter "email=${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --format "value(disabled)")
if [ "${SERVICE_ACCOUNT_CHECK:-notset}" = "notset" ] # account does not exist
then
	echo "Creating service account ${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
	gcloud iam service-accounts create ${SA_NAME} \
		--display-name "Service account used in IaC pipelines" \
		--project $GCP_PROJECT_ID
elif [ "${SERVICE_ACCOUNT_CHECK}" = "True" ]
then
	log_error "Service account exists but seems to be disbaled. Aborted."
	exit 1
elif [ "${SERVICE_ACCOUNT_CHECK}" = "False" ]
then
	echo "Service account already exists, skipping create"
else # whatever may happen else...
	log_error "Unknown error checking for service account"
	exit 1
fi

SA_FULL_NAME="${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

echo "Granting required permissions to service account"
for role in roles/compute.networkAdmin roles/compute.securityAdmin roles/storage.admin roles/storage.objectAdmin roles/iam.serviceAccountKeyAdmin roles/iam.serviceAccountAdmin roles/iam.securityAdmin roles/iam.roleAdmin roles/serviceusage.serviceUsageAdmin
do
	echo "* granting $role to serviceAccount:${SA_FULL_NAME}"
	gcloud --quiet projects add-iam-policy-binding $GCP_PROJECT_ID \
		--member="serviceAccount:${SA_FULL_NAME}" \
		--role="$role" >/dev/null
done

# service account keyfile
if [[ -f "${OUTPUT_DIR}/account.json" ]]
then
	read -p "${OUTPUT_DIR}/account.json exist, overwrite (download new key) (y/n)?" -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		echo "Downloading new service account key (overwrite existing one)"
		rm ${OUTPUT_DIR}/account.json
		gcloud --quiet iam service-accounts keys create "${OUTPUT_DIR}/account.json" \
			--iam-account ${SA_FULL_NAME} --project $GCP_PROJECT_ID
	fi
else
	echo "Downloading new service account key"
	gcloud --quiet iam service-accounts keys create "${OUTPUT_DIR}/account.json" \
		--iam-account ${SA_FULL_NAME} --project $GCP_PROJECT_ID
fi

# switch gcloud to service account
echo "Using ${SA_FULL_NAME} for further bootstrapping"
gcloud auth activate-service-account --key-file "${OUTPUT_DIR}/account.json"
trap reset_gcloud_auth INT TERM EXIT # ensure we switch back gcloud account in any case

if gsutil -q ls "gs://${GCS_BUCKET}" >/dev/null 2>&1
then
	echo "GCS bucket ${GCS_BUCKET} already exists, skipping creation."
else
	echo "Creating GCS bucket for terraform state"
	gsutil mb -c nearline -b on -l EU -p $GCP_PROJECT_ID "gs://${GCS_BUCKET}"
fi

# Create IaC code from template
TEMPLATE_BASEDIR=$(dirname "${BASH_SOURCE[0]}")
TEMPLATE_DIR="${TEMPLATE_BASEDIR}/templates/${MODE}"

# export variables to make them accessable for envsubst
export GCP_PROJECT_ID
export GCS_BUCKET
export SA_FULL_NAME
export SA_SHORT_NAME="${SA_NAME}"
export IAM_MANAGER_GROUP
export IAM_DEVELOPER_GROUP

echo "Generating files for your repository..."
for SOURCE_FILE in $(find "${TEMPLATE_DIR}" -name '*.in' -print)
do
	TARGET_FILE=$(basename $SOURCE_FILE .in)
	TARGET_DIR="${OUTPUT_DIR}/$(dirname $(realpath -L $SOURCE_FILE --relative-to ${TEMPLATE_DIR}))"
	TARGET_PATH="${TARGET_DIR}/${TARGET_FILE}"

	mkdir -p "${TARGET_DIR}"
	envsubst <$SOURCE_FILE >$TARGET_PATH
done

echo "Rewrite generated files in canonical format..."
if [ "$MODE" = "terraform" ]
then
	( cd $TARGET_DIR && terraform fmt -recursive )
else
	( cd $TARGET_DIR && terragrunt hclfmt )
fi

FULL_SA_ACCOUNT_FILE="$(realpath ${OUTPUT_DIR}/account.json)"
echo "${TEXT_COLOR_MAGENTA}Generated IaC code files in '${OUTPUT_DIR}' - please check them out!${TEXT_ALL_OFF}"
echo "${TEXT_COLOR_MAGENTA}You should set your GOOGLE_APPLICATION_CREDENTIALS for the next commands:${TEXT_ALL_OFF}"
echo "export GOOGLE_APPLICATION_CREDENTIALS=\"${FULL_SA_ACCOUNT_FILE}\""

if [ "$MODE" = "terraform" ]
then
	echo "${TEXT_COLOR_MAGENTA}You need to import the created service account into your state:${TEXT_ALL_OFF}"
	echo "terraform init && terraform import 'module.project-cfg.google_service_account.service_accounts[\"${SA_NAME}\"]' projects/${GCP_PROJECT_ID}/serviceAccounts/${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

	echo "${TEXT_COLOR_MAGENTA}You need to import the created GCS bucket into your state:${TEXT_ALL_OFF}"
	echo "terraform import 'module.tf-state-bucket.google_storage_bucket.bucket' ${GCP_PROJECT_ID}/${GCS_BUCKET}"
else

	echo "${TEXT_COLOR_MAGENTA}You need to import the created service account into your state (inside '${OUTPUT_DIR}/project-cfg' folder):${TEXT_ALL_OFF}"
	echo "terragrunt import 'google_service_account.service_accounts[\"${SA_NAME}\"]' projects/${GCP_PROJECT_ID}/serviceAccounts/${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
	echo "${TEXT_BOLD}Remark: It is important to run 'terragrunt apply' here as you need the output in the next import!${TEXT_ALL_OFF}"
	echo "terragrunt apply"

	echo "${TEXT_COLOR_MAGENTA}You need to import the created GCS bucket into your state (inside '${OUTPUT_DIR}/buckets/terraform-state' folder):${TEXT_ALL_OFF}"
	echo "terragrunt import 'google_storage_bucket.bucket' ${GCP_PROJECT_ID}/${GCS_BUCKET}"
fi
