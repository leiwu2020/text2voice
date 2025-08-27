#!/bin/bash

# Build Docker Image and Push to ECR
# This script builds the text2voice Docker image and pushes it to AWS ECR

set -e

# Configuration
IMAGE_NAME="text2voice"
ECR_REPO_NAME="text2voice-demo"
AWS_REGION="us-east-1"

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --tag      Specify image tag (default: latest)"
    echo ""
    echo "This script builds the text2voice Docker image and pushes it to ECR"
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker is not installed"
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

# Function to get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query 'Account' --output text
}

# Function to create ECR repository if it doesn't exist
create_ecr_repo() {
    local repo_name=$1
    local region=$2
    
    echo "Checking if ECR repository exists..."
    
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$region" &> /dev/null; then
        echo "ECR repository already exists"
    else
        echo "Creating ECR repository..."
        aws ecr create-repository \
            --repository-name "$repo_name" \
            --region "$region" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        
        echo "ECR repository created successfully"
    fi
}

# Function to get ECR login token
get_ecr_login() {
    local region=$1
    
    echo "Logging into ECR..."
    aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$(get_account_id).dkr.ecr.$region.amazonaws.com"
}

# Function to build and push image
build_and_push() {
    local tag=$1
    local account_id
    local ecr_uri
    
    account_id=$(get_account_id)
    ecr_uri="$account_id.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"
    
    echo "Building Docker image for AMD64 architecture..."
    docker buildx build --platform linux/amd64 -t "$IMAGE_NAME:$tag" .
    
    echo "Tagging image for ECR..."
    docker tag "$IMAGE_NAME:$tag" "$ecr_uri:$tag"
    
    echo "Pushing image to ECR..."
    docker push "$ecr_uri:$tag"
    
    echo "Image pushed successfully to ECR!"
    echo ""
    echo "ECR Repository URI: $ecr_uri"
    echo "Image Tag: $tag"
}

# Main execution
main() {
    local tag="latest"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--tag)
                tag="$2"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "Building and Pushing Docker Image to ECR"
    echo ""
    
    check_prerequisites
    
    echo "AWS Account ID: $(get_account_id)"
    echo "AWS Region: $AWS_REGION"
    echo "ECR Repository: $ECR_REPO_NAME"
    echo "Image Tag: $tag"
    echo ""
    
    create_ecr_repo "$ECR_REPO_NAME" "$AWS_REGION"
    get_ecr_login "$AWS_REGION"
    build_and_push "$tag"
    
    echo ""
    echo "Docker image successfully built and pushed to ECR!"
}

# Run main function
main "$@"
