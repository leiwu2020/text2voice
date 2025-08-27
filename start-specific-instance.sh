#!/bin/bash

# Start Specific EC2 Instance
# This script starts a specific EC2 instance by its ID

set -e

# Configuration
INSTANCE_ID="i-0283f614f534b0f3f"

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i, --id       Specify instance ID (default: $INSTANCE_ID)"
    echo ""
    echo "This script starts a specific EC2 instance by its ID"
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
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

# Function to check instance status
check_instance_status() {
    local instance_id=$1
    
    local status
    status=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Instance $instance_id not found"
        exit 1
    fi
    
    echo "$status"
}

# Function to start instance
start_instance() {
    local instance_id=$1
    
    echo "Starting EC2 instance $instance_id..."
    
    aws ec2 start-instances --instance-ids "$instance_id"
    
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
    local instance_id="$INSTANCE_ID"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--id)
                instance_id="$2"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "Starting Specific EC2 Instance"
    echo ""
    
    check_prerequisites
    
    echo "Target Instance ID: $instance_id"
    echo ""
    
    # Check current instance status
    local current_status
    current_status=$(check_instance_status "$instance_id")
    echo "Current instance status: $current_status"
    
    if [[ "$current_status" == "running" ]]; then
        echo "Instance is already running!"
        echo ""
        echo "Instance Details:"
        get_instance_details "$instance_id"
        exit 0
    elif [[ "$current_status" == "stopped" ]]; then
        echo "Instance is stopped. Starting it now..."
        echo ""
        
        start_instance "$instance_id"
        
        echo ""
        echo "Instance started successfully!"
        echo ""
        echo "Instance Details:"
        get_instance_details "$instance_id"
        
        echo ""
        echo "Next Steps:"
        echo "   1. Wait a few minutes for the instance to fully start"
        echo "   2. Deploy the ECR image: ./deploy-ecr-to-ec2.sh <PUBLIC_IP>"
        echo "   3. Test the web interface at http://<PUBLIC_IP>:5000"
        echo "   4. Stop the instance when not in use: ./stop-ec2.sh"
        
    elif [[ "$current_status" == "stopping" ]]; then
        echo "Instance is currently stopping. Please wait for it to stop completely before starting."
        exit 1
        
    elif [[ "$current_status" == "terminated" ]]; then
        echo "Instance has been terminated and cannot be started."
        echo "You need to create a new instance using: ./start-ec2.sh"
        exit 1
        
    else
        echo "Instance is in an unexpected state: $current_status"
        exit 1
    fi
}

# Run main function
main "$@"
