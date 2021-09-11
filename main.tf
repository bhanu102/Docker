#This is terraform code for VPC infra deployment

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

locals {
  env        = "Prod"
  owner      = "Bhanu"
  costcenter = 9000
}


resource "aws_vpc" "default" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name  = "${var.vpc_name}"
    Env   = "${local.env}"
    Owner = "${local.owner}"
    CC    = "${local.costcenter}"
  }
  # depends_on = ["aws_s3_bucket.example"] #Explicit dependency
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name  = "${var.IGW_name}"
    Env   = "${local.env}"
    Owner = "${local.owner}"
    CC    = "${local.costcenter}"
  }
  # depends_on = ["aws_s3_bucket.example"] #Explicit dependency
}

resource "aws_subnet" "subnets" {
  #count = "${length(var.cidrs)}"
  count                   = var.env != "Prod" ? 1 : 3
  vpc_id                  = aws_vpc.default.id #Implicit dependency
  cidr_block              = element(var.cidrs, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name  = "${var.vpc_name}-Subnet-${count.index + 1}"
    Env   = "${local.env}"
    Owner = "${local.owner}"
    CC    = "${local.costcenter}"
  }
}


resource "aws_route_table" "terraform-public" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = "${var.Main_Routing_Table}"

  }
}

resource "aws_route_table_association" "terraform-public" {
  #count = "${length(var.cidrs)}"
  count     = var.env != "Prod" ? 1 : 3
  subnet_id = element(aws_subnet.subnets.*.id, count.index)
  #aws_subnet.subnets.0.id
  #aws_subnet.subnets.1.id
  #aws_subnet.subnets.2.id
  route_table_id = aws_route_table.terraform-public.id
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "my_ami" {
  most_recent = true
  #name_regex       = "^mavrick"
  owners = ["454227745440"]
}


resource "aws_instance" "web-1" {
  ami                         = data.aws_ami.my_ami.id
  count                       = var.env != "Prod" ? 1 : 3
  instance_type               = "t2.micro"
  key_name                    = "bhanu_key_pair"
  subnet_id                   = element(aws_subnet.subnets.*.id, count.index)
  vpc_security_group_ids      = ["${aws_security_group.allow_all.id}"]
  associate_public_ip_address = true
  tags = {
    Name  = "${var.vpc_name}-Server-1"
    Env   = ""
    Owner = ""
  }
}
