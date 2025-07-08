variable "location" {
  default = "West Europe"
}

variable "vm_name" {
  default = "week10vm"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {}

variable "rg_name" {
  description = "Name of the resource group"
  type        = string
}
