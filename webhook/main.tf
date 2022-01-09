provider "github" {
  token = var.github_token
  owner = var.github_organization
}

resource "github_repository_webhook" "default" {
  count = var.enabled && length(var.github_repositories) > 0 ? length(var.github_repositories) : 0

  repository = var.github_repositories[count.index]
  active     = var.active

  configuration {
    url          = var.webhook_url
    content_type = var.webhook_content_type
    secret       = var.webhook_secret
    insecure_ssl = var.webhook_insecure_ssl
  }

  events = var.events

  # Ignore, if the webhook already exists
  lifecycle {
    ignore_changes = all
  }
}
