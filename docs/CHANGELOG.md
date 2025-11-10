# Changelog

## [3.4.0](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.3.0...v3.4.0) (2025-11-10)


### Features

* support v7 of the terraform google provider ([a7c22e7](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/a7c22e7bbf46a91f21b6721cfdb2b1d33d2688a9))

## [3.3.0](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.2.0...v3.3.0) (2025-09-05)


### Features

* add google_project data source to module output ([29734c8](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/29734c81681762f97cc4a025dd96305e0a408882))

## [3.2.0](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.1.1...v3.2.0) (2025-05-14)


### Features

* add support for tags to service accounts ([336eac6](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/336eac628ea9738b8e6ad79255bc666b229e9425))

## [3.1.1](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.1.0...v3.1.1) (2025-04-24)


### Bug Fixes

* filter deleted IAM principals ([b27b7e5](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/b27b7e595ebc6b935e3ce9bd56b38b7b356ad3f3))

## [3.1.0](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.0.2...v3.1.0) (2025-02-20)


### Features

* allow non cf panel projects ([4018b7c](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/4018b7cf975c88f5fbcfeb4c506e16cd7660c9e3))

## [3.0.2](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.0.1...v3.0.2) (2025-02-19)


### Bug Fixes

* douplicate project_id parameter ([ff3337e](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/ff3337e28c3908352c37a1ecc5f407ce1def02b9))
* passing repo to bootstrap causes failure ([0ad82d0](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/0ad82d0fe2be5fb47927944f42b6c2fd5bd8033f))

## [3.0.1](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v3.0.0...v3.0.1) (2025-02-11)


### Bug Fixes

* add missing on-prem landing zone ([518581a](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/518581a43643d03266bd79e1c72b0494661e9853))

## [3.0.0](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v2.4.1...v3.0.0) (2025-02-06)


### ⚠ BREAKING CHANGES

* The module no longer automatically configures the default VPC. NAT gateways are created with automatic IP allocation mode.
* The module is now fully authoritative on the IAM policy of the project as well as the IAM policy of service accounts created by this module. This implementation replaces the non-authoritative one which relied on external shell scripts and is now fully Terraform-native. All changes required from consumers of this module are now outlined in a migration guide.
* Removed `move`-blocks from previous Releases. Ensure configuration runs with the latest 2.x release of the module before upgrading to this major release.
* To match the Cloud Security Baseline, the module creates fewer firewall rules. Previously created firewall rules are **automatically removed**. The new input variable `firewall_rules` allows to configure which firewall rules are created.
* To comply with Security Policies, the module no longer grants the `roles/editor` role to the Compute Engine default service account. The previously existing toggle to remove this role from the service account is now removed, as this is now the default behaviour.
* The module no longer outputs METRO net blocks as those are fetched from an DNS record that is not very well maintained. Firewall rules should also not rely on the fact that traffic originates from METRO's public IPs to consider it trustworthy.

### Features

* dns logging policy ([88ea167](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/88ea16749ba2fffa058b5fd509e0418b3c06e691))
* iam for service accounts is optional ([22f702a](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/22f702a061a21a45957a407748d78d746be52bb4))
* improved bootstrap ([b6732df](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/b6732df49a1490bc4d5386a9574f114a524545dd))


### Bug Fixes

* correct default value for VPC DNS logging ([7233d5b](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/7233d5ba44af591ec525ddfe54f6319fa1aad1bc))
* correct invalid terraform syntax ([758fe4a](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/758fe4a779bcd93c3cba5509be25c806670e848d))
* fix output file generation in bootstrap ([9597074](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/959707417960f2e0da834c62c335028f800052b6))
* GCP project name and number retrieval in bootstrap script ([#62](https://github.com/metro-digital/terraform-google-cf-projectcfg/issues/62)) ([d355b67](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/d355b675e849e35417c64140cbf7bd8639fcbc4c))
* improve default VPC handling ([8ef834f](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/8ef834f8014a7f10971a0939b5cda1a26eccd234))
* pin state bucket module using pessimistic version constraint ([fc2d0b8](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/fc2d0b82c13b372898cdbb481a71ec8dd19347fe))
* trim .git from repos should the user not have done so themselves ([1fa91f2](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/1fa91f2550fea07082e7a81b99cde0941424ca0c))


### Reverts

* change back change log to default type ([fa1d1e9](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/fa1d1e972928dfaf08d47320c3017a97fd92f3e5))


### Code Refactoring

* always deprivilege compute engine sa ([f87ecb6](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/f87ecb6e588f35db2a7f09ef8c28679de4bc3178))
* delete move blocks ([4a58051](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/4a580517a6462663de636480175b52658457ae90))
* new default VPC handling ([c6f931d](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/c6f931da85d2111c9fc6139ca71eedb8c1d1bcfa))
* new firewall handling ([9c40968](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/9c40968ce641c5120e8f4ebd2ff8a9f6cea7cc6a))
* new iam handling ([1444f83](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/1444f8374a06bbbf923690ebb5161f5359261b36))
* remove metro_netblocks output ([98b596d](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/98b596d63cd4ffce6ac6a4e95cf64b2765ff33b1))
