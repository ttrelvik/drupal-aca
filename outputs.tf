output "drupal_url" {
  description = "The URL to access your Drupal application."
  value       = "https://${local.env_vars.custom_domain_name}"
}

output "database_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.db_server.fqdn
}

output "key_vault_name" {
  description = "The name of the Azure Key Vault storing the application secrets."
  value       = azurerm_key_vault.kv.name
}
