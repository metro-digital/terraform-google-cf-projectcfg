# Contributing

Thank you for taking the time to help us improve this module! This document
provides guidelines for contributing to this [Terraform] module. When
contributing to this repository, please first discuss the change you wish to
make via issue with the owners of this repository before making a change. We are
generally open to accept most changes but need to ensure that they align with
the overall strategy that we follow for this module.

## Contributing Changes

If you are a METRO engineer who plans to continuously work on this module,
please reach out to [the Cloud Foundation team][cloud-foundation-contact] to get
write access to the repository. If you only want to contribute a change once,
please fork this repository.

> [!IMPORTANT]
> Please make sure that you are legally allowed to contribute your work under
> the Apache License, Version 2.0. Work licensed under different terms cannot be
> accepted.

After you have performed your changes, please follow these steps to get them
accepted:

1. Make sure that you update the license header of any file that you modified.
   If you are a contributor from within METRO, just bump the year to the current
   year. If you are an outside contributor and you performed a significant
   number of changes to a file, you may add your own copyright notice to the
   header of the modified source files. All files continue to be licensed under
   the Apache License, Version 2.0. Adding your name simply highlights your
   contribution.

1. Phrase your commit messages following the
   [Conventional Commits specification][conventional-commits]. This ensures that
   release-please can properly associate your change with a major, minor or
   patch version number bump.

1. If you are not working for METRO, make sure that your commits include a
   [Developer Certificate of Origin (DCO)][dco]. You do not sign away any rights
   by doing so but simply confirm that you are legally allowed to contribute
   your changes. You can read the full text of the DCO [here][dco-text].

1. Run all [pre-commit checks][pcf] (via `pre-commit run -a`). If you don't do
   that, our pipelines will catch any outstanding issues. pre-commit will also
   make sure to:

   - format your markdown files,
   - trim any unnecessary white space and
   - perform Terraform validations on the code.

1. Open a pull request with your changes (from your local fork or a branch
   directly in this repository). We monitor open pull requests and will get in
   touch with you via pull request comments in case there are any issues. If we
   for some reason don't respond to your change within one week, don't hesitate
   to reach out directly.

1. After a review, we will merge your pull request and bundle it in a new
   release. Thank you for your help!

## Dependencies

The following dependencies must be installed on the development system:

- [Terraform]
- [pre-commit framework][pcf] and all the configured pre-commit hooks (run
  `pre-commit install`) and their external binaries (if needed).

## Releasing a New Version

We rely on [release-please] to generate new releases. release-please also
updates the references to the latest version of the module in the documentation
and code when [properly marked][release-please-arbitrary-updates]. The changelog
is also automatically updated.

A maintainer of the repository will pool multiple changes into one release and
release them by:

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
