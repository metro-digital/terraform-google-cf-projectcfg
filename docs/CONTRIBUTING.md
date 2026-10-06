# Contributing

Thank you for taking the time to help us improve this module! This document provides guidelines for
contributing to this [Terraform] module. When contributing to this repository, please first discuss
the change you wish to make via issue with the owners of this repository before making a change. We
are generally open to accept most changes but need to ensure that they align with the overall
strategy that we follow for this module.

## Contributing Changes

If you are a METRO engineer who plans to continuously work on this module, please reach out to
[the Cloud Foundation team][cloud-foundation-contact] to get write access to the repository. If you
only want to contribute a change once, please fork this repository.

> [!IMPORTANT]
> Please make sure that you are legally allowed to contribute your work under the Apache License,
> Version 2.0. Work licensed under different terms cannot be accepted.

After you have performed your changes, please follow these steps to get them accepted:

1. Make sure that you update the license header of any file that you modified. If you are a
   contributor from within METRO, just bump the year to the current year. If you are an outside
   contributor and you performed a significant number of changes to a file, you may add your own
   copyright notice to the header of the modified source files. All files continue to be licensed
   under the Apache License, Version 2.0. Adding your name simply highlights your contribution.

1. Phrase your commit messages following the
   [Conventional Commits specification][conventional-commits]. This ensures that release-please can
   properly associate your change with a major, minor or patch version number bump.

1. If you are not working for METRO, make sure that your commits include a
   [Developer Certificate of Origin (DCO)][dco]. You do not sign away any rights by doing so but
   simply confirm that you are legally allowed to contribute your changes. You can read the full
   text of the DCO [here][dco-text].

1. Run all [pre-commit checks][pcf] (via `pre-commit run -a`). If you don't do that, our pipelines
   will catch any outstanding issues. pre-commit will also make sure to:

   - format your markdown files,
   - trim any unnecessary white space and
   - perform Terraform validations on the code.

1. Open a pull request with your changes (from your local fork or a branch directly in this
   repository). We monitor open pull requests and will get in touch with you via pull request
   comments in case there are any issues. If we for some reason don't respond to your change within
   one week, don't hesitate to reach out directly.

1. After a review, we will merge your pull request and bundle it in a new release. Thank you for
   your help!

## Dependencies

The following dependencies must be installed on the development system:

- [Terraform]
- [pre-commit framework][pcf] and all the configured pre-commit hooks (run `pre-commit install`) and
  their external binaries (if needed).

## Unit Tests

Run the root module's full unit suite with Terraform 1.16 or later:

```sh
terraform init -backend=false -input=false
terraform test
```

The tests in `tests/*.tftest.hcl` mock both the `google` and `google-beta` providers. Most runs use
`command = plan`. Service-account IAM and federation tests use mocked applies to resolve computed
identities and policy reads that are deferred until resources exist. They need no Google Cloud
credentials and create no cloud resources. Initialization downloads provider plugins; Terraform
still uses their schemas to validate the configuration. Shared deterministic fixtures live in
`tests/mocks/`.

The initial suite covers minimal project defaults, API enablement, panel and non-panel IAM,
authoritative IAM composition and preservation, service-account IAM, regional networking and NAT,
GitHub and Kubernetes workload identity federation, and invalid inputs. IAM assertions inspect
composed bindings because the mocked `google_iam_policy` data source does not serialize real policy
JSON. These unit tests exercise module logic; they do not verify Google API behavior or replace
integration tests against a real project. The separate `bootstrap/terraform` generator is outside
this suite's scope.

The `terraform-test` GitHub Actions workflow runs formatting, validation, and the full unit suite on
every pull request. It discovers stable Terraform releases from HashiCorp's release index and
selects the latest patch release of every major/minor series from 1.16 onward, excluding
prereleases. New stable Terraform series and patch releases are picked up automatically. The matrix
crosses these Terraform versions with the latest available 6.x and 7.x releases of both `google` and
`google-beta`, covering each provider major supported by the module. Each job creates a temporary
Terraform override file to constrain both providers to its selected major and initializes with
`-upgrade` so an existing lock file cannot retain a different version. The module's published
provider constraints remain unchanged. All matrix jobs must succeed for the workflow to pass. The
`Pipeline Status` workflow uses `DataDog/ensure-ci-success` to wait for the PR's checks and commit
statuses and fail if any fail. Require its `pipeline-status` check in the repository's branch
protection ruleset to provide a single gate as individual checks evolve. Each matrix job publishes
its exact Terraform and provider versions plus check outcomes to the GitHub Actions run summary,
including failed or skipped checks. The job summary and PR comment share the same result validation
and Markdown renderer in `.github/scripts/terraform-test-results.cjs`.

After the test run completes, `terraform-test-comment` combines the matrix results into a single bot
comment on the PR and updates that comment on subsequent runs and reruns. It ignores results for an
outdated PR commit or run attempt. Partial reruns replace the rerun jobs' artifacts and retain
results for jobs that were not rerun.

The comment publisher uses `workflow_run` so it can also comment on fork PRs while test jobs retain
read-only repository permissions. It runs only trusted code from the default branch and validates
the uploaded result data before creating Markdown. Validation checks version formats and fixed check
outcomes rather than a list of provider majors, so a PR can extend the test matrix without first
updating the publisher on the default branch. GitHub activates this publisher only after its
workflow and script exist on the repository's default branch.

The full suite uses Terraform 1.16 or later because older releases have an
[upstream test/apply bug](https://github.com/hashicorp/terraform/issues/38974) with optional
ephemeral variables, including this module's legacy `roles` migration safeguard.

When adding coverage, use the shared mocks and assert observable configuration, binding contents, or
outputs. Prefer plan-only runs and keep both providers mocked. Use a mocked apply only when a
dependency defers the values being asserted until apply. For validation failures, use
`expect_failures` with the variable or resource that owns the validation. To run one test file:

```sh
terraform test -filter=tests/network.tftest.hcl
```

## Releasing a New Version

We rely on [release-please] to generate new releases. release-please also updates the references to
the latest version of the module in the documentation and code when
[properly marked][release-please-arbitrary-updates]. The changelog is also automatically updated.

A maintainer of the repository will pool multiple changes into one release and release them by:

1. Approving and merging the release-please release pull request.
1. Announcing the new release internally in case of major changes.

[cloud-foundation-contact]: https://metrodigital.atlassian.net/wiki/x/BwLMBw
[conventional-commits]: https://www.conventionalcommits.org/en/v1.0.0/
[dco]: https://opensource.com/article/18/3/cla-vs-dco-whats-difference
[dco-text]: https://developercertificate.org/
[pcf]: https://pre-commit.com/
[release-please]: https://github.com/googleapis/release-please
[release-please-arbitrary-updates]: https://github.com/googleapis/release-please/blob/v16.15.0/docs/customizing.md#updating-arbitrary-files
[terraform]: https://terraform.io/
