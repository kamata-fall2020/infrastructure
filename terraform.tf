
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}



provider "aws"  {
  profile = var.providerProfile
  region  = var.Region
}

# provider "aws" {
#   alias = "ghactions"
#   profile = var.ghactionsProfile
#   region = var.ghactionsRegion
# }

#resource for creating s3 bucket

resource "aws_s3_bucket" "bucket" {
  bucket        =  "${var.providerProfile}.${var.bucketName}"
  acl           = "private"
  force_destroy = "true"



  tags = {
    Name        = "aditya_bucket"
    Environment = var.providerProfile
  }


  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }



  lifecycle_rule {
    enabled = true


    transition {
      days          = 30
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

  #allow ingress of port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.loadbalancer.id}"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = ["${aws_security_group.loadbalancer.id}"]
  }
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   security_groups = ["${aws_security_group.loadbalancer.id}"]
  # }
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   security_groups = ["${aws_security_group.loadbalancer.id}"]
  # }
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
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.My_VPC_Security_Group.id}"
  security_group_id        = "${aws_security_group.database.id}"
}


resource "aws_db_instance" "db" {
  allocated_storage      = "5"
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7.22"
  instance_class         = "db.t2.micro"
  identifier             = var.db_identifier
  name                   = var.rdsDBName
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  db_subnet_group_name   = "${aws_db_subnet_group.db-subnet.name}"
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
}


resource "aws_db_subnet_group" "db-subnet" {
  name       = "test-group"
  subnet_ids = "${aws_subnet.test_VPC_Subnet.*.id}"
}


data "aws_ami" "latest-ubuntu" {
  most_recent = true
  owners      = ["${var.devAccountId}"]
}

# IAM POLICY for Webapp
resource "aws_iam_policy" "WebAPPS3" {
  name        = var.IAMPolicyName
  description = "Policy for EC2 instance to use S3"
  policy      = <<-EOF
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Effect": "Allow",
 "Action": [
 "s3:*"
 ],
  "Resource": [
                "arn:aws:s3:::${var.providerProfile}.${var.bucketName}",
                "arn:aws:s3:::${var.providerProfile}.${var.bucketName}/*"
            ]
 }
 ]
}
EOF
}

#IAM policy for CodeDeploy to use S3 for read
resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
  name        = var.IAMCodeDeployPolicyName
  description = "IAM policy for CodeDeploy to use S3 for read"
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${var.providerProfile}.${var.codeDeployBucketName}",
              "arn:aws:s3:::${var.providerProfile}.${var.codeDeployBucketName}/*"
              ]
        }
    ]
}
EOF
}

#IAM policy to let ghactions upload latest artifact to dedicated s3
resource "aws_iam_user_policy" "GH-Upload-To-S3" {
  name        = var.IAMGHUploadS3PolicyName
  user        = "ghactionsCICD"
  #description = "Policy for EC2 instance to use S3"
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
              "arn:aws:s3:::${var.providerProfile}.${var.codeDeployBucketName}",
              "arn:aws:s3:::${var.providerProfile}.${var.codeDeployBucketName}/*"
            ]
        }
    ]
}
EOF
}

#GH-Code-Deploy policy allows GitHub Actions to call CodeDeploy APIs to initiate application deployment on EC2 instances.

resource "aws_iam_user_policy" "GH-Code-Deploy" {
  name        = var.IAMGHCodeDeployPolicyName
  user        = "ghactionsCICD"
  policy      = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.Region}:${var.devProdAccountId}:application:${var.appName}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.Region}:${var.devProdAccountId}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.Region}:${var.devProdAccountId}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.Region}:${var.devProdAccountId}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}


resource "aws_iam_user_policy" "gh-ec2-ami" {
  name        = var.IAMGHEC2AMIPolicyName
  user        = "ghactionsCICD"
  #description = "Policy for EC2 instance to use S3"
  policy      = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource":[
        "arn:aws:s3:::${var.providerProfile}.${var.codeDeployBucketName}",
        "arn:aws:s3:::${var.providerProfile}.${var.codeDeployBucketName}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cloud_Watch_Agent_Server_Policy" {
  name        = var.CloudWatchPolicyName
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
        }
    ]
}
EOF
}



