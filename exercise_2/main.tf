#Creating VPC under name VPC
resource "aws_vpc" "VPC" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "Main_VPC"
  }
}

# Creating Two public subnets in different available zones
resource "aws_subnet" "public_subnets" {
  count             = var.pub_subnet_count
  vpc_id            = aws_vpc.VPC.id
  cidr_block        = element(var.subnet_cidr, count.index)
  availability_zone = data.aws_availability_zones.zones.names[count.index]
  tags = {
    Name = "pub_Subnet_${count.index}"
    Type = "Public"
  }
}

#private sub nets in different zones

resource "aws_subnet" "private_subnets" {
  count             = var.pub_subnet_count
  vpc_id            = aws_vpc.VPC.id
  cidr_block        = element(var.pri_subnet_cidr, count.index)
  availability_zone = data.aws_availability_zones.zones.names[count.index]

  tags = {
    Name = "pri_Subnet_${count.index}"
    Type = "Private"
  }
}

# creating internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.VPC.id

  tags = {
    "Name"  = "Main"
    "Owner" = "V3"
  }
}

# creating elastic Ip "aws_eip"

resource "aws_eip" "elastic_Ip" {
  vpc = true
  tags = {
    "Name" = "elastic_ip"
  }
}

# Creating Nat on one public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.elastic_Ip.id
  subnet_id     = aws_subnet.public_subnets.*.id[0]

  tags = {
    Name = "NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

#creating routes' for public subnets
resource "aws_route_table" "pub_rt" {
    vpc_id = aws_vpc.VPC.id
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main.id
    }
    tags = {
      "Name" = "public_route"
    }
  }

 #creating routes for private subnets
 resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private_route"
  }
} 

#route tables to associate with routes and subnets

# route table for public subnets
resource "aws_route_table_association" "pub_sub_rt" {
  count = var.pub_subnet_count
  subnet_id      = aws_subnet.public_subnets.*.id[count.index]
  route_table_id = aws_route_table.pub_rt.id
}

# routing to private subnets
resource "aws_route_table_association" "pri_sub_rt" {
  count = var.pub_subnet_count
  subnet_id      = aws_subnet.private_subnets.*.id[count.index]
  route_table_id = aws_route_table.pri_rt.id
}

# security groups
resource "aws_security_group" "webserver" {
  name        = "webserver"
  description = "webserver network traffic"
  vpc_id      = aws_vpc.VPC.id

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
    cidr_blocks = aws_subnet.public_subnets.*.cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow traffic"
  }
}

#security group for load balancer
resource "aws_security_group" "alb" {
  name        = "alb"
  description = "alb network traffic"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.webserver.id]
  }

  tags = {
    Name = "allow traffic"
  }
}

resource "aws_launch_template" "launchtemplate1" {
  name = "web"

  image_id               = "ami-0d70546e43a941d70"
  instance_type          = "t2.micro"
  key_name               = "NGX"
  vpc_security_group_ids = [aws_security_group.webserver.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "WebServer"
    }
  }

  user_data = filebase64("${path.module}/ec2.userdata")
}

resource "aws_lb" "alb1" {
  name               = "alb1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public_subnets.*.id

  enable_deletion_protection = false

  /*
  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "test-lb"
    enabled = true
  }
  */

  tags = {
    Environment = "Prod"
  }
}


resource "aws_alb_target_group" "webserver" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.VPC.id
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb1.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }
}

resource "aws_alb_listener_rule" "rule1" {
  listener_arn = aws_alb_listener.front_end.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_autoscaling_group" "bar" {
    availability_zones = aws_subnet.private_subnets.*.id
    desired_capacity   = 1
    max_size           = 1
    min_size           = 1

    launch_template = {
      id      = "${aws_launch_template.foobar.id}"
      version = "$$Latest"
    }
}