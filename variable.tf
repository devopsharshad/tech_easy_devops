variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  default     = "default"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "stage" {
  description = "Deployment stage (dev/prod)"
  type        = string
}

variable "key_name" {
  description = "Existing AWS key pair name"
  default = "terraform"
}

variable "app_port" {
  description = "App port to check"
  default     = 80
}
