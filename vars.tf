
variable "Region" {
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
