# Copyright 2023 METRO Digital GmbH
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
  wif_runtime_k8s_clusters = toset(flatten([
    for sa, config in var.service_accounts : [for runtime_sa in config.runtime_service_accounts : runtime_sa.cluster_id] if can(length(config.runtime_service_accounts) > 0)
  ]))
}

resource "google_iam_workload_identity_pool" "runtime_k8s" {
  provider = google
  for_each = local.wif_runtime_k8s_clusters
  project  = data.google_project.project.project_id

  workload_identity_pool_id = md5(each.key)
  display_name              = each.key
  description               = "Allows authentication from Cloud Native Runtime Kubernetes cluster '${each.key}'"

  depends_on = [
    google_project_iam_binding.roles,
    google_project_service.wif
  ]
}

resource "google_iam_workload_identity_pool_provider" "runtime_k8s_cluster" {
  provider = google
  for_each = local.wif_runtime_k8s_clusters
  project  = data.google_project.project.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.runtime_k8s[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id = "kubernetes"
  display_name                       = "Kubernetes"
  description                        = "OIDC Identity Pool Provider for Cloud Native Runtime Kubernetes cluster '${each.key}'"

  attribute_mapping = {
    "google.subject" = "assertion.sub"
    "attribute.aud"  = "assertion.aud[0]"
  }

  oidc {
    allowed_audiences = [
      "cf.metro.cloud/wif-cloud-native-runtime",
      "https://cf.metro.cloud/wif-cloud-native-runtime"
    ]
    issuer_uri = "https://storage.googleapis.com/${each.key}-wif-bucket"
  }

  depends_on = [
    google_iam_workload_identity_pool.runtime_k8s
  ]
}
