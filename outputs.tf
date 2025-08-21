output "drupal_url" {
  description = "The URL to access your Drupal application."
  value       = "https://${local.env_vars.custom_domain_name}"
}

output "database_connection_info" {
  description = "Information for the Drupal database configuration screen. The password is in Key Vault."
  value = {
    host           = azurerm_postgresql_flexible_server.db_server.fqdn
    database_name  = azurerm_postgresql_flexible_server_database.db.name
    username       = var.db_admin_username
    table_prefix   = "(Leave Blank - Not Used)"
  }
}

output "key_vault_name" {
  description = "The name of the Azure Key Vault storing the application secrets."
  value       = azurerm_key_vault.kv.name
}

output "container_shell_command" {
  description = "The command to get a shell on the running Drupal container for debugging."
  value       = "az containerapp exec -g ${azurerm_resource_group.rg.name} -n ${azurerm_container_app.drupal.name} --command '/bin/bash'"
}