# IAM ROLE
resource "aws_iam_role" "ec2role" {
  name               = var.IAMRole
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
  tags = {
    Name = "EC2 - S3 access policy"
  }
}

# IAM ROLE Create CodeDeployEC2ServiceRole IAM Role for EC2 Instance(s)
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name               = "CodeDeployEC2ServiceRole"
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
  tags = {
    Name = "CodeDeploy - EC2 service role"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_ec2_service" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = "arn:aws:iam::${var.devProdAccountId}:policy/${aws_iam_policy.CodeDeploy-EC2-S3.name}"
}

#CodeDeployEC2ServiceRole
#CodeDeployServiceRole
resource "aws_iam_role" "CodeDeployServiceRole" {
  name               = "CodeDeployServiceRole"
  assume_role_policy = <<-EOF
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Action": "sts:AssumeRole",
 "Principal": {
 "Service": "codedeploy.amazonaws.com"
 },
 "Effect": "Allow",
 "Sid": ""
 }
 ]
}
EOF
  tags = {
    Name = "CodeDeploy - Service role"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.CodeDeployServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}


resource "aws_iam_role_policy_attachment" "role_policy_attacher" {
 role = aws_iam_role.CodeDeployEC2ServiceRole.name
 policy_arn = aws_iam_policy.WebAPPS3.arn
}

resource "aws_iam_role_policy_attachment" "cloud_policy_attacher" {
 role = aws_iam_role.CodeDeployEC2ServiceRole.name
 policy_arn = aws_iam_policy.cloud_Watch_Agent_Server_Policy.arn
}
 


resource "aws_codedeploy_app" "csye6225-webapp" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

resource "aws_codedeploy_deployment_group" "csye6225-webapp-deployment" {
  app_name              = "${aws_codedeploy_app.csye6225-webapp.name}"
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = "arn:aws:iam::${var.devProdAccountId}:role/CodeDeployServiceRole"
  autoscaling_groups = ["${aws_autoscaling_group.autoscaling.name}"]
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

   load_balancer_info {
    target_group_info {
      name = "${aws_lb_target_group.alb-target-group.name}"
    }
  }

  #autoscaling_groups = ["${aws_autoscaling_group.auto_scale.name}"]


  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "ec2_app_server"
    }

  }

  auto_rollback_configuration {
    enabled = false
  }

}





#Creating a Instance profile
resource "aws_iam_instance_profile" "ec2_s3_profile" {
 name = "ec2_s3_profile"
 role = aws_iam_role.CodeDeployEC2ServiceRole.name
}

/*
resource "aws_instance" "my_ec2_instance" {
  ami                    = "${data.aws_ami.latest-ubuntu.id}"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.My_VPC_Security_Group.id}"]
  subnet_id              = "${aws_subnet.test_VPC_Subnet[0].id}"
  key_name               = var.ec2KeyName
  iam_instance_profile = "${aws_iam_instance_profile.ec2_s3_profile.name}"
  user_data              = <<-EOF
               #!/bin/bash
               sudo echo export "Bucketname=${aws_s3_bucket.bucket.bucket}" >> /etc/environment
               sudo echo export "Region=${var.Region}" >> /etc/environment
               sudo echo export "DBhost=${aws_db_instance.db.address}" >> /etc/environment
               sudo echo export "DBendpoint=${aws_db_instance.db.endpoint}" >> /etc/environment
               sudo echo export "DBname=${aws_db_instance.db.name}" >> /etc/environment
               sudo echo export "DBusername=${aws_db_instance.db.username}" >> /etc/environment
               sudo echo export "DBpassword=${aws_db_instance.db.password}" >> /etc/environment
               EOF

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }
  tags = {
 Name = "ec2_app_server"
 
 }
  


} 
*/


