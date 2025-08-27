#!/bin/bash

# Start EC2 Server for Text2Voice
# This script launches an EC2 instance to host the text2voice application

set -e

# Configuration
KEY_PAIR_NAME="/Users/250006761/lei-key.pem"
INSTANCE_TYPE="t3.medium"
AMI_ID="ami-0095b2d932ba790f3" # Amazon Linux 2023 for us-west-2
ECR_URI="517569678285.dkr.ecr.us-east-1.amazonaws.com/text2voice-demo"

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --type     Specify instance type (default: t3.medium)"
    echo ""
    echo "This script launches an EC2 instance for the text2voice application"
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if [[ ! -f "$KEY_PAIR_NAME" ]]; then
        echo "ERROR: Key pair file not found: $KEY_PAIR_NAME"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo "ERROR: AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "ERROR: AWS CLI is not configured"
        exit 1
    fi
    
    echo "Prerequisites check passed"
}

# Function to get current public IP
get_public_ip() {
    curl -s ifconfig.me
}

# Function to create or get security group
create_security_group() {
    echo "Checking for existing security group..."
    
    local existing_sg
    existing_sg=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=text2voice-sg" \
        --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
    
    if [[ "$existing_sg" != "None" ]] && [[ -n "$existing_sg" ]]; then
        echo "Using existing security group: $existing_sg"
        echo "$existing_sg"
    else
        echo "Creating new security group..."
        local sg_id
        sg_id=$(aws ec2 create-security-group \
            --group-name "text2voice-sg" \
            --description "Security group for text2voice application" \
            --query 'GroupId' --output text)
        
        echo "Security group created: $sg_id"
        echo "$sg_id"
    fi
}

# Function to configure security group rules
configure_security_group() {
    local sg_id=$1
    local my_ip=$2
    
    echo "Configuring security group rules..."
    
    # Add SSH rule (skip if already exists)
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 22 \
        --cidr "$my_ip/32" 2>/dev/null || echo "SSH rule already exists"
    
    # Add Flask app rule (skip if already exists)
    aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 5000 \
        --cidr "0.0.0.0/0" 2>/dev/null || echo "Flask app rule already exists"
    
    echo "Security group rules configured"
}

# Function to launch instance
launch_instance() {
    local sg_id=$1
    local instance_type=$2
    
    # Get default VPC and public subnet
    local vpc_id
    local subnet_id
    
    vpc_id=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    subnet_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=map-public-ip-on-launch,Values=true" --query 'Subnets[0].SubnetId' --output text)
    
    echo "Using VPC: $vpc_id, Subnet: $subnet_id" >&2
    
    local instance_id
    instance_id=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type "$instance_type" \
        --key-name "$(basename "$KEY_PAIR_NAME" .pem)" \
        --security-group-ids "$sg_id" \
        --subnet-id "$subnet_id" \
        --associate-public-ip-address \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=text2voice},{Key=Project,Value=text2voice}]" \
        --query 'Instances[0].InstanceId' --output text)
    
    echo "$instance_id"
}

# Function to wait for instance to be ready
wait_for_instance() {
    local instance_id=$1
    
    echo "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids "$instance_id"
    
    echo "Waiting for SSH to be ready..."
    sleep 30
    
    echo "Instance is ready!"
}

# Function to get instance details
get_instance_details() {
    local instance_id=$1
    
    aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIP:PublicIpAddress,InstanceType:InstanceType,EC2DNS:PublicDnsName}' \
        --output table
}

# Main execution
main() {
    local instance_type="$INSTANCE_TYPE"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--type)
                instance_type="$2"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "Starting EC2 Server for Text2Voice"
    echo ""
    
    check_prerequisites
    
    local my_ip
    my_ip=$(get_public_ip)
    echo "Your IP: $my_ip"
    echo ""
    
    # Create security group and capture only the ID
    echo "Setting up security group..."
    local sg_id
    sg_id=$(create_security_group | tail -n 1)
    echo "Security group ID: $sg_id"
    
    configure_security_group "$sg_id" "$my_ip"
    
    echo "Launching EC2 instance..."
    local instance_id
    instance_id=$(launch_instance "$sg_id" "$instance_type")
    echo "Instance launched: $instance_id"
    
    wait_for_instance "$instance_id"
    
    echo ""
    echo "EC2 instance launched successfully!"
    echo ""
    echo "Instance Details:"
    get_instance_details "$instance_id"
    
    echo ""
    echo "Next Steps:"
    echo "   1. Wait a few minutes for the instance to fully start"
    echo "   2. Deploy the ECR image: ./deploy-ecr-to-ec2.sh <PUBLIC_IP>"
    echo "   3. Test the web interface at http://<PUBLIC_IP>:5000"
    echo "   4. Stop the instance when not in use: ./stop-ec2.sh"
}

# Run main function
main "$@"
