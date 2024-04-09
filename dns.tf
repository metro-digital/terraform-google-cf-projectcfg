resource "google_dns_policy" "default" {
  count       = var.skip_default_vpc_creation ? 0 : 1
  name        = "default"
  description = "DNS policy for the networks created by the projectcfg module"
  project     = data.google_project.project.project_id

  enable_logging = true

  networks {
    network_url = google_compute_network.default[0].self_link
  }
}
