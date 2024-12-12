variable "cluster_size" {
  description = "Number of servers for cluster"
  type        = number
}

variable "cluster_instance_name" {
  type        = string
  description = "A name of a cluster to create"
  #default     = "cluster"
}

variable "system_user" {
  type        = string
  description = "User to connect to VMs"
}

variable "iqn_base" {
  type = string
}
variable "vg_name" {
  type = string

}
variable "lv_name" {
  type = string
}
variable "fs_name" {
  type = string
}
