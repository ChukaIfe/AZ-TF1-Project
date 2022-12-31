variable "resource_group_name" {
  default = "devTFResourceGroup"
}

variable "location_name" {
  default = "eastus"
}

variable "address_space_name" {
  default = ["10.0.0.0/16"]
}

variable "host_os" {
  type    = string
  default = "linux"

}