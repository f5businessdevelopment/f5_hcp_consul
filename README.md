# f5_consul_hcp
This projects helps to automate the BIG-IP configuration for automatically updating the BIG-Pool members whenever any new servers are deployed. It can also deploy new virtual server and pool configuration on the BIG-IP with AWAF cpolicy configuration on the VIP.

- Assumptions:
Enable ASM resource provision on BIG-IP
Install the RPM packages for AS3 and Fast templates
Tested with AS3 RPM 1.36 and Fast template 1.17.0
You have VPC Peering already done between the HashiCorp Virtual Network and your AWS VPC where the F5 bigip and backend applications are running. 

It uses Consul terraform Sync ( CTS enterprise 0.60 version), Consul HCP and Terraform Cloud. CTS  is used for Service Discovery and works with Consul HCP and Terraform Cloud. 

## How to use this repo

```
git clone https://github.com/f5businessdevelopment/f5_hcp_consul.git

```
update the terraform.tfvars.example file

```
cp terraform.tfvars.example terraform.tfvars

```

update the terraform.tfvars file with details like your AWS VPC id, cidr block, subnet id, security group id, consul cluster id and service principal taken from HVN.

### Deploy the infra on AWS using terraform

```
terraform plan && terraform apply 

```

This will deploy one jump box, f5 bigip, backend apps appA & appB alongwith consul agent, you can see the services ```appA``` and ```appB``` already register to the Consul Cluster. 




