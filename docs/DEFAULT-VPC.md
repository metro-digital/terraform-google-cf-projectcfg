<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [Default VPC](#default-vpc)
- [Supported regions](#supported-regions)
- [Preconfigured firewall rules](#preconfigured-firewall-rules)
  - [fw-allow-all-internal](#fw-allow-all-internal)
  - [fw-allow-icmp-metro-public](#fw-allow-icmp-metro-public)
  - [fw-allow-http-metro-public](#fw-allow-http-metro-public)
  - [fw-allow-https-metro-public](#fw-allow-https-metro-public)
  - [fw-allow-ssh-metro-public](#fw-allow-ssh-metro-public)
  - [fw-allow-ssh-iap](#fw-allow-ssh-iap)
  - [fw-allow-all-iap](#fw-allow-all-iap)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Default VPC

The creation of a default VPC network is enabled by default and can be disabled via `skip_default_vpc_creation` input parameter.
One of the main differences to the default VPC created by Google is the network range used. This module uses [RFC 1918] ip ranges
from `172.16.0.0/12` while Google uses ranges from `10.0.0.0/8` as this prefix is used widely used within Metros internal network.
This should help users to easily separate VPCs with on-premise connectivity from those without.

# Supported regions

The module aims to supports all main regions within the European Union:
* europe-west1
* europe-west2
* europe-west3
* europe-west4
* europe-north1

# Preconfigured firewall rules
The module creates some firewall rules allow basic network communication based on network tags.

## fw-allow-all-internal
This rule allows all traffic from inside the VPC. Each instance inside the VPC can communicate with every other system using any kind of protocol.

**Applies to:** Every instance inside VPC

## fw-allow-icmp-metro-public
This rule allows incoming ICMP (ping) traffic from all known Metro IP addresses (public)

**Applies to:** Every instance inside VPC with network tag `fw-allow-icmp-metro-public`

## fw-allow-http-metro-public
This rule allows HTTP traffic from all known Metro IP Addresses (public)

**Applies to:** Every instance inside VPC with network tag `fw-allow-http-metro-public`

## fw-allow-https-metro-public
This rule allows HTTPS traffic from all known Metro IP Addresses (public)

**Applies to:** Every instance inside VPC with network tag `fw-allow-https-metro-public`

## fw-allow-ssh-metro-public
This rule allows SSH traffic from all known Metro IP Addresses (public). Usage of this rule is **not recommend** to access instances via SSH. **Please use IAP whenever possible.**

**Applies to:** Every instance inside VPC with network tag `fw-allow-ssh-metro-public`

## fw-allow-ssh-iap
This rule allows SSH traffic from all known IP Addresses used by Cloud Identity-Aware Proxy

**Applies to:** Every instance inside VPC with network tag `fw-allow-ssh-iap`

## fw-allow-all-iap
This rule allows ALL traffic from all known IP Addresses used by Cloud Identity-Aware Proxy

**Applies to:** Every instance inside VPC with network tag `fw-allow-all-iap`

[RFC 1918]: https://datatracker.ietf.org/doc/html/rfc1918
