# terraform {
#   backend "azurerm" {
#     resource_group_name  = "tfstate"
#     storage_account_name = "tfstatestorageacct"
#     container_name       = "tfstate"
#     key                  = "infra.tfstate"
#   }
# }

terraform {
  backend "local" {
    path = "./infra.tfstate"
  }
}