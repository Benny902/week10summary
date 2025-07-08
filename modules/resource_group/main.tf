resource "azurerm_resource_group" "devops_rg" {
  name     = var.name
  location = var.location
}
