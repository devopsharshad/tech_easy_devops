import boto3
import os
import json
from datetime import datetime, timedelta


cw = boto3.client('cloudwatch')
sns = boto3.client('sns')


SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')


def lambda_handler(event, context):
# compute metrics for previous day
end = datetime.utcnow().replace(hour=0,minute=0,second=0,microsecond=0)
start = end - timedelta(days=1)


# example: get average CPU across the ASG (namespace AWS/EC2 per-instance) - change as needed
resp = cw.get_metric_statistics(Namespace='AWS/EC2', MetricName='CPUUtilization', StartTime=start, EndTime=end, Period=86400, Statistics=['Average'])
avg_cpu = resp.get('Datapoints', [{}])[0].get('Average', 0)


message = f"Daily
