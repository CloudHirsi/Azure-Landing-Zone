terraform {
  backend "azurerm" {
    resource_group_name  = "Identity"
    storage_account_name = "tfbackend7890"
    container_name       = "tfbackend"
    key                  = "prod.terraform.tfstate"
  }
}