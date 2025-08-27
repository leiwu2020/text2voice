#!/bin/bash

# Stop EC2 Server for Text2Voice
# This script stops the text2voice EC2 instance

set -e

# Configuration
INSTANCE_NAME="text2voice"

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Force stop without confirmation"
    echo "  -s, --status   Show instance status only"
    echo "  -t, --terminate Terminate instance completely (deletes it)"
    echo ""
    echo "This script stops the text2voice EC2 instance"
}

# Function to get instance ID by name
get_instance_id() {
    local instance_name=$1
    
    local instance_id
    instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running,stopping,stopped" \
        --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)
    
    if [[ "$instance_id" == "None" ]] || [[ -z "$instance_id" ]]; then
        echo ""
        return 1
    fi
    
    echo "$instance_id"
}

# Function to get instance details
get_instance_details() {
    local instance_id=$1
    
    aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIP:PublicIpAddress,InstanceType:InstanceType,LaunchTime:LaunchTime}' \
        --output table
}

# Function to stop instance
stop_instance() {
    local instance_id=$1
    local force=$2
    
    echo "Stopping EC2 instance $instance_id..."
    
    if [[ "$force" != "true" ]]; then
        echo ""
        echo "WARNING: This will stop the text2voice instance."
        echo "   - The web application will become unavailable"
        echo "   - You can restart it later using the start script"
        echo "   - This helps reduce AWS costs when not in use"
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            exit 0
        fi
    fi
    
    aws ec2 stop-instances --instance-ids "$instance_id"
    
    echo "Waiting for instance to stop..."
    aws ec2 wait instance-stopped --instance-ids "$instance_id"
    
    echo "Instance $instance_id has been stopped successfully!"
    
    # Show updated status
    echo ""
    echo "Current instance status:"
    get_instance_details "$instance_id"
}

# Function to terminate instance
terminate_instance() {
    local instance_id=$1
    local force=$2
    
    echo "Terminating EC2 instance $instance_id..."
    
    if [[ "$force" != "true" ]]; then
        echo ""
        echo "WARNING: This will PERMANENTLY DELETE the instance!"
        echo "   - All data will be lost"
        echo "   - The instance cannot be recovered"
        echo "   - You'll need to create a new instance to run the app again"
        echo ""
        read -p "Are you absolutely sure? Type 'DELETE' to confirm: " -r
        if [[ "$REPLY" != "DELETE" ]]; then
            echo "Operation cancelled"
            exit 0
        fi
    fi
    
    aws ec2 terminate-instances --instance-ids "$instance_id"
    
    echo "Waiting for instance to terminate..."
    aws ec2 wait instance-terminated --instance-ids "$instance_id"
    
    echo "Instance $instance_id has been terminated successfully!"
}

# Function to show instance status
show_status() {
    local instance_id=$1
    
    echo ""
    echo "Instance Details:"
    get_instance_details "$instance_id"
    
    echo ""
    echo "Cost Information:"
    echo "   - Instance Type: t3.medium"
    echo "   - Estimated cost: ~$0.0416/hour when running"
    echo "   - Cost when stopped: ~$0.00/hour (only storage costs apply)"
    echo ""
    echo "Remember to terminate the instance completely when you're done to avoid storage costs!"
}

# Main execution
main() {
    local force=false
    local status_only=false
    local terminate=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -s|--status)
                status_only=true
                shift
                ;;
            -t|--terminate)
                terminate=true
                shift
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "Stopping Text2Voice EC2 Instance"
    echo ""
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo "ERROR: AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "ERROR: AWS CLI is not configured"
        exit 1
    fi
    
    # Get instance ID
    echo "Looking for instance with name: $INSTANCE_NAME"
    local instance_id
    instance_id=$(get_instance_id "$INSTANCE_NAME")
    
    if [[ -z "$instance_id" ]]; then
        echo "WARNING: No running text2voice instance found"
        echo ""
        echo "Available instances with 'text2voice' in the name:"
        aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=*text2voice*" \
            --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
            --output table 2>/dev/null || echo "No instances found"
        exit 1
    fi
    
    echo "Found instance: $instance_id"
    
    if [[ "$status_only" == "true" ]]; then
        show_status "$instance_id"
        exit 0
    fi
    
    # Perform the requested action
    if [[ "$terminate" == "true" ]]; then
        terminate_instance "$instance_id" "$force"
        echo ""
        echo "Instance terminated successfully!"
        echo ""
        echo "To start a new instance, run: ./start-ec2.sh"
    else
        stop_instance "$instance_id" "$force"
        echo ""
        echo "Instance stopped successfully!"
        echo ""
        echo "To restart the instance later:"
        echo "   1. Run: ./start-ec2.sh"
        echo "   2. Then run: ./deploy-ecr-to-ec2.sh <NEW_PUBLIC_IP>"
        echo ""
        echo "To completely terminate the instance (saves storage costs):"
        echo "   $0 --terminate"
    fi
}

# Run main function
main "$@"
