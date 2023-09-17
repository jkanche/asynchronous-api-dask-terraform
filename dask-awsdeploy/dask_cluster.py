import os
import time

from dask_cloudprovider.aws import FargateCluster

__author__ = "jkanche"
__copyright__ = "jkanche"
__license__ = "MIT"

# try volume
# volume = {"containerPath": "/files", "sourceVolume": "dask_volume"}


cluster = FargateCluster(
    vpc=os.getenv("VPC_ID"),
    region_name="us-west-2",
    subnets=os.getenv("SUBNETS").split(","),
    security_groups=[os.getenv("SECURITY_GROUPS")],
    image=os.getenv("DASK_IMAGE"),
    n_workers=1,
    cluster_arn=os.getenv("FARGATE_CLUSTER_ARN"),
    ## if you need to add volumes ##
    # mount_points=[volume],
    # volumes=[
    #     {
    #         "name": "dask_volume",
    #         "efsVolumeConfiguration": {
    #             "fileSystemId": os.getenv("FILE_SYSTEM_ID"),
    #             "transitEncryption": "ENABLED",
    #         },
    #     }
    # ],
    fargate_use_private_ip=True,
    scheduler_address=os.getenv("SCHEDULER_ADDRESS"),
    environment={
        "FILES_PATH": os.getenv("FILES_PATH"),
        "REDIS_DOMAIN": os.getenv("REDIS_DOMAIN"),
        "REDIS_PASSWORD": os.getenv("REDIS_PASSWORD"),
    },
    cloudwatch_logs_group=os.getenv("WORKER_LOG_GROUP"),
    worker_task_definition_arn=os.getenv("WORKER_TASK_DEF"),
)

cluster.adapt(minimum=1, maximum=int(os.getenv("DASK_MAX_WORKERS")))

print(f"Cluster Initialized {cluster}.")

# So that the deployer is always running
# in the background!
while True:
    time.sleep(1)
