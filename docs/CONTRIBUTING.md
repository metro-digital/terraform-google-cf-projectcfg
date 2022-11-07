# Contributing

This document provides guidelines for contributing to this [terraform] module.
When contributing to this repository, please first discuss the change you wish to make via issue
with the owners of this repository before making a change.

## Pull Request Process

1. Update the README.md with details of changes to the interface.
1. Increase the version numbers in any examples files and the README.md to the new version that this
   Pull Request would represent. The versioning scheme we use is [SemVer](http://semver.org/).
1. You may merge the Pull Request in once you have the sign-off of one other developer, or if you
   do not have permission to do that, you may request a reviewer to merge it for you.

## Dependencies

The following dependencies must be installed on the development system:

- [pre-commit framework][pcf]
  - [pre-commit git hooks for terraform][pcf-tf]
    - [tfsec]
    - [tflint]
  - [pre-commit git hooks for doctoc][pcf-doctoc]

## Generating Documentation for inputs and outputs

The Inputs and Outputs tables in the README are automatically generated based on
the `variables` and `outputs` of the module. These tables must be refreshed if the
module interfaces are changed.

### Execution

Documentation is updated when running the pre-commit hooks: `pre-commit run -a`

[pcf]: https://pre-commit.com/
[pcf-doctoc]: https://github.com/thlorenz/doctoc
[pcf-tf]: https://github.com/antonbabenko/pre-commit-terraform
[terraform]: https://terraform.io/
[tflint]: https://github.com/terraform-linters/tflint
[tfsec]: https://github.com/tfsec/tfsec
