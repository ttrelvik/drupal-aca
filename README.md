# drupal-aca
Terraform deploy Drupal+PostgreSQL to Azure Container App
tom@trelvik.net

As best I can tell, hashicorp/azurerm 4.x doesn't seem to support binding
managed certificates to a custom domain on a Container App (or some combination
of that, anyway), so after running terraform apply, you will usually need to then
manually bind a managed certificate to the Container App with something like:

az containerapp hostname bind \
  --resource-group ${azurerm_resource_group.rg.name} \
  --name ${azurerm_container_app.drupal.name} \
  --environment ${azurerm_container_app_environment.aca_env.name} \
  --hostname ${var.custom_domain_name} \
  --validation-method CNAME

The output of a successful "terraform apply" will give the exact command necessary.
