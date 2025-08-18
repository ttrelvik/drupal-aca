#################################################################
# Database: PostgreSQL Flexible Server                          #
#################################################################

resource "azurerm_postgresql_flexible_server" "db_server" {
  name                   = "db-${local.env_vars.workload_name}-${terraform.workspace}"
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