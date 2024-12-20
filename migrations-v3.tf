# Copyright 2024 METRO Digital GmbH
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
