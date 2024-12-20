# TODO
- inline docs
- user migration docs
- bootstrap adjustments to new parameters
- bootstrap testing

Inputs:

roles                                               iam_policy
non_authoritative_roles                             iam_policy_non_authoritative_roles

custom_roles                                        custom_roles
> members                                           > project_iam_policy_members


service_accounts                                    service_accounts
> iam                                               > iam_policy
> iam_non_authoritative_roles                       > iam_policy_non_authoritative_roles
> project_roles                                     > project_iam_policy_roles


Outputs:
project custom roles
