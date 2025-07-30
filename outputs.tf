output "drupal_url" {
  description = "The URL to access your Drupal application."
  value       = "https://${var.custom_domain_name}"
}

output "database_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.db_server.fqdn
}

output "key_vault_name" {
  description = "The name of the Azure Key Vault storing the application secrets."
  value       = azurerm_key_vault.kv.name
}

output "bind_certificate_command" {
  description = "The Azure CLI command to bind the managed certificate to your custom domain after deployment."
  value = <<EOT
Run this command to bind your HTTPS certificate after the CNAME has propagated:

az containerapp hostname bind \
  --resource-group ${azurerm_resource_group.rg.name} \
  --name ${azurerm_container_app.drupal.name} \
  --environment ${azurerm_container_app_environment.aca_env.name} \
  --hostname ${var.custom_domain_name} \
  --validation-method CNAME
EOT
}