variable "region" {
  default = "ap-south-1"
}

variable "alert_email" {
  default = "gadekarharshad7776@gmail.com"
}

variable "ami_id" {
  default = "ami-03695d52f0d883f65"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "min_size" {
  default = 1
}

variable "max_size" {
  default = 4
}

variable "desired" {
  default = 1
}
