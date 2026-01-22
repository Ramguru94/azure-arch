terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # Note: No backend block here means state stays local
}

provider "azurerm" {
  features {}
}

