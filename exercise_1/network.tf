resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "venky_VPC"
    Demo = "Venky"
  }
}

resource "aws_subnet" "main_subnets" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.subnet_cidr, count.index)
  availability_zone = data.aws_availability_zones.zones.names[count.index]
  tags = {
    Name = "Subnet_${count.index}"
    Type = "Public"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name"  = "Main"
    "Owner" = "Venky"
  }
}

resource "aws_route_table" "rt1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public"
  }
}

resource "aws_route_table_association" "rt_subnet" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.main_subnets.*.id[count.index]
  route_table_id = aws_route_table.rt1.id
}

resource "aws_security_group" "webserver" {
  name        = "Webserver"
  description = "Webserver network traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
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
    Name = "Allow traffic"
  }
}

 # Instance

resource "aws_instance" "web" {
  ami                    = var.amis[data.aws_availability_zones.zones.names[0]]
  instance_type          = var.instance
  key_name               = var.key_name
  subnet_id              = aws_subnet.main_subnets.*.id[0]
  vpc_security_group_ids = [aws_security_group.webserver.id]

  associate_public_ip_address = true

  #userdata
  user_data = <<EOF
#!/bin/bash
apt-get -y update
apt-get -y install nginx
service nginx start
echo fin v1.00!
EOF

  tags = {
    Name = "NGX web"
  }
}