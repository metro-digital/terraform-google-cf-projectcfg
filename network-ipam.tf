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

locals {
  # Please always also update docs/DEFAULT-VPC.md when doing changes here!

  # We decided against using the IPAM service provided by the network connectivity service for now,
  # as we see a bigger implementation and migration effort we would like to avoid. Also the IPAM service
  # could fulfill all our needs already, it would be a bigger effort as we would need to create certain ranges
  # to have the fine grain control we would like to have (it only supports FOR_VPC and
  # EXTERNAL_TO_VPC at the current point in time).

  # Therefor we do the IPAM in this file using some locals.

  # Google groups regions into multi-regions, and those are referenced in organization policies by value groups.
  #
  # The module currently supports two value groups:
  #   - eu-locations
  #   - asia-locations
  #
  # Please also see https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations
  #
  # When reserving blocks, please take into account each block should always support enough regions to cover the
  # value group. It seems like supporting 16 regions (or a multiple of it like 32) is a reasonable assumption for
  # bigger geographic value blocks like the one we currently implement.
  #
  # The initially allocated blocks support 32 regions, and we decided to use the first 16 for the current regions
  # in eu-locations, and the remaining 16 for regions in asia-locations.

  # Primary ranges (/20 per region)
  # Blocks
  #   - 172.16.0.0/15 = 172.16.0.0 to 172.17.255.255
  #
  # Usage:
  #  - eu-locations:    172.16.0.0/16
  #  - asia-locations:  172.17.0.0/16
  default_vpc_primary_ranges = {
    # eu-locations
    europe-west1      = "172.16.0.0/20"   # St. Ghislain, Belgium, EU
    europe-west9      = "172.16.16.0/20"  # Paris, France, EU
    europe-west3      = "172.16.32.0/20"  # Frankfurt, Germany EU
    europe-west4      = "172.16.48.0/20"  # Eemshaven, Netherlands, EU
    europe-north1     = "172.16.64.0/20"  # Hamina, Finland, EU
    europe-central2   = "172.16.80.0/20"  # Warsaw, Poland, EU
    europe-southwest1 = "172.16.96.0/20"  # Madrid, Spain, EU
    europe-west8      = "172.16.112.0/20" # Milan, Italy, EU
    europe-west10     = "172.16.128.0/20" # Berlin, Germany, EU
    europe-west12     = "172.16.144.0/20" # Turin, Italy, EU
    # asia-locations
    asia-east1      = "172.17.0.0/20"
    asia-east2      = "172.17.16.0/20"
    asia-northeast1 = "172.17.32.0/20"
    asia-northeast2 = "172.17.48.0/20"
    asia-northeast3 = "172.17.64.0/20"
    asia-south1     = "172.17.80.0/20"
    asia-south2     = "172.17.96.0/20"
    asia-southeast1 = "172.17.112.0/20"
    asia-southeast2 = "172.17.128.0/20"
    me-central1     = "172.17.144.0/20"
    me-central2     = "172.17.160.0/20"
    me-west1        = "172.17.176.0/20"
  }

  # Serverless VPC Access Connectors (/28 per region)
  # Blocks
  #   - 172.18.0.0/23 = 172.18.0.0 to 172.18.1.255
  #
  # Usage:
  #  - eu-locations:    172.18.0.0/24
  #  - asia-locations:  172.18.1.0/24
  default_vpc_subnet_connectors = {
    # eu-locations
    europe-west1      = "172.18.0.0/28"
    europe-west9      = "172.18.0.16/28"
    europe-west3      = "172.18.0.32/28"
    europe-west4      = "172.18.0.48/28"
    europe-north1     = "172.18.0.64/28"
    europe-central2   = "172.18.0.80/28"
    europe-southwest1 = "172.18.0.96/28"
    europe-west8      = "172.18.0.112/28"
    europe-west10     = "172.18.0.128/28"
    europe-west12     = "172.18.0.144/28"
    # asia-locations
    asia-east1      = "172.18.1.0/28"
    asia-east2      = "172.18.1.16/28"
    asia-northeast1 = "172.18.1.32/28"
    asia-northeast2 = "172.18.1.48/28"
    asia-northeast3 = "172.18.1.64/28"
    asia-south1     = "172.18.1.80/28"
    asia-south2     = "172.18.1.96/28"
    asia-southeast1 = "172.18.1.112/28"
    asia-southeast2 = "172.18.1.128/28"
    me-central1     = "172.18.1.144/28"
    me-central2     = "172.18.1.160/28"
    me-west1        = "172.18.1.176/28"
  }

  # Proxy Only subnetworks (/23 per region)
  # Blocks
  #   - 172.18.64.0/18 = 172.18.64.0 to 172.18.127.255
  #
  # Usage:
  #  - eu-locations:    172.18.64.0/19
  #  - asia-locations:  172.18.96.0/19
  default_vpc_proxy_only = {
    # eu-locations
    europe-west1      = "172.18.64.0/23"
    europe-west9      = "172.18.66.0/23"
    europe-west3      = "172.18.68.0/23"
    europe-west4      = "172.18.70.0/23"
    europe-north1     = "172.18.72.0/23"
    europe-central2   = "172.18.74.0/23"
    europe-southwest1 = "172.18.76.0/23"
    europe-west8      = "172.18.78.0/23"
    europe-west10     = "172.18.80.0/23"
    europe-west12     = "172.18.82.0/23"
    # asia-locations
    asia-east1      = "172.18.96.0/23"
    asia-east2      = "172.18.98.0/23"
    asia-northeast1 = "172.18.100.0/23"
    asia-northeast2 = "172.18.102.0/23"
    asia-northeast3 = "172.18.104.0/23"
    asia-south1     = "172.18.106.0/23"
    asia-south2     = "172.18.108.0/23"
    asia-southeast1 = "172.18.110.0/23"
    asia-southeast2 = "172.18.112.0/23"
    me-central1     = "172.18.114.0/23"
    me-central2     = "172.18.116.0/23"
    me-west1        = "172.18.118.0/23"
  }

  # Secondary ranges
  #   - gke-services (/20 per region)
  #   - gke-pods (/16 per region)
  #
  # Blocks
  #   - 10.0.0.0/15  = 10.0.0.0  to 10.1.255.255  (GKE Services)
  #   - 10.32.0.0/11 = 10.32.0.0 to 10.63.255.255	 (GKE Pod)
  #
  # Usage:
  #   - eu-locations:
  #     - gke-services: 10.0.0.0/16
  #     - gke-pods:     10.32.0.0/12
  #   - asia-locations:
  #     - gke-services: 10.1.0.0/16
  #     - gke-pods:     10.48.0.0/12
  default_vpc_secondary_ranges = {
    # eu-locations
    europe-west1      = { gke = { gke-services = "10.0.0.0/20", gke-pods = "10.32.0.0/16" } }
    europe-west9      = { gke = { gke-services = "10.0.16.0/20", gke-pods = "10.33.0.0/16" } }
    europe-west3      = { gke = { gke-services = "10.0.32.0/20", gke-pods = "10.34.0.0/16" } }
    europe-west4      = { gke = { gke-services = "10.0.48.0/20", gke-pods = "10.35.0.0/16" } }
    europe-north1     = { gke = { gke-services = "10.0.64.0/20", gke-pods = "10.36.0.0/16" } }
    europe-central2   = { gke = { gke-services = "10.0.80.0/20", gke-pods = "10.37.0.0/16" } }
    europe-southwest1 = { gke = { gke-services = "10.0.96.0/20", gke-pods = "10.38.0.0/16" } }
    europe-west8      = { gke = { gke-services = "10.0.112.0/20", gke-pods = "10.39.0.0/16" } }
    europe-west10     = { gke = { gke-services = "10.0.128.0/20", gke-pods = "10.40.0.0/16" } }
    europe-west12     = { gke = { gke-services = "10.0.144.0/20", gke-pods = "10.41.0.0/16" } }
    # asia-locations
    asia-east1      = { gke = { gke-services = "10.1.0.0/20", gke-pods = "10.48.0.0/16" } }
    asia-east2      = { gke = { gke-services = "10.1.16.0/20", gke-pods = "10.49.0.0/16" } }
    asia-northeast1 = { gke = { gke-services = "10.1.32.0/20", gke-pods = "10.50.0.0/16" } }
    asia-northeast2 = { gke = { gke-services = "10.1.48.0/20", gke-pods = "10.51.0.0/16" } }
    asia-northeast3 = { gke = { gke-services = "10.1.64.0/20", gke-pods = "10.52.0.0/16" } }
    asia-south1     = { gke = { gke-services = "10.1.80.0/20", gke-pods = "10.53.0.0/16" } }
    asia-south2     = { gke = { gke-services = "10.1.96.0/20", gke-pods = "10.54.0.0/16" } }
    asia-southeast1 = { gke = { gke-services = "10.1.112.0/20", gke-pods = "10.55.0.0/16" } }
    asia-southeast2 = { gke = { gke-services = "10.1.128.0/20", gke-pods = "10.56.0.0/16" } }
    me-central1     = { gke = { gke-services = "10.1.144.0/20", gke-pods = "10.57.0.0/16" } }
    me-central2     = { gke = { gke-services = "10.1.160.0/20", gke-pods = "10.58.0.0/16" } }
    me-west1        = { gke = { gke-services = "10.1.176.0/20", gke-pods = "10.59.0.0/16" } }
  }

  # 172.20.0.0/16 = 172.20.0.0 to 172.20.255.255
  # Used for Private Service Access (VPC peering)
  default_vpc_private_service_access = {
    address       = "172.20.0.0"
    prefix_length = "16"
  }
}
