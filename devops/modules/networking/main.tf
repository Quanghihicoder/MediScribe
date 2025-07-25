resource "aws_subnet" "public_a" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_cidr_block_a
  availability_zone       = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "mediscribe-public-subnet"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_cidr_block_b
  availability_zone       = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "mediscribe-public-subnet"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_cidr_block_a
  availability_zone = var.az_a

  tags = {
    Name = "mediscribe-private-subnet"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_cidr_block_b
  availability_zone = var.az_b

  tags = {
    Name = "mediscribe-private-subnet"
  }
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = var.public_route_table_id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = var.public_route_table_id
}



# ==================

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "mediscribe-nat-eip"
  }
}

# NAT Gateway in public subnet
resource "aws_nat_gateway" "mediscribe_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id  # Using public_a, but can use public_b for HA

  tags = {
    Name = "mediscribe-nat-gateway"
  }
}

# Private route table (new)
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mediscribe_nat.id
  }

  tags = {
    Name = "mediscribe-private-rt"
  }
}

# Associate private subnets with NAT route table
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Add explicit route to ECR endpoint (optional but recommended)
resource "aws_route" "ecr_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "3.104.83.140/32"  # ECR API endpoint in ap-southeast-2
  nat_gateway_id         = aws_nat_gateway.mediscribe_nat.id
}