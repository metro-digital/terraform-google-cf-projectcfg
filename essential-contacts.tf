resource "google_project_service" "essential-contacts" {
  project = data.google_project.project.project_id
  count   = length(var.essential_contacts) > 0 ? 1 : 0
  service = "essentialcontacts.googleapis.com"

  # The user may enable/use the needed service somewhere else, too! Hence,
  # we will never disabling it again, even if we initially enabled it here. Keeping
  # the service enabled is a lot less dangerous than disabling it, even if we do
  # not have a reason to keep it enabled any longer. Users can still disable it via
  # the CLI / UI if need be.
  disable_on_destroy = false
}

resource "google_essential_contacts_contact" "contact" {
  for_each                            = var.essential_contacts
  parent                              = data.google_project.project.id
  email                               = each.key
  language_tag                        = each.value.language
  notification_category_subscriptions = each.value.categories

  depends_on = [
    google_project_service.essential-contacts,
    google_project_iam_binding.roles
  ]
}
