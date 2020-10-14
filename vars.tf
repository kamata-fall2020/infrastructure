
variable "Region" {
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
variable "ingressCIDR" {
  type = list
}
variable "egressCIDR" {
  type = list
}
variable "mapPubIP" {
  default = true
}
