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
  subdomain = replace(var.custom_domain_name, ".${var.dns_zone_name}", "")
}

#################################################################
# Core Infrastructure: RG, Log Analytics & Container App Env    #
#################################################################

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.workload_name}-${var.environment}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
}

resource "azurerm_container_app_environment" "aca_env" {
  name                       = "cae-${var.workload_name}-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id     = azurerm_subnet.container_app_subnet.id
}

#################################################################
# Network infrastructure: vnets and subnets                     #
#################################################################

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.workload_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet for the Container App Environment
resource "azurerm_subnet" "container_app_subnet" {
  name                 = "snet-containerapp"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/23"]
}

# Create a subnet for the PostgreSQL Flexible Server
resource "azurerm_subnet" "postgres_subnet" {
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  # Delegation for PostgreSQL Flexible Server
  # This allows the PostgreSQL server to manage its own networking
  delegation {
    name = "postgres"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

# Create a private DNS zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres_dns_zone" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the private DNS zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "${azurerm_virtual_network.vnet.name}-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

#################################################################
# Identity & Secrets: Key Vault, UAI, and DB Credentials        #
#################################################################

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-${var.workload_name}-${var.environment}"
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
  name = "kv-${var.workload_name}-${random_string.suffix.result}"
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

#################################################################
# Database: PostgreSQL Flexible Server                          #
#################################################################

resource "azurerm_postgresql_flexible_server" "db_server" {
  name                   = "db-${var.workload_name}-${var.environment}"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  sku_name               = var.postgres_sku_name
  administrator_login    = var.db_admin_username
  administrator_password = random_password.db_password.result
  storage_mb             = var.postgres_storage_mb
  version                = var.postgres_version
  zone                   = "2"
  delegated_subnet_id        = azurerm_subnet.postgres_subnet.id
  private_dns_zone_id        = azurerm_private_dns_zone.postgres_dns_zone.id
  public_network_access_enabled = false

  lifecycle {
    prevent_destroy = true
  }
}

# Drupal requires the PG_TRGM extension for full-text search
resource "azurerm_postgresql_flexible_server_configuration" "pg_trgm" {
    name      = "azure.extensions"
    server_id = azurerm_postgresql_flexible_server.db_server.id
    value     = "PG_TRGM"
}

# Create the initial database for Drupal
resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "drupaldb"
  server_id = azurerm_postgresql_flexible_server.db_server.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

#################################################################
# Persistence: Storage Account & File Share for Drupal          #
#################################################################

resource "azurerm_storage_account" "st" {
  name                     = "st${replace(var.workload_name, "-", "")}${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_share" "sites" {
  name                 = "drupal-sites"
  storage_account_id   = azurerm_storage_account.st.id
  quota                = var.file_share_quota

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_container_app_environment_storage" "sites_storage_link" {
  name                         = "drupal-sites-storage"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  account_name                 = azurerm_storage_account.st.name
  share_name                   = azurerm_storage_share.sites.name
  access_key                   = azurerm_storage_account.st.primary_access_key
  access_mode                  = "ReadWrite"
}

# The azure container app ingress controller will manage certs for the custom domain
# but Drupal will need its own cert for its SAML SSO configuration.
resource "azurerm_storage_share" "certs" {
  name                 = "drupal-certs"
  storage_account_id   = azurerm_storage_account.st.id
  quota                = 1 # Smallest possible size (1 GB)

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_container_app_environment_storage" "certs_storage_link" {
  name                         = "drupal-certs-storage"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  account_name                 = azurerm_storage_account.st.name
  share_name                   = azurerm_storage_share.certs.name
  access_key                   = azurerm_storage_account.st.primary_access_key
  access_mode                  = "ReadWrite"
}

#################################################################
# App: Azure Container App running Drupal + Init Container      #
#################################################################

# Drupal Container App
resource "azurerm_container_app" "drupal" {
  name                         = "ca-${var.workload_name}-${var.environment}"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  revision_mode                = var.revision_mode

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai.id]
  }

  # Link to the Docker Hub for pulling the Drupal image
  registry {
    server   = "index.docker.io"
    username = var.dockerhub_username
    password_secret_name = "dockerhub-password-secret"
  }

  # Secrets are defined here, referencing Key Vault via Managed Identity
  secret {
    name                = "db-password-secret"
    key_vault_secret_id = azurerm_key_vault_secret.db_password.versionless_id
    identity            = azurerm_user_assigned_identity.uai.id
  }
  secret {
    name                = "db-host-secret"
    key_vault_secret_id = azurerm_key_vault_secret.db_host.versionless_id
    identity            = azurerm_user_assigned_identity.uai.id
  }
    secret {
    name = "dockerhub-password-secret"
    value = var.dockerhub_password
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    # Scale settings for the container app
    min_replicas = var.drupal_min_replicas
    max_replicas = var.drupal_max_replicas

    # The initContainer runs before the main container to prepare the volume
    init_container {
      name   = "drupal-sites-initializer"
      image  = var.drupal_image
      cpu    = 0.25
      memory = "0.5Gi"

      # Temporary mount path for the init script
      volume_mounts {
        name = "drupal-sites-volume"
        path = "/mnt/drupal-sites"
      }

      # This command copies default files to the volume if it's not already initialized
      command = ["/bin/sh", "-c", <<-EOT
      if [ ! -f /mnt/drupal-sites/default/settings.php ]; then
          echo 'Initializing sites directory...'
          cp -aR /var/www/html/sites/. /mnt/drupal-sites/
          chown -R www-data:www-data /mnt/drupal-sites
          echo 'Initialization complete.'
      else
          echo 'Sites directory already initialized.'
      fi
      EOT
      ]
    }

    container {
      name   = "drupal"
      image  = var.drupal_image
      cpu    = var.drupal_cpu
      memory = var.drupal_memory

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

      volume_mounts {
        name = "drupal-sites-volume"
        path = "/var/www/html/sites" # Final mount path for the Drupal application
      }
      volume_mounts {
        name = "drupal-certs-volume"
        path = "/etc/ssl/private" # A secure, non-web-accessible path
      }
    }

    volume {
      name         = "drupal-sites-volume"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.sites_storage_link.name
    }
    volume {
      name         = "drupal-certs-volume"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.certs_storage_link.name
    }
  }
}

#################################################################
# DNS + Custom Domain + Managed SSL                             #
#################################################################

data "azurerm_dns_zone" "existing" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_resource_group_name
}

resource "azurerm_dns_cname_record" "drupal_cname" {
  name                = local.subdomain
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = var.cname_ttl
  record              = azurerm_container_app.drupal.ingress[0].fqdn
}

resource "azurerm_dns_txt_record" "drupal_verification" {
  name                = "asuid.${local.subdomain}"
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = var.cname_ttl

  record {
    value = azurerm_container_app.drupal.custom_domain_verification_id
  }
}

resource "azurerm_container_app_custom_domain" "drupal" {
  name             = var.custom_domain_name
  container_app_id = azurerm_container_app.drupal.id

lifecycle {
    # When using an Azure created Managed Certificate these values must be added to ignore_changes
    # to prevent resource recreation.
    ignore_changes = [certificate_binding_type, container_app_environment_certificate_id]
  }

  depends_on = [
    azurerm_dns_cname_record.drupal_cname,
    azurerm_dns_txt_record.drupal_verification,
  ]
}