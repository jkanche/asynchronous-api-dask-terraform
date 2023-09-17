import boto3
import os
import datetime


def lambda_handler(event, context):
    client = boto3.client('ecs')
    ecs_cluster = os.environ['ecs_cluster']
    ecs_service = os.environ['ecs_service']

    response = client.list_tasks(cluster=ecs_cluster, serviceName=ecs_service)

    if not response.get('taskArns'):
        print(f"No running tasks found for service {ecs_service} in cluster {ecs_cluster}.")
        return

    task_arn = response['taskArns'][0]  # take the first task in the service
    task_response = client.describe_tasks(cluster=ecs_cluster, tasks=[task_arn])
    task = task_response['tasks'][0]

    if task['startedAt']:
        task_duration = (datetime.datetime.now(datetime.timezone.utc) - task['startedAt']).total_seconds() / 60 / 60
        expected_duration = 72
        if task_duration >= expected_duration:
            print(f"Task {task_arn} running for more than {expected_duration} hours ({task_duration} hrs), restarting the service...")
            client.update_service(cluster=ecs_cluster, service=ecs_service, forceNewDeployment=True)
            print(f"Service {ecs_service} updated to force a new deployment.")
        else:
            print(f"Task {task_arn} running for less than {expected_duration} hours ({task_duration} hrs), skipping restart.")
    else:
        print(f"Task {task_arn} has not started yet.")
