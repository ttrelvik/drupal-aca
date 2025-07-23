################################################################################
# Terraform + Provider
################################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.37.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  subdomain = replace(var.custom_domain_name, ".${var.dns_zone_name}", "")
}


################################################################################
# Core Infra: RG, Log Analytics & Container Apps Environment
################################################################################

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.workload_name}-${var.environment}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "aca_env" {
  name                       = "cae-${var.workload_name}-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}


################################################################################
# Secrets: Key Vault + DB credentials
################################################################################

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = "ttrelvik-kv-${var.workload_name}-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Set", "Get", "Delete", "Purge", "List"
    ]
  }
}

resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "azurerm_postgresql_flexible_server" "db_server" {
  name                   = "db-${var.workload_name}-${var.environment}"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  sku_name               = "B_Standard_B1ms"
  zone                   = "1"
  administrator_login    = var.db_admin_username
  administrator_password = random_password.db_password.result
  storage_mb             = 32768
  version                = "16"
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "drupaldb"
  server_id = azurerm_postgresql_flexible_server.db_server.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "allow-all-azure-ips"
  server_id        = azurerm_postgresql_flexible_server.db_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_configuration" "enable_pg_trgm" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.db_server.id
  value     = "PG_TRGM"
}

resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_postgresql_flexible_server.db_server.fqdn
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_access_policy" "drupal_app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.drupal.identity[0].principal_id

  secret_permissions = [
    "Get", "List"
  ]
}


################################################################################
# Persistence: Storage Account & File Share for Drupal
################################################################################

resource "azurerm_storage_account" "sa" {
  name                     = "st${var.workload_name}${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "files" {
  name                 = "drupal-files"
  storage_account_id = azurerm_storage_account.sa.id
  quota                = 50
}

resource "azurerm_container_app_environment_storage" "files" {
  name                         = "drupal-files"                               # arbitrary unique name
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  account_name         = azurerm_storage_account.sa.name
  share_name                   = azurerm_storage_share.files.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadWrite"
}


################################################################################
# App: Azure Container App running Drupal + Mounted Azure File share
################################################################################

resource "azurerm_container_app" "drupal" {
  name                         = "ca-${var.workload_name}-${var.environment}"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "drupal"
      image  = "drupal:11.2.2-apache-bookworm"
      cpu    = 0.5
      memory = "1.0Gi"

      # Pass DB creds from Key Vault
      env {
        name  = "POSTGRES_DB"
        value = azurerm_postgresql_flexible_server_database.db.name
      }
      env {
        name  = "POSTGRES_USER"
        value = azurerm_postgresql_flexible_server.db_server.administrator_login
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "db-password-secret"
      }
      env {
        name        = "POSTGRES_HOST"
        secret_name = "db-host-secret"
      }

      # Mount the File Share at Drupal’s files directory
      volume_mounts {
        name       = "drupal-files"
        path       = "/var/www/html/sites/default/files"
      }
    }

    # Define the Azure File share volume
    volume {
      name         = "drupal-files"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.files.name
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # Hook up Key Vault secrets
  secret {
    name                = "db-password-secret"
    key_vault_secret_id = azurerm_key_vault_secret.db_password.id
    identity            = "System"
  }
  secret {
    name                = "db-host-secret"
    key_vault_secret_id = azurerm_key_vault_secret.db_host.id
    identity            = "System"
  }
}


################################################################################
# DNS + Custom Domain + Managed SSL
################################################################################

data "azurerm_dns_zone" "existing" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_resource_group_name
}

resource "azurerm_dns_cname_record" "drupal_cname" {
  name                = local.subdomain
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 300
  record              = azurerm_container_app.drupal.latest_revision_fqdn
}

resource "azurerm_dns_txt_record" "drupal_verification" {
  name                = "asuid.${local.subdomain}"
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 300

  record {
    value = azurerm_container_app.drupal.custom_domain_verification_id
  }

  depends_on = [
    azurerm_container_app.drupal
  ]
}

resource "azurerm_container_app_custom_domain" "drupal" {
  name             = var.custom_domain_name
  container_app_id = azurerm_container_app.drupal.id

  depends_on = [
    azurerm_dns_cname_record.drupal_cname,
    azurerm_dns_txt_record.drupal_verification,
  ]
}
