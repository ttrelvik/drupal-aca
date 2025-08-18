#################################################################
# Persistence: Storage Account & File Share for Drupal          #
#################################################################

resource "azurerm_storage_account" "st" {
  name                     = "st${replace(local.env_vars.workload_name, "-", "")}${terraform.workspace}"
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