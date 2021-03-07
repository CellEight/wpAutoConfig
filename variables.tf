variable "access_key" {
  type = string
  description = "AWS Access Key"
}

variable "secret_key" {
  type = string
  description = "AWS Secret Key"
}

variable "region" {
  type = string
  description = "The AWS region that the site will be created in."
}

variable "availability_zone" {
  type = string
  description = "The specific AWS availabilty zone in the the region that the site will be lauched"
}

variable "admin_ips" {
  type = list
  description = "List of ips that will be allowed to ssh into the webserver"
}

variable "instance_type" {
  type = string
  description = "t2.micro"
}

variable "key_name" {
  type = string
  description = "Name of the private key used to SSH into the server"
}


