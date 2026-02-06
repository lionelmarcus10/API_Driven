
## Setup

### Alias

```bash
# Get url of forward port
csurl(){ echo "https://${CODESPACE_NAME}-$1.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; }

# usage
csurl 4566 => gives link of 4566

# run aws command for localstack 
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
AWS_PAGER=""

awslocal="aws --endpoint-url=http://localhost:4566 --region=us-east-1"

awsonline="aws --endpoint-url=$(csurl 4566) --region=us-east-1"
```

### Install local stack and aws

```bash
# install localstack
sudo -i mkdir rep_localstack
sudo -i python3 -m venv ./rep_localstack
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0

# install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm awscliv2.zip
rm -rf aws
```
### Start local stack
```bash
# Start localstack service
localstack start -d
# Get the status
localstack status services
```

### Get port 4566 url
```bash
csurl 4566
```

## EC2

### Create an ec2 instance

```bash
awslocal ec2 run-instances \
    --image-id ami-12345678 \
    --count 1 \
    --instance-type t2.micro \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=instance_one_name}]'
```

### List EC2 instances
```bash
awsonline ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId, Name:Tags[?Key==`Name`].Value|[0], PrivateIP:PrivateIpAddress, PublicIP:PublicIpAddress, Type:InstanceType}' --output table
```

## Deploy lambda and api gateway

```bash
chmod +x deploy_lambda_and_gateway.sh
```