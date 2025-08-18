terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
    random = {
      source  = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  # Selects the appropriate configuration map based on the current Terraform workspace.
  # It falls back to the "dev" configuration if the workspace name doesn't match a key.
  env_vars = lookup(var.environment_variables, terraform.workspace, var.environment_variables["prod"])

  # The subdomain is derived from the custom domain name in the selected map.
  subdomain = replace(local.env_vars.custom_domain_name, ".${var.dns_zone_name}", "")
}

#################################################################
# Core Infrastructure: RG, Log Analytics & Container App Env    #
#################################################################

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.env_vars.workload_name}-${terraform.workspace}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-${local.env_vars.workload_name}-${terraform.workspace}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
}

resource "azurerm_container_app_environment" "aca_env" {
  name                       = "cae-${local.env_vars.workload_name}-${terraform.workspace}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id     = azurerm_subnet.container_app_subnet.id
}