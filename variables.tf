// Configuring the provider information
provider "aws" {
    region = "us-west-2"
}

// Creating the EC2 private key
variable "key_name" {
  type    = string
  default = "vockey"
}

variable "ami" {
  description = "ID of AMI to use for the instance"
  type        = string
  default     = "ami-0d593311db5abb72b"
}

variable "instance_type" {
  description = "The type of instance to start"
  type        = string
  default     = "t3.micro"
}
