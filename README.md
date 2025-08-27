# Text2Voice Web Application

A Flask-based web application that converts text to speech using espeak and ffmpeg.

## 🚀 Quick Start

### Prerequisites
- Docker installed and running
- AWS CLI configured with appropriate permissions
- SSH key pair for EC2 access

### 1. Build and Push Docker Image to ECR
```bash
./build-and-push-ecr.sh
```

This script:
- Builds the Docker image for AMD64 architecture
- Creates ECR repository if it doesn't exist
- Pushes the image to AWS ECR

**Options:**
- `-h, --help` - Show help message
- `-t, --tag` - Specify image tag (default: latest)

### 2. Start EC2 Server
```bash
./start-ec2.sh
```

This script:
- Launches a t3.medium EC2 instance in a public subnet
- Creates security group with SSH (port 22) and Flask app (port 5000) access
- Tags the instance for easy identification

**Options:**
- `-h, --help` - Show help message
- `-t, --type` - Specify instance type (default: t3.medium)

### 3. Deploy ECR Image to EC2
```bash
./deploy-ecr-to-ec2.sh <EC2_PUBLIC_IP>
```

This script:
- Installs Docker and AWS CLI on the EC2 instance
- Sets up the text2voice application directory
- Pulls and runs the Docker image from ECR
- Creates a systemd service for auto-start

**Example:**
```bash
./deploy-ecr-to-ec2.sh 35.86.71.130
```

### 4. Stop EC2 Server
```bash
./stop-ec2.sh
```

This script:
- Stops the running text2voice EC2 instance
- Preserves instance data for later restart
- Reduces AWS costs when not in use

**Options:**
- `-h, --help` - Show help message
- `-f, --force` - Force stop without confirmation
- `-s, --status` - Show instance status only
- `-t, --terminate` - Terminate instance completely (deletes it)

## 📋 Complete Workflow

1. **Build and Push to ECR:**
   ```bash
   ./build-and-push-ecr.sh
   ```

2. **Start EC2 Instance:**
   ```bash
   ./start-ec2.sh
   ```

3. **Deploy Application:**
   ```bash
   ./deploy-ecr-to-ec2.sh <PUBLIC_IP>
   ```

4. **Access Application:**
   - Web Interface: http://<PUBLIC_IP>:5000
   - SSH Access: `ssh -i /path/to/key.pem ec2-user@<PUBLIC_IP>`

5. **Stop When Done:**
   ```bash
   ./stop-ec2.sh
   ```

## 🔧 Configuration

### Key Pair Path
Update the `KEY_PAIR_NAME` variable in the scripts to match your SSH key location:
```bash
KEY_PAIR_NAME="/path/to/your/key.pem"
```

### AWS Region
The scripts are configured for `us-west-2` (Oregon). Update `AMI_ID` in `start-ec2.sh` if using a different region.

### ECR Repository
The ECR repository name is set to `text2voice-demo`. Update `ECR_REPO_NAME` in `build-and-push-ecr.sh` if needed.

## 💰 Cost Management

- **Running Instance**: ~$0.0416/hour
- **Stopped Instance**: ~$0.00/hour (only storage costs)
- **Monthly Savings**: ~$30 when stopped

## 🗑️ Cleanup

To completely remove the instance and avoid storage costs:
```bash
./stop-ec2.sh --terminate
```

## 📁 Project Structure

```
text2voice/
├── build-and-push-ecr.sh    # Build and push Docker image to ECR
├── start-ec2.sh             # Launch EC2 instance
├── deploy-ecr-to-ec2.sh     # Deploy ECR image to EC2
├── stop-ec2.sh              # Stop/terminate EC2 instance
├── Dockerfile                # Docker image definition
├── app-docker.py            # Flask application for Docker
├── requirements-docker.txt   # Python dependencies for Docker
├── templates/                # HTML templates
├── uploads/                  # File upload directory
└── outputs/                  # Generated audio files
```

## 🆘 Troubleshooting

### Common Issues

1. **Docker not running:**
   ```bash
   open -a Docker
   ```

2. **AWS CLI not configured:**
   ```bash
   aws configure
   ```

3. **Permission denied on scripts:**
   ```bash
   chmod +x *.sh
   ```

4. **Instance not accessible:**
   - Check security group rules
   - Verify instance is in public subnet
   - Wait for instance status checks to pass

### Getting Help

Each script includes help information:
```bash
./script-name.sh --help
```

## 📚 Additional Resources

- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Docker Documentation](https://docs.docker.com/)
