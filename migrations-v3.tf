# Copyright 2025 METRO Digital GmbH
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

# Renames, removals and similar done between  v2.x.x and v3.x.x release
# File can be removed with a v4 release. Keep in mind to inform users to at least
# one-time apply the latest v3.x.x release when releasing v4 (if you remove this file)

removed {
  from = google_project_iam_binding.roles

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_iam_binding.custom_roles

  lifecycle {
    destroy = false
  }
}

moved {
  from = google_project_service.project
  to   = google_project_service.this
}

removed {
  from = google_project_iam_member.servicenetworking_service_account_binding

  lifecycle {
    destroy = false
  }
}

# tflint-ignore: terraform_unused_declarations, terraform_standard_module_structure
variable "roles" {
  description = <<-EOD
    Safeguard against unplanned module version upgrades. Not used within the module.
    If this input variable is set to anything else then `null` the variable validation
    will fail and cause an error message providing links to migration instructions.
  EOD
  type        = any
  default     = null
  ephemeral   = true

  validation {
    condition     = var.roles == null
    error_message = <<-EOM
      It seems like the configuration provided to the module is old. It still uses the roles input
      variable. This input variable got removed with the v3 release.

      The v3 release of this module contains several breaking changes compared with the v2 release.

      Therefore, please consult documentation to find out how to upgrade:

        CHANGELOG: https://github.com/metro-digital/terraform-google-cf-projectcfg/blob/main/docs/CHANGELOG.md
        MIGRATION: https://github.com/metro-digital/terraform-google-cf-projectcfg/blob/main/docs/MIGRATION.md

      You will not be able to apply your code until you upgrade or constrain the module version to
      be < 3.0.
    EOM
  }
}
