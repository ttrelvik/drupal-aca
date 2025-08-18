# Deploying a Scalable and Secure Drupal on Azure Container Apps

This Terraform project provides a robust, production-ready infrastructure to deploy a Drupal application on Azure Container Apps. It is designed with security, scalability, and automation in mind, leveraging a fully VNet-integrated architecture.

The infrastructure is managed using Terraform workspaces to support multiple environments (e.g., `dev`, `prod`, `cmsdev`, `cmsprod`).

## Architecture Overview

This project provisions the following key resources in a secure, private network:

* **Azure Container Apps Environment**: A dedicated, VNet-integrated environment to host the Drupal container app.
* **Azure Container App**: Runs a custom Drupal Docker image. The application scales based on environment-specific replica settings.
* **Azure Database for PostgreSQL Flexible Server**: A private, VNet-integrated database server with public access disabled.
* **Azure Key Vault**: For securely storing and managing all application secrets, including database credentials and API keys.
* **Azure Storage Account**: Provides persistent file storage for the Drupal sites directory and a separate share for SAML certificates.
* **Azure Managed Identity**: A user-assigned identity allows the Container App to securely access other Azure resources like Key Vault without storing credentials in code.
* **Automated DNS and SSL**: Automatically configures a custom domain and uses a local-exec provisioner to bind a managed SSL certificate upon deployment.

## Key Features

* **Workspace-Driven Environments**: Easily manage multiple, isolated environments like `dev` and `prod` using Terraform Workspaces.
* **Automated Setup**: An `initContainer` automatically prepares the persistent storage volume on the first launch, copying the necessary Drupal files.
* **Secure by Default**: All components are deployed within a Virtual Network. The PostgreSQL database is not exposed to the public internet.
* **Passwordless Secrets Management**: The Drupal container app uses its Managed Identity to fetch database credentials directly from Key Vault at runtime.
* **Persistent & Stateful**: Azure File Shares are used for the Drupal `sites` directory and for SAML certificates, ensuring data persistence across container restarts and scaling events.
* **Customizable Drupal Image**: The provided `Dockerfile` builds upon the official Drupal image to include common security modules like Password Policy, SecKit, and Login Security.
* **Data Protection**: Critical resources like the PostgreSQL server, Storage Account, and Key Vault are protected from accidental deletion using a `prevent_destroy` lifecycle hook.

## Prerequisites

Before you begin, ensure you have the following:

1.  **Terraform CLI**: Version 1.0 or later.
2.  **Azure CLI**: Logged in to your Azure account (`az login`).
3.  **Azure Subscription**: With permissions to create the resources defined in this project.
4.  **Azure DNS Zone**: An existing public DNS zone where Terraform can create CNAME and TXT records for the custom domain.
5.  **Docker Hub Credentials**: A username and password for Docker Hub to pull the Drupal container image.

## Configuration

1.  **Clone the repository.**
2.  **Create a `terraform.tfvars` file** to provide values for your specific environment. At a minimum, you must provide your Docker Hub credentials.

    ```terraform
    # terraform.tfvars

    # Required: Docker Hub credentials for pulling the container image
    dockerhub_username = "your_dockerhub_username"
    dockerhub_password = "your_dockerhub_password"

    # Optional: Override the DNS zone if it's not the default
    # dns_zone_name = "yourdomain.com"
    # dns_resource_group_name = "rg-where-dns-zone-lives"
    ```

3.  **Review `variables.tf`** for other default settings you may wish to override, such as location, resource SKUs, or container CPU/memory settings.

## Deployment Steps

1.  **Initialize Terraform**:
    ```shell
    terraform init
    ```

2.  **Create or Select a Workspace**: Each workspace corresponds to an environment defined in `variables.tf`.
    ```shell
    # To deploy a new production environment
    terraform workspace new prod

    # Or to switch to an existing one
    terraform workspace select prod
    ```

3.  **Plan the Deployment**: Review the resources that Terraform will create.
    ```shell
    terraform plan
    ```

4.  **Apply the Configuration**:
    ```shell
    terraform apply
    ```
    Upon successful application, Terraform will automatically run the Azure CLI command to bind the managed certificate to your custom domain.

## Managing Environments

To work on a different environment (e.g., `dev`), simply switch your workspace and run `plan` or `apply` again.

```shell
terraform workspace select dev
terraform apply
```

## Destroying Resources

To tear down an environment, run the destroy command from the corresponding workspace.

```shell
terraform workspace select prod
terraform destroy
```

**Note:** The `prevent_destroy` lifecycle hook is enabled on the Key Vault, PostgreSQL server, and Storage Account. If you intend to completely destroy all resources, you must first comment out or remove these blocks from the respective `.tf` files.