# aws launch configuration
resource "aws_launch_configuration" "launch_config" {
  name          = "launch_config"
  image_id      = "${data.aws_ami.latest-ubuntu.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.My_VPC_Security_Group.id}"]
  key_name        = var.ec2KeyName
  iam_instance_profile = "${aws_iam_instance_profile.ec2_s3_profile.name}"
  user_data              = <<-EOF
               #!/bin/bash
               sudo echo export "Bucketname=${aws_s3_bucket.bucket.bucket}" >> /etc/environment
               sudo echo export "Region=${var.Region}" >> /etc/environment
               sudo echo export "DBhost=${aws_db_instance.db.address}" >> /etc/environment
               sudo echo export "DBendpoint=${aws_db_instance.db.endpoint}" >> /etc/environment
               sudo echo export "DBname=${aws_db_instance.db.name}" >> /etc/environment
               sudo echo export "DBusername=${aws_db_instance.db.username}" >> /etc/environment
               sudo echo export "DBpassword=${aws_db_instance.db.password}" >> /etc/environment
               EOF

  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
    delete_on_termination = true
  }

  depends_on = [aws_s3_bucket.bucket,aws_db_instance.db]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "autoscaling" {
  name                 = "autoscaling"
  launch_configuration = "${aws_launch_configuration.launch_config.name}"
  min_size             = 3
  max_size             = 5
  default_cooldown     = 60
  desired_capacity     = 3
  vpc_zone_identifier = ["${aws_subnet.test_VPC_Subnet[0].id}"]
  
  target_group_arns    = ["${aws_lb_target_group.alb-target-group.arn}"]

  tag {
    key                 = "Name"
    value               = "ec2_app_server"
    propagate_at_launch = true
  }
}

resource "aws_lb_target_group" "alb-target-group" {  
  name     = "alb-target-group"  
  port     = "8080"  
  protocol = "HTTP"  
  vpc_id   = "${aws_vpc.test_VPC.id}"   
  tags     = {    
    name = "alb-target-group"    
  }   
}



# Auto scaling Policies
resource "aws_autoscaling_policy" "WebServerScaleUpPolicy" {
  name                   = "WebServerScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling.name}"
}

resource "aws_autoscaling_policy" "WebServerScaleDownPolicy" {
  name                   = "WebServerScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling.name}"
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling.name}"
  }
  alarm_description = "ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.WebServerScaleUpPolicy.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling.name}"
  }
  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.WebServerScaleDownPolicy.arn}"]
}



# Load Balancer Security Group
resource "aws_security_group" "loadbalancer" {
  name          = "loadbalancer_security_group"
  vpc_id        = aws_vpc.test_VPC.id
  ingress{
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  ingress{
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags          = {
    Name        = "loadbalancer_security_group"
    Environment = "${var.providerProfile}"
  }
}


resource "aws_lb" "appLoadbalancer" {
  name               = "appLoadbalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.loadbalancer.id}"]
  subnets            = "${aws_subnet.test_VPC_Subnet.*.id}"
  ip_address_type    = "ipv4"
  tags = {
    Environment = "${var.providerProfile}"
    Name = "appLoadbalancer"
  }

}

resource "aws_lb_listener" "webapp_listener" {
  load_balancer_arn = "${aws_lb.appLoadbalancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.alb-target-group.arn}"
  }
}






data "aws_route53_zone" "selected" {
  name         = "${var.providerProfile}.adityakamatcsye.me"
 # private_zone = false
}




resource "aws_route53_record" "dns-record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "api.${data.aws_route53_zone.selected.name}"
  type    = "A"

  alias {
    name    = "${aws_lb.appLoadbalancer.dns_name}"
    zone_id = "${aws_lb.appLoadbalancer.zone_id}"
    evaluate_target_health = true
  }
}


resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = var.dynamodbTableName
  hash_key       = "Id"
  read_capacity  = 5
  write_capacity = 5


  attribute {
    name = "Id"
    type = "S"
  }


}

