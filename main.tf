provider "aws" {
  region = var.region
}

# ----------------------------------------------------------
# SNS Topic + Email Subscription
# ----------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "asg-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ----------------------------------------------------------
# IAM Role for EC2
# ----------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name               = "asg-ec2-role"
  assume_role_policy = file("${path.module}/policies/ec2-assume-policy.json")
}

resource "aws_iam_role_policy" "ec2_policy" {
  name   = "asg-ec2-policy"
  role   = aws_iam_role.ec2_role.id
  policy = file("${path.module}/policies/ec2-cloudwatch-sns-policy.json")
}

resource "aws_iam_instance_profile" "profile" {
  name = "asg-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ----------------------------------------------------------
# CloudWatch Agent Config
# ----------------------------------------------------------
locals {
  cw_agent_config = jsonencode({
    metrics = {
      namespace = "CWAgent"
      metrics_collected = {
        mem = {
          measurement = ["mem_used_percent"]
        }
      }
    }
  })
}

# ----------------------------------------------------------
# Launch Template
# ----------------------------------------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "asg-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
set -e

yum update -y
yum install -y amazon-cloudwatch-agent python3

# ---------------------------
# Install Flask API
# ---------------------------
pip3 install flask

cat << 'APP' > /home/ec2-user/app.py
from flask import Flask
app = Flask(__name__)

@app.route("/test")
def test():
    return "OK", 200

@app.route("/heavy")
def heavy():
    x = 0
    for i in range(50000000):
        x += i
    return "CPU spike completed", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
APP

nohup python3 /home/ec2-user/app.py &

# ---------------------------
# CloudWatch Agent Config
# ---------------------------
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWCFG
${local.cw_agent_config}
CWCFG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

EOF
  )
}

# ----------------------------------------------------------
# Default VPC & Subnets
# ----------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ----------------------------------------------------------
# Auto Scaling Group
# ----------------------------------------------------------
resource "aws_autoscaling_group" "asg" {
  name             = "asg-example"
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  vpc_zone_identifier = data.aws_subnets.default.ids

  tag {
    key                 = "Name"
    value               = "asg-instance"
    propagate_at_launch = true
  }
}

# ----------------------------------------------------------
# CPU Scaling Policy
# ----------------------------------------------------------
resource "aws_autoscaling_policy" "cpu_scale_out" {
  name                   = "cpu-scale-out"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 30
  }
}

# Memory scale-out policy
resource "aws_autoscaling_policy" "memory_scale_out" {
  name                   = "memory-scale-out"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# ----------------------------------------------------------
# Memory Alarm
# ----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "ASGMemoryHigh"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [
    aws_autoscaling_policy.memory_scale_out.arn
  ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# ----------------------------------------------------------
# EC2 Status Alarm
# ----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ec2_failure" {
  alarm_name          = "EC2FailureAlarm"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}

# ----------------------------------------------------------
# S3 Bucket for CICD Artifacts
# ----------------------------------------------------------
resource "aws_s3_bucket" "cicd_artifacts" {
  bucket = "my-app-artifacts-bucket111111"
  
  
}

# ----------------------------------------------------------
# CodeDeploy Application
# ----------------------------------------------------------
resource "aws_codedeploy_app" "app" {
  name = "MyApp"
}

# ----------------------------------------------------------
# CodeDeploy IAM Role
# ----------------------------------------------------------
resource "aws_iam_role" "codedeploy_role" {
  name = "CodeDeployServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codedeploy_policy" {
  name = "CodeDeployRolePolicy"
  role = aws_iam_role.codedeploy_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:*",
          "ec2:*",
          "tag:GetTags",
          "tag:GetResources",
          "s3:Get*",
          "s3:List*",
          "cloudwatch:*",
          "sns:*",
          "lambda:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# ----------------------------------------------------------
# CodeDeploy Deployment Group
# ----------------------------------------------------------
resource "aws_codedeploy_deployment_group" "dg" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "MyApp-DeploymentGroup"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  autoscaling_groups = [
    aws_autoscaling_group.asg.name
  ]
}


# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "artifact_bucket" {
  value = aws_s3_bucket.cicd_artifacts.bucket
}

output "codedeploy_app" {
  value = aws_codedeploy_app.app.name
}

output "codedeploy_group" {
  value = aws_codedeploy_deployment_group.dg.deployment_group_name
}

