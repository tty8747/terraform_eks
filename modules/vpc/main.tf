terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

resource "aws_vpc" "vpc" {
  cidr_block       = var.cidr
  instance_tenancy = "default"

  tags = {
    Name        = "vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count = length(var.pub_subnets)
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.pub_subnets[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${var.environment}-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

  depends_on = [aws_route_table.public]
}

resource "aws_subnet" "private" {
  count = length(var.priv_subnets)
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.priv_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "private-${var.environment}-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id

  depends_on = [aws_route_table.private]
}

resource "aws_internet_gateway" "igw" {
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "igw-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_eip" "eip" {
  domain   = "vpc"
  count = length(aws_subnet.private)

  tags = {
    Name = "eip-${var.environment}-${count.index}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "ngw" {
  count = length(aws_subnet.private)
  allocation_id = aws_eip.eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "ngw-${var.environment}-${count.index}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt-public-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  count = length(aws_subnet.private)

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw[count.index].id
  }

  tags = {
    Name = "rt-private-${var.environment}"
    Environment = var.environment
  }
}
