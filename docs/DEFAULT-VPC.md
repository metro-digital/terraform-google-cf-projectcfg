# DEFAULT VPC

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [General](#general)
- [Supported regions](#supported-regions)
- [IP configurations](#ip-configurations)
  - [Free to use IP address ranges in the default VPC](#free-to-use-ip-address-ranges-in-the-default-vpc)
    - [10.0.0.0/8 (10.0.0.0 - 10.255.255.255)](#100008-10000---10255255255)
    - [172.16.0.0/12 (172.16.0.0 - 172.31.255.255)](#172160012-1721600---17231255255)
    - [192.168.0.0/16 (192.168.0.0 - 192.168.255.255)](#1921680016-19216800---192168255255)
  - [Primary ranges](#primary-ranges)
  - [Secondary ranges](#secondary-ranges)
    - [GKE](#gke)
      - [Services ranges](#services-ranges)
      - [Pod ranges](#pod-ranges)
  - [Serverless VPC access](#serverless-vpc-access)
  - [Proxy only subnetworks](#proxy-only-subnetworks)
  - [Additional used IP ranges](#additional-used-ip-ranges)
- [Preconfigured firewall rules](#preconfigured-firewall-rules)
  - [fw-allow-all-internal](#fw-allow-all-internal)
  - [fw-allow-ssh-iap](#fw-allow-ssh-iap)
  - [fw-allow-rdp-iap](#fw-allow-rdp-iap)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## General

The creation of a default VPC network is enabled by default and can be disabled
via `skip_default_vpc_creation` input parameter.

One of the main differences  to the default VPC created by Google is the
network range used. Google uses ranges from `10.0.0.0/8` for the default VPC,
as this prefix is used widely used within METROs internal network this module
uses [RFC 1918] ip ranges from `172.16.0.0/12` for primary ranges. This should
help users to easily separate VPCs with on-premise connectivity from those
without. Secondary ranges are picked from the `10.0.0.0/8` range.

## Supported regions

The module aims to support all main regions within the European Union:

| Region            | Location                   |
| ----------------- | -------------------------- |
| europe-west1      | St. Ghislain, Belgium, EU  |
| europe-west3      | Frankfurt, Germany EU      |
| europe-west4      | Eemshaven, Netherlands, EU |
| europe-west8      | Milan, Italy, EU           |
| europe-west9      | Paris, France, EU          |
| europe-north1     | Hamina, Finland, EU        |
| europe-central2   | Warsaw, Poland, EU         |
| europe-southwest1 | Madrid, Spain, EU          |

## IP configurations

### Free to use IP address ranges in the default VPC

When you want to create additional subnetworks or other network resources
in the default VPC please take ranges from the ones listed here to avoid any
further feature implemented inside the module conflicting with your resources.

#### 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)

We will not use `10.192.0.0/10` for any further implementation.

#### 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)

We will not use `172.28.0.0/14` for any further implementation.

#### 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)

Please do not use `192.168.0.0/16`, consider it reserved for further use.

### Primary ranges

For primary ranges we allocated `172.16.0.0/15`. Any region will use one
a `/20` subrange from this block, allowing up to 32 regions.

| Region            | IP range        |
| ----------------- |-----------------|
| europe-west1      | 172.16.0.0/20   |
| europe-west3      | 172.16.32.0/20  |
| europe-west4      | 172.16.48.0/20  |
| europe-west8      | 172.16.112.0/20 |
| europe-west9      | 172.16.16.0/20  |
| europe-north1     | 172.16.64.0/20  |
| europe-central2   | 172.16.80.0/20  |
| europe-southwest1 | 172.16.96.0/20  |

### Secondary ranges

#### GKE

Each GKE clusters needs 1 secondary range for pods, and one for services.
The module supports adding those secondary ranges to your subnetworks, but
only supports one GKE cluster (one set of ranges). For secondary ranges from
the 10.0.0.0/8 range are used.

##### Services ranges

Each services range is `/20` in size, resulting in 4096 possible services per
GKE cluster. Reserved range for services is `10.0.0.0/15`, allowing up to 32
regions.

| Region            | IP range      |
| ----------------- | ------------- |
| europe-west1      | 10.0.0.0/20   |
| europe-west3      | 10.0.32.0/20  |
| europe-west4      | 10.0.48.0/20  |
| europe-west8      | 10.0.144.0/20 |
| europe-west9      | 10.0.16.0/20  |
| europe-north1     | 10.0.64.0/20  |
| europe-central2   | 10.0.80.0/20  |
| europe-southwest1 | 10.0.96.0/20  |

##### Pod ranges

Each pod range is `/16` in size, resulting in 256 nodes with 28160 pods
(110 pods per node) per GKE cluster. Reserved range for services is
`10.32.0.0/11`, allowing up to 32 regions.

| Region            | IP range     |
| ----------------- | ------------ |
| europe-west1      | 10.32.0.0/16 |
| europe-west3      | 10.34.0.0/16 |
| europe-west4      | 10.35.0.0/16 |
| europe-west8      | 10.39.0.0/16 |
| europe-west9      | 10.33.0.0/16 |
| europe-north1     | 10.36.0.0/16 |
| europe-central2   | 10.37.0.0/16 |
| europe-southwest1 | 10.38.0.0/16 |

### Serverless VPC access

For Serverless VPC access connectors created by the module we use ranges from
the `172.18.0.0/23` block, allowing up to 32 regions.

| Region            | IP range        |
| ----------------- | --------------- |
| europe-west1      | 172.18.0.0/28   |
| europe-west3      | 172.18.0.32/28  |
| europe-west4      | 172.18.0.48/28  |
| europe-west8      | 172.18.0.112/28 |
| europe-west9      | 172.18.0.16/28  |
| europe-north1     | 172.18.0.64/28  |
| europe-central2   | 172.18.0.80/28  |
| europe-southwest1 | 172.18.0.96/28  |

### Proxy only subnetworks

[Proxy only subnets] are used for Envoy-based load balancers. We use
`172.18.64.0/18` allowing 32 regions following Googles recommendation
to use networks with a `/23` each.

| Region            | IP range       |
| ----------------- | -------------- |
| europe-west1      | 172.18.64.0/23 |
| europe-west9      | 172.18.66.0/23 |
| europe-west3      | 172.18.68.0/23 |
| europe-west4      | 172.18.70.0/23 |
| europe-north1     | 172.18.72.0/23 |
| europe-central2   | 172.18.74.0/23 |
| europe-southwest1 | 172.18.76.0/23 |
| europe-west8      | 172.18.78.0/23 |

### Additional used IP ranges

| IP range      | Description                                             |
| ------------- | ------------------------------------------------------- |
| 172.20.0.0/16 | Used for VPC peerings created by Private Service Access |

## Preconfigured firewall rules

The module can create some firewall rules depending on your configuration.
For details how to enable/disable firewalls, see the `firewall_rules` input.

### fw-allow-all-internal

This rule allows all traffic within the VPC. Each instance inside the VPC
can communicate with every other system using any kind of protocol.

**Applies to:** Every instance inside VPC

### fw-allow-ssh-iap

This rule allows SSH traffic from all known IP Addresses used by Cloud
Identity-Aware Proxy

**Applies to:** Every instance inside VPC with network tag `fw-allow-ssh-iap`

### fw-allow-rdp-iap

This rule allows RDP traffic from all known IP Addresses used by Cloud
Identity-Aware Proxy

**Applies to:** Every instance inside VPC with network tag `fw-allow-rdp-iap`

[RFC 1918]: https://datatracker.ietf.org/doc/html/rfc1918
[proxy only subnets]: https://cloud.google.com/load-balancing/docs/proxy-only-subnets
