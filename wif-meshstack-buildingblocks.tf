# Copyright 2026 METRO Digital GmbH
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

locals {
  meshstack_bb_pool_providers = { for k, v in flatten([
    for sa, sacfg in var.service_accounts : [for bb in sacfg.meshstack_buildingblocks :
      [for audience in bb.audiences :
        {
          (bb.issuer) = audience
        }
      ]
    ] if can(length(sacfg.meshstack_buildingblocks) > 0)
  ]) : keys(v)[0] => values(v)[0]... }

  meshstack_bb_pool_provider_subjects = { for k, v in flatten([
    for sa, sacfg in var.service_accounts : [for bb in sacfg.meshstack_buildingblocks :
      [for subject in bb.subjects :
        {
          (bb.issuer) = subject
        }
      ]
    ] if can(length(sacfg.meshstack_buildingblocks) > 0)
  ]) : keys(v)[0] => values(v)[0]... }
}

resource "google_iam_workload_identity_pool" "meshstack_buildingblocks" {
  count                     = local.meshstack_buildingblocks_enabled
  project                   = var.project_id
  workload_identity_pool_id = "meshstack-buildingblocks"
  description               = "Identity pool for meshStack building blocks"
}

resource "google_iam_workload_identity_pool_provider" "meshstack_buildingblocks" {
  for_each = local.meshstack_bb_pool_providers
  project  = var.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack_buildingblocks[0].workload_identity_pool_id
  workload_identity_pool_provider_id = md5(each.key)
  description                        = <<-EOD
    OIDC identity provider for meshStack building blocks
    GKE Cluster
        Project ID: ${provider::google::project_from_id(each.key)}
        Location: ${provider::google::location_from_id(each.key)}
        Name: ${provider::google::name_from_id(each.key)}"
  EOD

  oidc {
    issuer_uri        = each.key
    allowed_audiences = each.value
  }

  # Map the OIDC token's `sub` claim to google.subject
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = join(" || ", [
    for subject in local.meshstack_bb_pool_provider_subjects[each.key] :
    "google.subject == '${subject}'"
  ])
}
