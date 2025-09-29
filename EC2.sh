#!/bin/bash

: '
This script automates the creation of an AWS EC2 instance with:
- A custom security group allowing SSH (22), HTTP (80), and HTTPS (443)
- A key pair for SSH access
- Output of deployment details to a JSON file
-Alter the instance AMI and security group to suits your needs

'

set -e  

OUTPUT_FILE="ec2_deployment_info.json"
> "$OUTPUT_FILE" 

# ...rest of your script

set -e  

OUTPUT_FILE="ec2_deployment_info.json"
> "$OUTPUT_FILE" 

checks() {
    if [ $? -eq 0 ]; then 
        echo "✅ Success: $1"
    else
        echo "❌ Error: $1"
        exit 1
    fi
}

awsconfig() {
    # Create Security Group
    sg_id=$(aws ec2 create-security-group \
        --group-name "launch-wizard-150" \
        --description "launch-wizard-150 created $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --vpc-id "vpc-08beedc889dac362f" \
        --query 'GroupId' --output text)
    
    checks "Security group created"

    aws ec2 authorize-security-group-ingress \
    --group-id "$sg_id" \
    --ip-permissions '[
        {"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
        {"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
        {"IpProtocol":"tcp","FromPort":443,"ToPort":443,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]}
    ]'

    # Create Key Pair
    key_name="my-keypair-$(date +%s)"
    key_file="$key_name.pem"

    aws ec2 create-key-pair \
        --key-name "$key_name" \
        --query 'KeyMaterial' \
        --output text > "$key_file"
    chmod 400 "$key_file"
    checks "Key pair created and saved as $key_file"

    # Launch Instance
    instance_id=$(aws ec2 run-instances \
        --image-id "ami-046c2381f11878233" \
        --instance-type "t2.micro" \
        --key-name "$key_name" \
        --network-interfaces "[{\"AssociatePublicIpAddress\":true,\"DeviceIndex\":0,\"Groups\":[\"$sg_id\"]}]" \
        --count 1 \
        --query 'Instances[0].InstanceId' \
        --output text)

    checks "EC2 instance launched"

    echo "⏳ Waiting for instance to be in 'running' state..."
    aws ec2 wait instance-running --instance-ids "$instance_id"
    echo "Instance is running ✅"

    # Get Public IP
    public_ip=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    # Save everything to JSON
    cat <<EOF > "$OUTPUT_FILE"
    {
    "security_group_id": "$sg_id",
    "key_pair_name": "$key_name",
    "key_file": "$key_file",
    "instance_id": "$instance_id",
    "public_ip": "$public_ip",
    "ssh_command": "ssh -i $key_file ec2-user@$public_ip"
    }
    EOF

        echo "✅ Deployment info saved in $OUTPUT_FILE"
}

awsconfig