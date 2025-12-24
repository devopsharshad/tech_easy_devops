# ------------------------------
# Provider Configuration
# ------------------------------
provider "aws" {
  region = "ap-south-1"
}

# ------------------------------
# Variables
# ------------------------------
variable "app_bucket" {
  default = "techeazytesting" # Existing bucket with your JAR
}

variable "logs_bucket" {
  default = "techeazytesting-logs2"
}

variable "ami_id" {
  default = "ami-03695d52f0d883f65" # AMI ID provided
}

# ------------------------------
# S3 Bucket for Logs
# ------------------------------
resource "aws_s3_bucket" "logs" {
  bucket = var.logs_bucket
}

# ------------------------------
# IAM Role & Policy for EC2
# ------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_rw" {
  name = "ec2_s3_rw_policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${var.app_bucket}/*"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject"],
        Resource = "arn:aws:s3:::${aws_s3_bucket.logs.bucket}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

# ------------------------------
# EC2 Instances (3)
# ------------------------------
resource "aws_instance" "app" {
  count                       = 3
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  subnet_id                   = element(["subnet-09aa7de557e11448c", "subnet-0d264c91f007d07f1"], count.index % 2)
  vpc_security_group_ids      = [] # You can add your SG IDs here if needed

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y aws-cli java-17-amazon-corretto
    cd /home/ec2-user
    aws s3 cp s3://${var.app_bucket}/hellomvc-0.0.1-SNAPSHOT.jar app.jar
    nohup java -jar app.jar --server.port=80 > app.log 2>&1 &
    aws s3 cp app.log s3://${aws_s3_bucket.logs.bucket}/$(hostname)-app.log
  EOF

  tags = {
    Name = "techeazy-app-${count.index}"
  }
}

# ------------------------------
# Load Balancer (ALB)
# ------------------------------
resource "aws_lb" "app_alb" {
  name               = "techeazy-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = ["subnet-09aa7de557e11448c", "subnet-0d264c91f007d07f1"]
}

# ------------------------------
# Target Group & Listener
# ------------------------------
resource "aws_lb_target_group" "app_tg" {
  name     = "techeazy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-059e2ac47d33636b5"

  health_check {
    path                = "/"
    port                = "80"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-499"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ------------------------------
# Target Group Attachments
# ------------------------------
resource "aws_lb_target_group_attachment" "attach" {
  count            = 3
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

# ------------------------------
# Outputs
# ------------------------------
output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}
