#################################################################
# Identity & Secrets: Key Vault, UAI, and DB Credentials        #
#################################################################

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-${local.env_vars.workload_name}-${terraform.workspace}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Generate a random suffix for kv resource name
resource "random_string" "suffix" {
  length  = 8
  special = false # No special characters
  upper   = false # Lowercase letters only
}

resource "azurerm_key_vault" "kv" {
  name = "kv-${local.env_vars.workload_name}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  # Access for the user/principal running Terraform
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions =[
      "Set", "Get", "Delete", "Purge", "List"
    ]
  }

  # Access for the Container App's Managed Identity
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.uai.principal_id
    secret_permissions = [
      "Get", "List"
    ]
  }
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "random_password" "db_password" {
  length  = var.random_password_length
  special = var.random_password_special
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_postgresql_flexible_server.db_server.fqdn
  key_vault_id = azurerm_key_vault.kv.id
}