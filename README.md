# infrastructure

Script takes care of following points
Create Virtual Private Cloud (VPC) (Links to an external site.).
Create subnets (Links to an external site.) in your VPC. You must create 3 subnets, each in different availability zone in the same region in the same VPC.
Create Internet Gateway (Links to an external site.) resource and attach the Internet Gateway to the VPC.
Create a public route table (Links to an external site.). Attach all subnets created above to the route table.
Create a public route in the public route table created above with destination CIDR block 0.0.0.0/0 and internet gateway created above as the target.

Steps to run Terraform script

1- terraform init
2- terraform validate
3- terraform apply -var -file="vars.tfvars"
4- Now the VPC and subnets have been created in your AWS console
In order to create new VPCs and Subnets create a new workspace 

5- terraform workspace new test
6- terraform apply -var -file="vars.tfvars"

