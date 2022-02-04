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
  if [ -z "$PRG" ] ; then
    echo "ERROR - \"$1\" not found" >&2
    exit 1
  fi
}

check_program jq
check_program curl

eval "$(jq -r '@sh "PROJECT_ID=\(.project_id) ACCESS_TOKEN=\(.access_token)"')"

curl -H "Authorization: Bearer $ACCESS_TOKEN" -s -X POST \
  "https://cloudresourcemanager.googleapis.com/v3/projects/$PROJECT_ID:getIamPolicy" | \
  jq -c '{roles: [.bindings[].role] | join(",")}'
