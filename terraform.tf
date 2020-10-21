
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

 

provider "aws" {
  profile = "dev"
  region  = "us-east-1"
}

#resource for creating s3 bucket

resource "aws_s3_bucket" "bucket" {
  bucket = "webapp.aditya.kamat"
  acl    = "private"
  force_destroy="true"

 

  tags = {
    Name        = "aditya_bucket"
    Environment = "dev"
  }

 
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }

 

  lifecycle_rule {
    enabled = true

 
    transition {
      days = 30
      storage_class = "STANDARD_IA"
    }
  }
}

  

#Point 1:  Create VPC
resource "aws_vpc" "test_VPC" {
  cidr_block           = var.myVpcCIDR
  instance_tenancy     = var.instanceTenancy
  enable_dns_support   = var.dnsSupport
  enable_dns_hostnames = var.dnsHostNames
  tags = {
    Name = "Aditya VPC"
  }
}
# end resource

#Point 2: Create Subnet 
resource "aws_subnet" "test_VPC_Subnet" {
  count                   = "${length(var.sCIDR)}"
  vpc_id                  = "${aws_vpc.test_VPC.id}"
  cidr_block              = "${element(var.sCIDR, count.index)}"
  map_public_ip_on_launch = var.mapPubIP
  availability_zone       = "${element(var.availableZone, count.index)}"
  tags = {
    Name = "Subnet-${count.index + 1}"
  }
}



# Poni 3: Create the Internet Gateway
resource "aws_internet_gateway" "test_VPC_GW" {
  vpc_id = aws_vpc.test_VPC.id
  tags = {
    Name = "My VPC Internet Gateway"
  }
} # end resource


# Point 4 : Create the Route Table
resource "aws_route_table" "test_VPC_route_table" {
  vpc_id = aws_vpc.test_VPC.id
  tags = {
    Name = "My VPC Route Table"
  }
} # end resource


# Create the Internet Access
resource "aws_route" "test_VPC_internet_access" {
  route_table_id         = aws_route_table.test_VPC_route_table.id
  destination_cidr_block = var.destinationCIDR
  gateway_id             = aws_internet_gateway.test_VPC_GW.id
} # end resource

# Associate the Route Table with the Subnet

resource "aws_route_table_association" "test_VPC_association" {
  count          = "${length(var.sCIDR)}"
  subnet_id      = "${element(aws_subnet.test_VPC_Subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.test_VPC_route_table.id}"
}

# end vpc.tf

resource "aws_security_group" "My_VPC_Security_Group" {
  vpc_id      = aws_vpc.test_VPC.id
  name        = "My VPC Security Group"
  description = "My VPC Security Group"

  # allow ingress of port 22
  ingress {
    cidr_blocks = var.ingressCIDR
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = var.ingressCIDR
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = var.ingressCIDR
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = var.ingressCIDR
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} # end resource


# Database security group
resource "aws_security_group" "database" {
  name   = "database_security_group"
  vpc_id = aws_vpc.test_VPC.id

}


resource "aws_security_group_rule" "database" {
  type      = "ingress"
  from_port = 3306
  to_port   = 3306
  protocol  = "tcp"
  source_security_group_id = "${aws_security_group.My_VPC_Security_Group.id}"
  security_group_id = "${aws_security_group.database.id}"
}


resource "aws_db_instance" "db" {
  allocated_storage      = "5"
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7.22"
  instance_class         = "db.t2.micro"
  identifier             = "csye6225-f20"
  name                   = "csye6225"
  username               = "aditya"
  password               = "adityaKamat"
  skip_final_snapshot    = true
  db_subnet_group_name   = "${aws_db_subnet_group.db-subnet.name}"
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
}


resource "aws_instance" "my_ec2_instance" {
  ami                    = "${data.aws_ami.latest-ubuntu.id}"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.My_VPC_Security_Group.id}"]
  subnet_id              = "${aws_subnet.test_VPC_Subnet[0].id}"
  key_name               = "csye6225-fall2020-aws"
  user_data = <<-EOF
               #!/bin/bash
               sudo echo export "Bucketname=${aws_s3_bucket.bucket.bucket}" >> /etc/environment
               sudo echo export "DBhost=${aws_db_instance.db.address}" >> /etc/environment
               sudo echo export "DBendpoint=${aws_db_instance.db.endpoint}" >> /etc/environment
               sudo echo export "DBname=${var.rdsDBName}" >> /etc/environment
               sudo echo export "DBusername=${aws_db_instance.db.username}" >> /etc/environment
               sudo echo export "DBpassword=${aws_db_instance.db.password}" >> /etc/environment
               EOF

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
    delete_on_termination = true
  }


}

resource "aws_db_subnet_group" "db-subnet" {
  name       = "test-group"
  subnet_ids = "${aws_subnet.test_VPC_Subnet.*.id}"
}


data "aws_ami" "latest-ubuntu" {
most_recent = true
owners = ["${var.devAccountId}"] 
}

resource "aws_iam_role" "role" {
  name = "test-role"

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "WebAppS3"
  description = "A WebAppS3 policy for S3 bucket"

  policy = <<-EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::webapp.aditya.kamat",
                "arn:aws:s3:::webapp.aditya.kamat/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}


resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "csye6225"
  hash_key       = "Id"
 

  attribute {
    name = "Id"
    type = "S"
  }


}
