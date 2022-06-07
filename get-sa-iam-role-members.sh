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

# do not allow unset variables
set -u
# exit script on any error
set -e

function check_program() {
  set +e # next command my fail - allow failure
  PRG="$(command -v "$1" 2>/dev/null)"
  set -e # exit script on any error again
  if [ -z "$PRG" ]; then
    echo "ERROR - \"$1\" not found" >&2
    exit 1
  fi
}

check_program jq
check_program curl

eval "$(jq -r '@sh "PROJECT_ID=\(.project_id) SA_UNIQUE_ID=\(.sa_unique_id) ACCESS_TOKEN=\(.access_token) ROLE=\(.role)"')"

IAM_POLICY=$(curl -H "Authorization: Bearer $ACCESS_TOKEN" -s -X POST \
  "https://iam.googleapis.com/v1/projects/$PROJECT_ID/serviceAccounts/$SA_UNIQUE_ID:getIamPolicy")

# check if policy is empty
BINDINGS_LENGTH=$(echo "${IAM_POLICY}" | jq -r '.bindings | length')
if [ "${BINDINGS_LENGTH}" -eq 0 ]; then
  echo '{"members":"", "message":"No IAM policy"}'
  exit 0
fi

# returns empty string if not set
MEMBER_LENGTH=$(echo "${IAM_POLICY}" | jq -r ".bindings[] | select(.role==\"$ROLE\") | .members | length")
if [ -z "${MEMBER_LENGTH}" ]; then
  echo '{"members":"", "message":"Role not in IAM policy"}'
  exit 0
fi

MEMBERS=$(echo "${IAM_POLICY}" | jq -r ".bindings[] | select(.role==\"$ROLE\") | .members | join(\",\")")
echo "{\"members\":\"$MEMBERS\", \"message\":\"Found role in IAM policy\"}"
