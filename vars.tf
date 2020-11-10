
variable "Region" {
  type = string
}
variable "zone_id" {
  type = string
}
variable "ghactionsRegion" {
  type = string
}
variable "IAMGHUploadS3PolicyName" {
  type = string
}
variable "codeDeployBucketName" {
  type = string
}
variable "IAMCodeDeployPolicyName" {
  type = string
}
variable "IAMGHCodeDeployPolicyName" {
  type = string
}
variable "CloudWatchPolicyName" {
  type = string
}
variable "appName" {
  type = string
}
variable "IAMGHEC2AMIPolicyName" {
  type = string
}
variable "devProdAccountId" {
  type = string
}
variable "ghactionsProfile" {
  type = string
}
variable "IAMRole" {
  type = string
}
variable "ec2KeyName" {
  type = string
}
variable "db_password" {
  type = string
}
variable "db_username" {
  type = string
}
variable "db_identifier" {
  type = string
}
variable "IAMPolicyName" {
  type = string
}
variable "dynamodbTableName" {
  type = string
}
variable "providerProfile"{
  type = string
}
variable "bucketName"{
  type = string
}
variable "rdsDBName" {
  type = string
}
variable "devAccountId" {
  type = string
}
variable "availableZone" {
  type = list
}
variable "instanceTenancy" {
  default = "default"
}
variable "dnsSupport" {
  default = true
}
variable "dnsHostNames" {
  default = true
}
variable "myVpcCIDR" {
  type = string
}
variable "sCIDR" {
  type = list
}
variable "destinationCIDR" {
  type = string
}
variable "ec2Subnet_cidr" {
  type = string
}
variable "ingressCIDR" {
  type = list
}
variable "egressCIDR" {
  type = list
}
variable "mapPubIP" {
  default = true
}

