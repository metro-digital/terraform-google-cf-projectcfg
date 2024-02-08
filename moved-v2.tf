# Resources moved to make the module compliant with
# terraform code style requirements
# will be removed in v3 module version

moved {
  from = google_netblock_ip_ranges.iap-forwarders
  to   = google_netblock_ip_ranges.iap_forwarders
}

moved {
  from = external.active-roles
  to   = external.active_roles
}

moved {
  from = google_project_service.essential-contacts
  to   = google_project_service.essential_contacts
}

moved {
  from = google_compute_firewall.allow-all-internal
  to   = google_compute_firewall.allow_all_internal
}

moved {
  from = google_compute_firewall.allow-icmp-metro-public
  to   = google_compute_firewall.allow_icmp_metro_public
}

moved {
  from = google_compute_firewall.allow-http-metro-public
  to   = google_compute_firewall.allow_http_metro_public
}

moved {
  from = google_compute_firewall.allow-https-metro-public
  to   = google_compute_firewall.allow_https_metro_public
}

moved {
  from = google_compute_firewall.allow-ssh-metro-public
  to   = google_compute_firewall.allow_ssh_metro_public
}

moved {
  from = google_compute_firewall.allow-ssh-iap
  to   = google_compute_firewall.allow_ssh_iap
}

moved {
  from = google_compute_firewall.allow-all-iap
  to   = google_compute_firewall.allow_all_iap
}

moved {
  from = google_compute_subnetwork.proxy-only
  to   = google_compute_subnetwork.proxy_only
}

moved {
  from = google_iam_workload_identity_pool.github-actions
  to   = google_iam_workload_identity_pool.github_actions
}

moved {
  from = google_iam_workload_identity_pool.runtime-k8s
  to   = google_iam_workload_identity_pool.runtime_k8s
}

moved {
  from = google_iam_workload_identity_pool_provider.runtime-k8s-cluster
  to   = google_iam_workload_identity_pool_provider.runtime_k8s_cluster
}

moved {
  from = google_project_service_identity.servicenetworking-service-account
  to   = google_project_service_identity.servicenetworking_service_account
}

moved {
  from = google_project_iam_member.servicenetworking-service-account-binding
  to   = google_project_iam_member.servicenetworking_service_account_binding
}
