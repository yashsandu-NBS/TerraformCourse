# Source Code: https://github.com/Sanjeev-Thiyagarajan/Terraform-Crash-Course/blob/master/main.tf 
# Tutorial:    https://www.youtube.com/watch?v=SLB_c_ayRMo

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
  access_key = ""
  secret_key = ""
}



# Personal Project
# 1. Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 3. Create Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# 4. Create a Subnet
variable "subnet_prefix" {
    description = "Subnet cidr block"
    # default =
    # type = 
    //Default - When user does not specify input value
    //Type - value of the variable e.g. String, numbers, lists, maps, boolean etc. 
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "eu-west-2a"
  tags = {
    Name = "prod_subnet"
  }
}

# 5. Associate subnet with routing Table created in step 3
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create security group to allow port 22 / 80 / 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# 9. Create ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
    ami = "ami-0194c3e07668a7e36"
    instance_type = "t2.micro"
    availability_zone = "eu-west-2a"
    key_name = "main-key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo Your very FIRST Web Server > /var/www/html/index.html'
                EOF

    tags = {
        Name = "web-server"
    }
}

# Output information on current state
output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# Example Format
# resource "<provider>_<resource_type>" "name" {
#     config options...
#     key = "value"
#     key2 = "another value"
# }

# ssh -i "main-key.cer" ubuntu@18.168.87.100
# curl -L http://localhost/index.html