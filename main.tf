# -----------------------------------------
# PROVIDER: AWS
# -----------------------------------------
provider "aws" {
  region = "us-east-1"  # AWS region
}

# -----------------------------------------
# IAM ROLE for EC2 to pull Docker images from ECR
# -----------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach ECR read-only policy to IAM role
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------------------
# SECURITY GROUP for EC2 (SSH + App Port)
# -----------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "devops-ec2-sg"
  description = "Allow SSH and app port 3000"

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow App Port 3000
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------
# EC2 INSTANCE
# -----------------------------------------
resource "aws_instance" "app_server" {
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2 (us-east-1)
  instance_type          = "t2.micro"
  key_name               = "your-key-name"          # Replace with your EC2 key pair
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # USER DATA: Install Docker + AWS CLI automatically
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              yum install aws-cli -y
              EOF

  tags = {
    Name = "DevOps-App-EC2"
  }
}

# -----------------------------------------
# OUTPUT PUBLIC IP
# -----------------------------------------
output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}
