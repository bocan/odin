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

variable "ami_override" {
  type        = string
  description = "The Debian Sid AMI can be updated too fast.  Set this if you don't want to update it."
  default     = null
}

variable "users_for_key" {
  type        = list(string)
  description = "The users or sts roles to give access to the customer managed key"
  default     = null
}
