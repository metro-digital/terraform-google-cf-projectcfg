# DEFAULT VPC

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=2 -->

- [General](#general)
  - [Serverless VPC Access](#serverless-vpc-access)
  - [Cloud NAT](#cloud-nat)
    - [Migrating From Static to Automatic IP Address Allocation](#migrating-from-static-to-automatic-ip-address-allocation)
  - [Google Kubernetes Engine Support](#google-kubernetes-engine-support)
  - [Proxy-Only subnets](#proxy-only-subnets)
- [IP Configurations](#ip-configurations)
  - [172.16.0.0/12 (172.16.0.0 - 172.31.255.255)](#172160012-1721600---17231255255)
  - [10.0.0.0/8 (10.0.0.0 - 10.255.255.255)](#100008-10000---10255255255)
  - [192.168.0.0/16 (192.168.0.0 - 192.168.255.255)](#1921680016-19216800---192168255255)
- [Preconfigured Firewall Rules](#preconfigured-firewall-rules)
  - [fw-allow-ssh-iap](#fw-allow-ssh-iap)
  - [fw-allow-rdp-iap](#fw-allow-rdp-iap)

<!-- mdformat-toc end -->

## General

> [!IMPORTANT]
> The VPC set up via this module does not have connectivity to METRO's
> on-premise systems. The VPC is completely isolated from all other METRO
> resources which are not accessible from the internet. If you require a network
> which is connected to METRO's on-premise network, please check the
> documentation of the METRO-internal
> [on-premise connectivity feature][on-premise connectivity].

The creation of a default VPC network depends on the
[`vpc_regions`][input variables] input variable.

The VPC aims to support most default use cases like hosting Compute Instances
and private connections to managed Services like Cloud SQL (Private Service
Connect). Other features like [Serverless VPC Access](#serverless-vpc-access),
[GKE support](#google-kubernetes-engine-support) and [Cloud NAT](#cloud-nat) and
[Proxy Only subnets](#proxy-only-subnets) are configurable per region.

The module aims to support all regions allowed within the different Landing
Zones provided by Cloud Foundation. Those landing zones usually allow a certain
[value group] defined in the [location organization policy] set on this landing
zone.

**Regions currently supported in `eu-locations`:**

|            Region | Location               |
| ----------------: | ---------------------- |
|      europe-west1 | St. Ghislain, Belgium  |
|      europe-west3 | Frankfurt, Germany     |
|      europe-west4 | Eemshaven, Netherlands |
|      europe-west8 | Milan, Italy           |
|      europe-west9 | Paris, France          |
|     europe-west10 | Berlin, Germany        |
|     europe-west12 | Turin, Italy           |
|     europe-north1 | Hamina, Finland        |
|   europe-central2 | Warsaw, Poland         |
| europe-southwest1 | Madrid, Spain          |

**Regions currently supported in `asia-locations`:**

|          Region | Location                |
| --------------: | ----------------------- |
|      asia-east1 | Changhua County, Taiwan |
|      asia-east2 | Hong Kong, China        |
| asia-northeast1 | Tokyo, Japan            |
| asia-northeast2 | Osaka, Japan            |
| asia-northeast3 | Seoul, South Korea      |
|     asia-south1 | Mumbai, India           |
|     asia-south2 | Delhi, India            |
| asia-southeast1 | Jurong West, Singapore  |
| asia-southeast2 | Jakarta, Indonesia      |
|     me-central1 | Doha, Qatar             |
|     me-central2 | Dammam, Saudi Arabia    |
|        me-west1 | Dammam, Saudi Arabia    |

### Serverless VPC Access

Serverless VPC Access allows your serverless services to access resources hosted
within the VPC created by the module. It is disabled by default. If you set the
`serverless_vpc_access` attribute of a region, a Serverless VPC Access connector
will be provisioned in the respective region.

```hcl
vpc_regions = {
  # Create subnetwork in europe-west1 Serverless VPC Access enabled
  europe-west1 = {
    serverless_vpc_access = true
  },
  # The subnet in europe-west3 will not have any Serverless VPC Access
  # connectors because the feature is disabled by default.
  europe-west3 = {}
}
```

### Cloud NAT

Access to internet resources from the default VPC should be done via NAT gateway
instead of public IP addresses on your Compute resources. To facilitate this,
the module provisions Cloud NAT gateways and their accompanying Cloud Routers in
each region that is configured via the `vpc_regions` input variable.

All NAT gateways are by default provisioned with automatic IP allocation:

```hcl
vpc_regions = {
  # A NAT gateway in europe-west1 will be created with automatic IP allocation
  europe-west1 = {}
}
```

If you require a static IP allocation for your Cloud NAT gateways, e.g. because
you need to allowlist your internet-facing IP address in a service that you are
consuming via the internet), you can configure the number of required IPs via an
attribute:

```hcl
vpc_regions = {
  # Two IP addresses will be allocated for use by Cloud NAT in europe-west1
  europe-west1 = {
    nat = {
      mode    = "MANUAL"
      num_ips = 2
    }
  }
}
```

Alternatively, if you do not need any Cloud NAT gateways in a region, you can
opt-out of the creation of any Cloud NAT resources by setting the `num_ips`
attribute to `0`:

```hcl
vpc_regions = {
  # No Cloud NAT resources will be created in europe-west1
  europe-west1 = {
    nat = {
      mode = "DISABLED"
    }
  }
}
```

#### Migrating From Static to Automatic IP Address Allocation

The module's default setting is to provision a NAT gateway using automatic IP
address allocation. However, if you used a version of the module < `v3`, your
NAT resources will have been provisioned using manual IP address allocation.

We generally recommend you to use automatic IP address allocation in all cases
in which you do not need to allowlist your internet-facing IP addresses in
external systems.

Due to the way that the IP addresses are allocated in manual mode via Terraform
and bound to the NAT gateway in Google Cloud, you cannot simply update your
configuration to migrate to the new allocation strategy.

To migrate to the new allocation strategy, perform the following steps:

1. Grant yourself the permission to manage the NAT gateway in your project. You
   must be in the *manager* group if your project to do this interactively via
   the Google Cloud Console. A sufficient role for this task is the
   `Compute Network Admin` (`roles/compute.networkAdmin`).

1. Navigate to the NAT gateway configuration of your project in the Google Cloud
   Console. Open the NAT gateway that you want to migrate to use automatic IP
   address allocation, switch the allocation mode in the UI and save the
   changes. This will drop open session currently held by the NAT gateway.

1. Change your Terraform configuration for the `vpc_regions` input variable to
   no longer reference the `MANUAL` mode:

   ```hcl
   vpc_regions = {
     europe-west1 = {
       nat = {
         # You can also completely remove the `mode` attribute. The default
         # value is `AUTO`.
         mode = "AUTO"
       }
     }
   }
   ```

1. Apply your Terraform code. Terraform will remove the previously managed
   static IP addresses of your NAT gateway. You are now using automatic IP
   address allocation.

### Google Kubernetes Engine Support

Each GKE clusters needs secondary ranges configured on a subnetwork that should
contain the node pool(s) for GKE clusters. One secondary range for pods, and one
for services. The module supports adding those secondary ranges to your
subnetworks, but only supports one GKE cluster (one set of ranges). Secondary
ranges are allocated from the `10.0.0.0/8` prefix. Each service range is `/20`
in size, resulting in 4096 possible services per GKE cluster. Each pod range is
`/16` in size, resulting in 256 nodes with 28160 pods (110 pods per node) per
GKE cluster.

```hcl
vpc_regions = {
  # Create subnetwork in europe-west1 with secondary ranges
  europe-west1 = {},
  # Create subnetwork in europe-west3 with secondary ranges, explicitly enabled
  europe-west3 = {
    gke_secondary_ranges = true
  },
  # Create subnetwork in europe-west4 without secondary ranges
  europe-west4 = {
    gke_secondary_ranges = false
  }
}
```

### Proxy-Only subnets

[Proxy-only subnets] are used for Envoy-based load balancers. The module will
create one network in each region by default. Each network has a size of `/23`.

The creation can be disabled by setting the `proxy_only` attribute to false, see
also [input variables]:

```hcl
vpc_regions = {
  # Create subnetwork in europe-west1 with proxy_only subnet
  europe-west1 = {},
  # Create subnetwork in europe-west3 with proxy_only subnet, explicitly enabled
  europe-west3 = {  # Create a subnetwork in europe-west1
    proxy_only = true
  },
  # Create subnetwork in europe-west4 without proxy_only subnet
  europe-west4 = {  # Create a subnetwork in europe-west1
    proxy_only = false
  }
}
```

## IP Configurations

The module uses ranges from [RFC 1918] to create the subnetworks.

When you want to create additional subnetworks or other network resources in the
default VPC consuming [RFC 1918] IP addresses, please take ranges from the
tables below marked for usage from outside the module to avoid conflicts between
your resources and any future module features.

In the unlikely event that the blocks marked for outside usage are not big
enough for your use-case, please reach out to Cloud Foundation team. We will
then work with you to determine if your use case justifies additional ranges to
be blocked.

### 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)

| Range           | Usage                                 |
| --------------- | ------------------------------------- |
| 172.16.0.0/15   | Primary ranges                        |
| 172.18.0.0/23   | Serverless VPC Access Connectors      |
| 172.18.2.0/23   | *currently unused*                    |
| 172.18.4.0/22   | *currently unused*                    |
| 172.18.8.0/21   | *currently unused*                    |
| 172.18.16.0/20  | *currently unused*                    |
| 172.18.32.0/19  | *currently unused*                    |
| 172.18.64.0/18  | Proxy Only subnetworks                |
| 172.18.128.0/17 | *currently unused*                    |
| 172.19.0.0/16   | *currently unused*                    |
| 172.20.0.0/16   | Private Service Access (VPC peerings) |
| 172.21.0.0/16   | *currently unused*                    |
| 172.22.0.0/15   | *currently unused*                    |
| 172.24.0.0/14   | *currently unused*                    |
| 172.28.0.0/14   | **To be used outside of the module**  |

### 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)

| Range         | Usage                                |
| ------------- | ------------------------------------ |
| 10.0.0.0/15   | Secondary ranges (GKE Services)      |
| 10.2.0.0/15   | *currently unused*                   |
| 10.4.0.0/14   | *currently unused*                   |
| 10.8.0.0/13   | *currently unused*                   |
| 10.16.0.0/12  | *currently unused*                   |
| 10.32.0.0/11  | Secondary ranges (GKE Pod)           |
| 10.64.0.0/10  | *currently unused*                   |
| 10.128.0.0/10 | *currently unused*                   |
| 10.192.0.0/10 | **To be used outside of the module** |

### 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)

Please do not use `192.168.0.0/16`. consider it completely **reserved for
further use.**

## Preconfigured Firewall Rules

The module can create some firewall rules depending on your configuration. For
details on how to enable/disable firewall rules, see the `firewall_rules` input.

### fw-allow-ssh-iap

This rule allows SSH traffic from all known IP Addresses used by Cloud
Identity-Aware Proxy.

**Applies to:** Every instance inside VPC with network tag `fw-allow-ssh-iap`

### fw-allow-rdp-iap

This rule allows RDP traffic from all known IP Addresses used by Cloud
Identity-Aware Proxy.

**Applies to:** Every instance inside VPC with network tag `fw-allow-rdp-iap`

[input variables]: TERRAFORM.md#inputs
[location organization policy]: https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations#location_types
[on-premise connectivity]: https://metrodigital.atlassian.net/wiki/x/XQLMBw
[proxy-only subnets]: https://cloud.google.com/load-balancing/docs/proxy-only-subnets
[rfc 1918]: https://datatracker.ietf.org/doc/html/rfc1918
[value group]: https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations#value_groups
