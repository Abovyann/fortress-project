resource "aws_vpc" "fortress_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "fortress_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.fortress_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "fortress-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.fortress_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "fortress-private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.fortress_vpc.id

  tags = {
    Name = "fortress-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.fortress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "fortress-public-rt"
  }

}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.fortress_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "fortress-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "fortress-nat"
  }
}

resource "aws_security_group" "public_sg" {
  vpc_id      = aws_vpc.fortress_vpc.id
  description = "Allow SSH and Web"
  name        = "fortress-public-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["195.250.80.115/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
    Name = "fortress-public-sg"
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id      = aws_vpc.fortress_vpc.id
  name        = "fortress-private-sg"
  description = "Allow only internal traffic"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public_sg.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fortress-private-sg"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "fortress_tf_key"
  public_key = file("fortress_tf_key.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "haproxy_lb" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "fortress-haproxy-lb"
  }
}

resource "aws_instance" "web_servers" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "fortress-web-node-${count.index + 1}"
  }
}


resource "aws_instance" "db_primary" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "fortress-db-primary"
  }
}

resource "aws_instance" "db_replica" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "fortress-db-replica"
  }
}

output "haproxy_public_ip" {
  value = aws_instance.haproxy_lb.public_ip
}

output "web_server_ips" {
  value = aws_instance.web_servers[*].private_ip
}

output "db_primary_ip" {
  value = aws_instance.db_primary.private_ip
}

output "db_replica_ip" {
  value = aws_instance.db_replica.private_ip
}

# 1. The S3 Bucket
resource "aws_s3_bucket" "db_backups" {
  bucket = "fortress-db-backups-narek-2026" # <--- Must match your script!
}

# 2. The IAM Role (Allows EC2 to assume this identity)
resource "aws_iam_role" "ec2_s3_role" {
  name = "fortress_ec2_s3_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 3. The IAM Policy (Gives the Role permission to write to S3)
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 4. The Instance Profile (The "glue" that attaches the Role to an EC2 instance)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "fortress_ec2_profile"
  role = aws_iam_role.ec2_s3_role.name
}