output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
output "asg_name" { value = aws_autoscaling_group.asg.name }
