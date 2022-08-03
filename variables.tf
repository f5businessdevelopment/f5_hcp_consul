variable "vpc_id" {
  type        = string
  description = "AWS VPC ID where your instances are running"
}

variable "vpc_cidr_block" {
  type        = string
  description = "AWS CIDR block of the above VPC"
}

variable "subnet_id" {
  type        = string
  description = "AWS subnet (public) in that VPC"
}

variable "cluster_id" {
  type        = string
  description = "HCP Consul ID"
}

variable "hcp_consul_security_group_id" {
  type        = string
  description = "AWS Security group for HCP Consul"
}

variable "service-principal-key-client-id" {
  type        = string
  description = "Service principle Key required for  Consul HCP"
}

variable "service-principal-key-client-secret" {
  type        = string
  description = "Service principle key for HCP Consul HCP"
}

variable "f5ami" {
  description = "f5 ami in west 2"
  default     = "ami-09ae9af26d2e96786"

}
