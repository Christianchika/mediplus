variable "region" {
  default = "eu-north-1"
}

variable "ami" {
  default = "ami-0fa91bc90632c73c9" # Canonical, Ubuntu, 24.04 (eu-north-1)
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  default = "stagging-key"
}

variable "private_key_path" {
  type        = string
  description = "Path to your SSH private key file"
  default     = "C:\\Users\\user\\Downloads\\stagging-key (1).pem"
}

variable "private_key" {
  type      = string
  sensitive = true
  # Provide via TF_VAR_private_key or *.tfvars, not checked into VCS
}

variable "domain_name" {
  default = "mypodsix.online"
}

variable "email" {
  default = "okoro.christianpeace@gmail.com"
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR allowed for SSH (port 22). Set to your_ip/32."
  default     = "0.0.0.0/0"
}

