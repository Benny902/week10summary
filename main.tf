provider "azurerm" {
  features {}
  subscription_id = "00e80aee-87ac-481e-89b3-6653e95e6bfa"
}

module "rg" {
  source   = "./modules/resource_group"
  name     = var.rg_name
  location = var.location
}

module "network" {
  source  = "./modules/network"
  rg_name = module.rg.name
  location = var.location
}

module "vm" {
  source           = "./modules/vm"
  rg_name          = module.rg.name
  location         = var.location
  vm_name          = var.vm_name
  admin_username   = var.admin_username
  ssh_public_key   = var.ssh_public_key
  nic_id           = module.network.nic_id
  public_ip_dep    = module.network

  depends_on = [module.network]
}
