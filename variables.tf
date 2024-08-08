variable "github_user" {
  type        = string
  description = "The github user I use to let Hugo write back to Github."
  sensitive   = true
}

variable "github_token" {
  type        = string
  description = "The github token I use to let Hugo write back to Github."
  sensitive   = true
}
