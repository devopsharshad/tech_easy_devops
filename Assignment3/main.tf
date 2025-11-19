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
  assume_role_policy = file("policies/ec2-assume-policy.json")
}

resource "aws_iam_role_policy" "ec2_policy" {
  name   = "asg-ec2-policy"
  role   = aws_iam_role.ec2_role.id
  policy = file("policies/ec2-cloudwatch-sns-policy.json")
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
yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<CWCFG
${local.cw_agent_config}
CWCFG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

EOF
  )
}

# ----------------------------------------------------------
# VPC & Subnets (default)
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
# CPU Scaling Policy (>30%)
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

# ----------------------------------------------------------
# Memory Alarm (>5%) — Scale Out
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

  alarm_actions = [aws_autoscaling_policy.cpu_scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# ----------------------------------------------------------
# EC2 Failure Alarm → SNS Email
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
