variable "workload_name" {
  type        = string
  description = "Short name for this workload (used in resource names)."
  default     = "drupal"
}

variable "environment" {
  type        = string
  description = "Environment tag (e.g. dev, qa, prod)."
  default     = "prod"
}

variable "location" {
  type        = string
  description = "Azure region where resources will be deployed (e.g. eastus)."
  default     = "eastus"
}

variable "log_analytics_sku" {
  type        = string
  description = "Log Analytics SKU."
  default     = "PerGB2018"
}

variable "log_analytics_retention_in_days" {
  type        = number
  description = "Log Analytics retention in days."
  default     = 30
}

variable "random_password_length" {
  type        = number
  description = "Length of the generated database password."
  default     = 24
}

variable "random_password_special" {
  type        = bool
  description = "Whether to include special characters in the generated database password."
  default     = true
}

variable "postgres_sku_name" {
  type        = string
  description = "PostgreSQL Flexible Server SKU."
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type        = number
  description = "PostgreSQL storage size in MB."
  default     = 32768
}

variable "postgres_version" {
  type        = string
  description = "PostgreSQL version."
  default     = "16"
}

variable "db_admin_username" {
  type        = string
  description = "PostgreSQL admin username."
  default     = "drupaladmin"
}

variable "storage_account_tier" {
  type        = string
  description = "Storage account tier."
  default     = "Standard"
}

variable "storage_account_replication_type" {
  type        = string
  description = "Storage account replication type."
  default     = "LRS"
}

variable "file_share_quota" {
  type        = number
  description = "File share quota in GB for the Drupal sites directory."
  default     = 5
}

# drupal_image default gets overridden by custom image in terraform.tfvars
variable "drupal_image" {
  type        = string
  description = "Docker image for Drupal (e.g., drupal:11.2.2-apache-bookworm)."
  default     = "drupal:11.2.2-apache-bookworm"
}

variable "drupal_cpu" {
  type        = number
  description = "CPU cores for the Drupal container."
  default     = 0.5
}

variable "drupal_memory" {
  type        = string
  description = "Memory for the Drupal container (e.g., '1Gi')."
  default     = "1Gi"
}

variable "revision_mode" {
  type        = string
  description = "Container App revision mode ('Single' or 'Multiple')."
  default     = "Single"
}

variable "dns_zone_name" {
  type        = string
  description = "The name of the existing DNS zone (e.g., example.com)."
  default     = "az.trelvik.net"
}

variable "dns_resource_group_name" {
  type        = string
  description = "The name of the resource group where the DNS zone is located."
  default     = "rgDns"
}

variable "cname_ttl" {
  type        = number
  description = "TTL for the DNS CNAME and TXT records."
  default     = 300
}

variable "custom_domain_name" {
  type        = string
  description = "The full custom hostname for the Drupal site (e.g., drupal.example.com)."
  default     = "drupal.az.trelvik.net"
}