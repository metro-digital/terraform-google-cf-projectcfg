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

# Both providers are mocked; these tests make no Google API calls.
mock_provider "google" {
  source = "./tests/mocks"
}

mock_provider "google-beta" {
  source = "./tests/mocks"
}

variables {
  project_id = "cf-unit-test"
}

run "default_regional_network" {
  command = plan

  variables {
    vpc_regions = { europe-west1 = {} }
  }

  assert {
    condition     = length(google_compute_network.default) == 1 && !google_compute_network.default[0].auto_create_subnetworks
    error_message = "Requested regions must create a single custom-mode VPC."
  }

  assert {
    condition = (
      google_compute_subnetwork.default["europe-west1"].private_ip_google_access &&
      output.vpc.subnetworks["europe-west1"].ip_cidr_range == "172.16.0.0/20" &&
      toset([for range in google_compute_subnetwork.default["europe-west1"].secondary_ip_range : "${range.range_name}:${range.ip_cidr_range}"]) == toset([
        "gke-services:10.0.0.0/20", "gke-pods:10.32.0.0/16"
      ])
    )
    error_message = "Regional subnets must use the documented primary and GKE ranges with Private Google Access."
  }

  assert {
    condition     = google_compute_subnetwork.proxy_only["europe-west1"].ip_cidr_range == "172.18.64.0/23" && google_compute_subnetwork.proxy_only["europe-west1"].purpose == "INTERNAL_HTTPS_LOAD_BALANCER"
    error_message = "Proxy-only subnets must use the reserved proxy range and purpose."
  }

  assert {
    condition     = google_compute_router_nat.nat["europe-west1"].nat_ip_allocate_option == "AUTO_ONLY" && length(google_compute_address.address) == 0
    error_message = "Default NAT must allocate IP addresses automatically without reserving static IPs."
  }

  assert {
    condition = (
      google_dns_policy.logging[0].enable_logging &&
      google_compute_firewall.allow_ssh_iap[0].source_ranges == toset(["35.235.240.0/20"]) &&
      one(google_compute_firewall.allow_ssh_iap[0].allow).ports == tolist(["22"]) &&
      one(google_compute_firewall.allow_rdp_iap[0].allow).ports == tolist(["3389"])
    )
    error_message = "DNS logging and IAP-only SSH/RDP firewall rules must be enabled by default."
  }

  assert {
    condition     = toset(keys(google_project_service.this)) == toset(["iam.googleapis.com", "servicenetworking.googleapis.com", "compute.googleapis.com", "dns.googleapis.com", "iap.googleapis.com"])
    error_message = "A VPC must enable all required network APIs."
  }
}

run "manual_nat_and_connector" {
  command = plan

  variables {
    vpc_regions = {
      europe-west1 = {
        nat                   = { mode = "MANUAL", num_ips = 2, min_ports_per_vm = 128 }
        serverless_vpc_access = {}
      }
    }
  }

  assert {
    condition = (
      google_compute_router_nat.nat["europe-west1"].nat_ip_allocate_option == "MANUAL_ONLY" &&
      google_compute_router_nat.nat["europe-west1"].min_ports_per_vm == 128 &&
      toset(keys(google_compute_address.address)) == toset(["europe-west1-0001", "europe-west1-0002"]) &&
      alltrue([for address in google_compute_address.address : address.region == "europe-west1" && address.address_type == "EXTERNAL"])
    )
    error_message = "Manual NAT must reserve the requested static IPs in the correct region."
  }

  assert {
    condition = (
      contains(keys(google_project_service.this), "vpcaccess.googleapis.com") &&
      google_vpc_access_connector.default["europe-west1"].ip_cidr_range == "172.18.0.0/28" &&
      google_vpc_access_connector.default["europe-west1"].min_instances == 2 &&
      google_vpc_access_connector.default["europe-west1"].max_instances == 3
    )
    error_message = "Serverless connectors must enable their API and use the reserved range and default sizing."
  }
}

run "disable_optional_network_features" {
  command = plan

  variables {
    vpc_regions = {
      europe-west1 = {
        nat                  = { mode = "DISABLED" }
        gke_secondary_ranges = false
        proxy_only           = false
      }
    }
    skip_default_vpc_dns_logging_policy = true
    firewall_rules                      = { allow_ssh_iap = false, allow_rdp_iap = false }
  }

  assert {
    condition = (
      length(google_compute_subnetwork.default["europe-west1"].secondary_ip_range) == 0 &&
      length(google_compute_subnetwork.proxy_only) == 0 &&
      length(google_compute_router.router) == 0 &&
      length(google_compute_router_nat.nat) == 0 &&
      length(google_compute_address.address) == 0 &&
      length(google_vpc_access_connector.default) == 0 &&
      length(google_dns_policy.logging) == 0 &&
      length(google_compute_firewall.allow_ssh_iap) == 0 &&
      length(google_compute_firewall.allow_rdp_iap) == 0
    )
    error_message = "Explicit opt-outs must remove the corresponding network resources."
  }
}
