#################################################################
# App: Azure Container App running Drupal + Init Container      #
#################################################################

# Drupal Container App
resource "azurerm_container_app" "drupal" {
  name                         = "ca-${local.env_vars.workload_name}-${terraform.workspace}"
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
    min_replicas = local.env_vars.drupal_min_replicas
    max_replicas = local.env_vars.drupal_max_replicas

    # The initContainer runs before the main container to prepare the volume
    init_container {
      name   = "drupal-sites-initializer"
      image  = local.env_vars.drupal_image
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
      image  = local.env_vars.drupal_image
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