terraform {
  backend "azurerm" {
    resource_group_name  = "sandbox"
    storage_account_name = "tfstatecommonbackend"
    container_name       = "tfstate"
    key                  = "kubernetes-config.terraform.tfstate"
  }
}

data "terraform_remote_state" "cluster_infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "sandbox"
    storage_account_name = "tfstatecommonbackend"
    container_name       = "tfstate"
    key                  = "infra.terraform.tfstate"
  }
}
