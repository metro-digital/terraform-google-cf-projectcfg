# Changelog

## [3.0.0](https://github.com/metro-digital/terraform-google-cf-projectcfg/compare/v2.4.1...v3.0.0) (2024-12-09)


### ⚠ BREAKING CHANGES

* delete move blocks
* To match the Cloud Security Baseline, the module creates fewer firewall rules. Previously created firewall rules are **automatically removed**. The new input variable `firewall_rules` allows to configure which firewall rules are created.
* To comply with Security Policies, the module no longer grants the `roles/editor` role to the Compute Engine default service account. The previously existing toggle to remove this role from the service account is now removed, as this is now the default behaviour.
* The module no longer outputs METRO net blocks as those are fetched from an DNS record that is not very well maintained. Firewall rules should also not rely on the fact that traffic originates from METRO's public IPs to consider it trustworthy.

### Features

* iam for service accounts is optional ([40607ff](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/40607ff2815806ea9516037dd44baea93a54aa89))
* improved bootstrap ([b6732df](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/b6732df49a1490bc4d5386a9574f114a524545dd))


### Bug Fixes

* correct invalid terraform syntax ([05a0359](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/05a035946a3e2c05c1c66741b157b966127514bc))
* fix output file generation in bootstrap ([9597074](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/959707417960f2e0da834c62c335028f800052b6))
* GCP project name and number retrieval in bootstrap script ([#62](https://github.com/metro-digital/terraform-google-cf-projectcfg/issues/62)) ([d355b67](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/d355b675e849e35417c64140cbf7bd8639fcbc4c))
* trim .git from repos should the user not have done so themselves ([de9128e](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/de9128e61dfcba77f7f496ef8db4daea18951ed4))


### Reverts

* change back change log to default type ([fa1d1e9](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/fa1d1e972928dfaf08d47320c3017a97fd92f3e5))


### Code Refactoring

* always deprivilege compute engine sa ([f87ecb6](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/f87ecb6e588f35db2a7f09ef8c28679de4bc3178))
* delete move blocks ([942709f](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/942709fcb95aab5244c989cae98e77d64312bea8))
* new firewall handling ([9c40968](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/9c40968ce641c5120e8f4ebd2ff8a9f6cea7cc6a))
* remove metro_netblocks output ([98b596d](https://github.com/metro-digital/terraform-google-cf-projectcfg/commit/98b596d63cd4ffce6ac6a4e95cf64b2765ff33b1))
