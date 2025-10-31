####################################
# Security Group
####################################
resource "aws_security_group" "allow_http" {
  name_prefix = "allow-http"

  ingress {
    description = "Allow HTTP"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

####################################
# EC2 Instance
####################################
resource "aws_instance" "app_server" {
  ami                    = "ami-01760eea5c574eb86" # Amazon Linux 2 (update if needed)
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  user_data              = file("setup.sh")

  tags = {
    Name  = "techEazy-${var.stage}"
    Stage = var.stage
  }
}

####################################
# Output
####################################
output "public_ip" {
  value = aws_instance.app_server.public_ip
}
