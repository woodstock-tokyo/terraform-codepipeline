variable "enabled" {
  description = "Whether or not to enable this module"
  default     = true
  type        = bool
}

variable "github_token" {
  default     = ""
  description = "GitHub token used for API access. If not provided, can be sourced from the `GITHUB_TOKEN` environment variable"
  type        = string
}

variable "github_organization" {
  description = "GitHub organization to use when creating webhooks"
  type        = string
}

variable "github_repositories" {
  description = "List of repository names which should be associated with the webhook"
  type        = list(string)
  default     = []
}

variable "webhook_url" {
  description = "Webhook URL"
  type        = string
}

variable "webhook_content_type" {
  description = "Webhook Content Type (E.g. json)"
  default     = "json"
  type        = string
}

variable "webhook_secret" {
  description = "Webhook secret"
  default     = ""
  type        = string
}

variable "webhook_insecure_ssl" {
  description = "Webhook Insecure SSL (E.g. trust self-signed certificates)"
  default     = false
  type        = bool
}

variable "active" {
  description = "Indicate of the webhook should receive events"
  default     = true
  type        = bool
}

variable "events" {
  # Full list of events available here: https://developer.github.com/v3/activity/events/types/
  description = "A list of events which should trigger the webhook."
  type        = list(string)
  default     = ["issue_comment", "pull_request", "pull_request_review", "pull_request_review_comment"]
}
