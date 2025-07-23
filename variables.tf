variable "workload_name" {
  type        = string
  description = "The name of the workload or application."
  default     = "drupal"
}

variable "environment" {
  type        = string
  description = "The deployment environment name (e.g., prod, dev)."
  default     = "prod"
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed."
  default     = "East US"
}

variable "db_admin_username" {
  type        = string
  description = "The administrator username for the PostgreSQL server."
  default     = "drupaladmin"
}

variable "custom_domain_name" {
  type        = string
  description = "The custom domain name for the app."
  default     = "drupal.az.trelvik.net"
}

variable "dns_zone_name" {
  type        = string
  description = "The name of the existing Azure DNS Zone."
  default     = "az.trelvik.net"
}

variable "dns_resource_group_name" {
  type        = string
  description = "The name of the resource group containing the DNS Zone."
  default     = "rgDNS"
}