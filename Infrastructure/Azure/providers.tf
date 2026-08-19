terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "wiztfstateaccount123" 
    container_name       = "tfstate"
    key                  = "wiz-exercise.terraform.tfstate"
    use_oidc             = true 
  }
}

provider "azurerm" {
  features {}
  use_oidc = true 
}
