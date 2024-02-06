plugin "google" {
    enabled = true
    version = "0.26.0"
    source  = "github.com/terraform-linters/tflint-ruleset-google"
}
plugin "terraform" {
  enabled = true
  preset = "all"
}
