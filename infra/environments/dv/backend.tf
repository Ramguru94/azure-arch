terraform {
  backend "azurerm" {
    resource_group_name  = "sandbox"
    storage_account_name = "tfstatecommonbackend"
    container_name       = "tfstate"
    key                  = "infra.terraform.tfstate"
  }
}
