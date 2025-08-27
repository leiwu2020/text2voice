#!/bin/bash

# Deploy ECR Image to EC2 Server
# This script sets up an EC2 instance to run the text2voice image from ECR

set -e

# Configuration
KEY_PAIR_NAME="/Users/250006761/lei-key.pem"
ECR_URI="517569678285.dkr.ecr.us-east-1.amazonaws.com/text2voice-demo"
ECR_REGION="us-east-1"

# Function to show help
show_help() {
    echo "Usage: $0 <EC2_ADDRESS>"
    echo ""
    echo "This script sets up the EC2 instance to run the text2voice image from ECR"
    echo "EC2_ADDRESS can be either the public IP address or the EC2 DNS name"
    echo ""
    echo "Examples:"
    echo "  $0 35.86.71.130"
    echo "  $0 ec2-35-86-71-130.us-west-2.compute.amazonaws.com"
}

# Function to setup the instance
setup_instance() {
    local instance_address=$1
    
    echo "Setting up EC2 instance at $instance_address..."
    
    # Check if address is provided
    if [[ -z "$instance_address" ]]; then
        echo "ERROR: Please provide the EC2 public IP address or DNS name"
        show_help
        exit 1
    fi
    
    # Check if key file exists
    if [[ ! -f "$KEY_PAIR_NAME" ]]; then
        echo "ERROR: Key pair file not found: $KEY_PAIR_NAME"
        exit 1
    fi
    
    echo "Installing Docker and dependencies..."
    
    # SSH into the instance and run setup commands
    ssh -i "$KEY_PAIR_NAME" "ec2-user@$instance_address" << 'EOF'
        # Update system
        sudo yum update -y
        
        # Install Docker
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add ec2-user to docker group
        sudo usermod -a -G docker ec2-user
        
        # Install AWS CLI v2
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        
        # Create application directory
        sudo mkdir -p /opt/text2voice
        sudo chown ec2-user:ec2-user /opt/text2voice
        cd /opt/text2voice
        
        # Create startup script
        cat > start-app.sh << 'SCRIPT_EOF'
#!/bin/bash
cd /opt/text2voice

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 517569678285.dkr.ecr.us-east-1.amazonaws.com

# Pull latest image
docker pull 517569678285.dkr.ecr.us-east-1.amazonaws.com/text2voice-demo:latest

# Stop existing container if running
docker stop text2voice-app 2>/dev/null || true
docker rm text2voice-app 2>/dev/null || true

# Create necessary directories
mkdir -p uploads outputs
chown -R ec2-user:ec2-user uploads outputs

# Start new container
docker run -d \
    --name text2voice-app \
    --restart unless-stopped \
    -p 5000:5000 \
    -v /opt/text2voice/uploads:/app/uploads \
    -v /opt/text2voice/outputs:/app/outputs \
    -e FLASK_ENV=production \
    517569678285.dkr.ecr.us-east-1.amazonaws.com/text2voice-demo:latest

echo "Application started successfully!"
docker ps | grep text2voice-app
SCRIPT_EOF

        chmod +x start-app.sh
        
        # Create systemd service for auto-start
        sudo tee /etc/systemd/system/text2voice-ecr.service > /dev/null << 'SERVICE_EOF'
[Unit]
Description=Text2Voice ECR Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=ec2-user
WorkingDirectory=/opt/text2voice
ExecStart=/opt/text2voice/start-app.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

        # Enable the service
        sudo systemctl enable text2voice-ecr
        
        echo "Setup completed successfully!"
        echo "Starting the application..."
        
        # Start the application
        ./start-app.sh
EOF

    if [[ $? -eq 0 ]]; then
        echo "Instance setup completed successfully!"
        echo ""
        echo "Testing the application..."
        
        # Wait a bit for the application to start
        sleep 30
        
        # Test the application
        if curl -s --connect-timeout 10 "http://$instance_address:5000" >/dev/null; then
            echo "Web interface is accessible at http://$instance_address:5000"
        else
            echo "Web interface not responding yet (may still be starting)"
        fi
        
        echo ""
        echo "Useful Commands:"
        echo "   Check container status: ssh -i $KEY_PAIR_NAME ec2-user@$instance_address 'docker ps'"
        echo "   View logs: ssh -i $KEY_PAIR_NAME ec2-user@$instance_address 'docker logs text2voice-app'"
        echo "   Restart app: ssh -i $KEY_PAIR_NAME ec2-user@$instance_address 'cd /opt/text2voice && ./start-app.sh'"
        echo "   SSH access: ssh -i $KEY_PAIR_NAME ec2-user@$instance_address"
        
    else
        echo "ERROR: Instance setup failed"
        exit 1
    fi
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    local instance_address=$1
    
    echo "Setting up EC2 instance for ECR deployment..."
    echo ""
    
    setup_instance "$instance_address"
    
    echo ""
    echo "Setup completed! Your text2voice application should be running at http://$instance_address:5000"
}

# Run main function
main "$@"
