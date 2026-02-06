import json
import subprocess

def lambda_handler(event, context):
    """
    event['path'] gives the API route: /start, /stop, /status
    """
    path = event.get("path", "/status")
    action = path.lstrip("/")  # remove leading slash

    AWS_CLI_BASE = [
        "aws",
        "--endpoint-url=https://shiny-space-lamp-gwjjqqgwg9ghxgp-4566.app.github.dev",
        "--region=us-east-1",
        "--no-cli-pager"
    ]

    # Function to get instance info
    def get_instances():
        cmd = AWS_CLI_BASE + [
            "ec2", "describe-instances",
            "--query",
            "Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Type:InstanceType,State:State.Name}",
            "--output", "json"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return json.loads(result.stdout)

    # Execute start/stop if requested
    if action in ["start", "stop"]:
        instances = get_instances()
        instance_ids = [inst['ID'] for inst in instances]
        if instance_ids:
            cmd_action = AWS_CLI_BASE + [
                "ec2", f"{action}-instances",
                "--instance-ids"
            ] + instance_ids
            subprocess.run(cmd_action)
        message = f"{action} executed on instances: {instance_ids}"
    else:
        message = "status fetched"

    # Always return the table of instances
    return {
        "message": message,
        "instances": get_instances()
    }
