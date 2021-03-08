
provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# 1. Create VPC

resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "wp-vpc"
  }
}

# 2. Create public and private subnets

resource "aws_subnet" "wp_public_sn" {
  vpc_id = aws_vpc.wp_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.availability_zone
}

resource "aws_subnet" "wp_private_sn" {
  vpc_id = aws_vpc.wp_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = var.availability_zone
}

# 3. Create internet gateway for VPC

resource "aws_internet_gateway" "wp_gw" {
  vpc_id = aws_vpc.wp_vpc.id
}

# 4. Create Public and Private Route Tables

resource "aws_route_table" "wp_public_rt" {
  vpc_id = aws_vpc.wp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wp_gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.wp_gw.id
  }

  tags = {
    Name = "wp-gw"
  }
}

# 5. Create Route Table Association

resource "aws_route_table_association" "wp_rta" {
  subnet_id = aws_subnet.wp_public_sn.id
  route_table_id = aws_route_table.wp_public_rt.id
}

# 6. Create Security Group

resource "aws_security_group" "wp_sg" {
    name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ips 
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a Network Interface for Public Subnet

resource "aws_network_interface" "wp_public_nic" {
  subnet_id = aws_subnet.wp_public_sn.id
  private_ips = ["10.0.1.5"]
  security_groups = [aws_security_group.wp_sg.id]
}

# 8. Assign Elastic ip

resource "aws_eip" "wp_public_eip" {
  vpc = "true"
  network_interface = aws_network_interface.wp_public_nic.id
  associate_with_private_ip = "10.0.1.5"
  depends_on = [aws_internet_gateway.wp_gw]
}

output "server_public_ip" {
  value = aws_eip.wp_public_eip.public_ip
}

# 9. EC2 instance

resource "aws_instance" "wp_ec2" {
  ami = "ami-096cb92bb3580c759"
  instance_type = var.instance_type
  availability_zone = var.availability_zone
  key_name = var.key_name

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.wp_public_nic.id
  }
  # Install docker and configure wp webserver and mariadb 
  user_data = <<-EOF
    #!/bin/bash
    #
    # 1. Install docker
    # 
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install apt-transport-https ca-certificates curl gnupg -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y
    sudo apt install docker-ce docker-ce-cli containerd.io -y
    #
    # 2. Spin-Up Mariadb Container
    #
    mkdir -p ~/worpress/database
    mkdir -p ~/wordpress/html
    sudo docker run -e MYSQL_ROOT_PASSWORD=password -e MYSQL_USER=wpuser -e MYSQL_PASSWORD=password -e MYSQL_DATABASE=wpdb -v /home/ubuntu/wordpress/database:/var/lib/mysql --name wordpressdb -d mariadb
    #
    # 3. Spin-Up Wordpress Image
    #
    sudo docker run -e WORDPRESS_DB_USER=wpuser -e WORDPRESS_DB_PASSWORD=password -e WORDPRESS_DB_NAME=wpdb -p 80:80 -v /home/ubuntu/wordpress/html:/var/www/html --link wordpressdb:mysql --name wpcontainer -d wordpress
    EOF

  tags = {
    Name = "wp-ec2"
  }
}


