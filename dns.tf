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
  name             = local.env_vars.custom_domain_name
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

# This null_resource runs a local-exec provisioner to bind the managed certificate
# to the custom domain after the DNS records have been created and propagated.
resource "null_resource" "bind_certificate" {
  # This resource depends on the custom domain and its DNS records being created first.
  depends_on = [
    azurerm_container_app_custom_domain.drupal,
    azurerm_dns_cname_record.drupal_cname,
    azurerm_dns_txt_record.drupal_verification
  ]

  # Triggers re-running this command if key values change.
  triggers = {
    hostname    = local.env_vars.custom_domain_name
    app_name    = azurerm_container_app.drupal.name
    rg_name     = azurerm_resource_group.rg.name
    environment = azurerm_container_app_environment.aca_env.name
  }

  # This provisioner runs the Azure CLI command on the machine executing Terraform.
  provisioner "local-exec" {
    command = <<EOT
      az containerapp hostname bind \
        --resource-group "${self.triggers.rg_name}" \
        --name "${self.triggers.app_name}" \
        --environment "${self.triggers.environment}" \
        --hostname "${self.triggers.hostname}" \
        --validation-method CNAME
    EOT
  }
}