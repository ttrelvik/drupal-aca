# This file sets up monitoring for the Azure Container App and its environment by exporting logs and metrics to a storage account.

# Create a storage account to hold the exported diagnostics
resource "azurerm_storage_account" "monitoring" {
  name                     = "st${replace(local.env_vars.workload_name, "-", "")}monitoring"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Diagnostic setting for the Container App Environment to capture ALL logs
resource "azurerm_monitor_diagnostic_setting" "environment_diagnostics" {
  name               = "cae-diagnostics-logs"
  target_resource_id = azurerm_container_app_environment.aca_env.id
  storage_account_id = azurerm_storage_account.monitoring.id

  # Captures stdout/stderr from all apps in the environment (e.g., Drupal)
  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  # Captures platform-level logs (scaling, revisions, etc.)
  enabled_log {
    category = "ContainerAppSystemLogs"
  }
}

# Diagnostic setting specifically for the Container App to capture its metrics
resource "azurerm_monitor_diagnostic_setting" "container_app_metrics" {
  name               = "ca-diagnostics-metrics"
  target_resource_id = azurerm_container_app.drupal.id
  storage_account_id = azurerm_storage_account.monitoring.id

  # Exporting all metrics from the container app itself
  enabled_metric {
    category = "AllMetrics"
  }
}