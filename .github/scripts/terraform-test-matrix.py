# Copyright 2026 METRO Digital GmbH
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

"""Select the latest stable patch of each Terraform series supported by the tests."""

import json
import re
import urllib.request


# Terraform 1.16 fixes hashicorp/terraform#38974: test applies with optional
# ephemeral inputs. The module itself still supports Terraform >= 1.10.
MINIMUM_TEST_SERIES = (1, 16)
RELEASE_INDEX = "https://releases.hashicorp.com/terraform/index.json"


def select_versions(versions):
    latest = {}
    for version in versions:
        # Exclude alpha, beta, RC, and other prereleases.
        if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) is None:
            continue
        major, minor, patch = map(int, version.split("."))
        series = (major, minor)
        if series >= MINIMUM_TEST_SERIES:
            latest[series] = max(patch, latest.get(series, -1))

    if not latest:
        raise ValueError("No stable Terraform versions >= 1.16 found in the release index")

    return [
        f"{major}.{minor}.{patch}"
        for (major, minor), patch in sorted(latest.items())
    ]


def main():
    with urllib.request.urlopen(RELEASE_INDEX, timeout=30) as response:
        versions = select_versions(json.load(response)["versions"])
    # GitHub Actions job output, consumed by fromJSON in the test matrix.
    print(f"terraform-versions={json.dumps(versions)}")


if __name__ == "__main__":
    main()
