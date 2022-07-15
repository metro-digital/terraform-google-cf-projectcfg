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

function get_dns_netblocks() {
	# remove " from dig output using xargs
	# store output in variable to loop over - piping directly into loop
	# would create a subshell as a result and arrays IPV4 and IPV6 are out of scope
	RECORDS=$(dig +short txt "$1" | xargs)
	for RECORD in $RECORDS; do
		case "$RECORD" in
		ip4:*) IPV4+=("${RECORD#*:}") ;;
		ip6:*) IPV6+=("${RECORD#*:}") ;;
		include:*) get_dns_netblocks "${RECORD#*:}" ;;
		esac
	done
}

# needed to store IPv4 subnetworks
IPV4=()
# needed to store IPv6 subnetworks
IPV6=()

# check all programs needed are installed
check_program jq
check_program dig
check_program xargs

get_dns_netblocks _netblocks.metrosystems.net

# print out JSON result - terraform does not support arrays
# so we simply make them a huge string (and split in terraform by space)
jq -c -n --arg ipv4 "${IPV4[*]:-}" --arg ipv6 "${IPV6[*]:-}" \
	'{"ipv4": $ipv4 , "ipv6": $ipv6 }'
