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


variable "users_for_key" {
  type        = list(string)
  description = "The users or sts roles to give access to the customer managed key."
  default     = null
}

variable "passphrase" {
  type        = string
  description = "Password to encrypt state."
  sensitive   = true
}

variable "ipv6_addresses" {
  type        = list(string)
  description = "A list of ipv6 addreses to assign to the instance."
}
