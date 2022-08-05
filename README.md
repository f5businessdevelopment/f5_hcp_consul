# f5_consul_hcp
This projects helps to automate the BIG-IP configuration by automatically updating the BIG-Pool members whenever any new servers are deployed. It can also deploy new virtual server and pool configuration on the BIG-IP with AWAF policy configuration on the VIP.

## Assumptions:

- Enable ASM resource provision on BIG-IP after BIG-IP is deployed

- Install the RPM packages for AS3 and Fast templates

- Tested with AS3 RPM 1.36 and Fast template 1.17.0

- You have VPC Peering already done between the HashiCorp Virtual Network and your AWS VPC where the F5 bigip and backend applications are running. 

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


### Run the Consul-terraform-Sync

Once the infra is deployed it will provide you all the required details as shown

```
F5_Password = "te4l3RLtMc"
consul_root_token = <sensitive>
consul_url = "https://ssome-consul-cluster.consul.xxxxxf6-6078-40ed-99e.aws.hashicorp.cloud"
f5_ui = "https://3.2.2.6:8443"
next_steps = "Hashicups Application will be ready in ~2 minutes. Use 'terraform output consul_root_token' to retrieve the root token."
ssh_tojumpbox = "ssh -i consul-client ubuntu@18.237.4.21"

```
you can ssh to the ```jumpbox``` login to the cts directory and fine tune the hcl file as per your parameters

example hcl file under cts directory


``` 
cat << EOF > f5nia.hcl

## Global Config
log_level   = "DEBUG"
working_dir = "sync-tasks"
port        = 8558

syslog {}

buffer_period {
  enabled = true
  min     = "5s"
  max     = "20s"
}

# Consul Block
 consul {
  address = "localhost:8500"
  service_registration {
    enabled = true
    service_name = "CTS Event AS3 WAF"
    default_check {
      enabled = true
      address = "http://localhost:8558"
   }
}
token = "${consul_acl_token}"
}


# Driver block
driver "terraform-cloud" {
  hostname     = "https://app.terraform.io"
  organization = "SCStest"
  token        = "<token>"
required_providers {
    bigip = {
      source = "F5Networks/bigip"
    }
  }

}

terraform_provider "bigip" {
  address  = "5.2.2.29:8443"
  username = "admin"
  password = "s8!"
}

 task {
  name = "AS3-tenent_AppA"
  description = "BIG-IP example"
  source = "scshitole/consul-sync-multi-tenant/bigip"
  providers = ["bigip"]
  services = ["appA"]
  variable_files = ["tenantA_AppA.tfvars"]
}
 
 task {
  name = "AS3-tenent_AppB"
  description = "BIG-IP example"
  source = "scshitole/consul-sync-multi-tenant/bigip"
  providers = ["bigip"]
  services = ["appB"]
  variable_files = ["tenantB_AppB.tfvars"]
}

EOF 
```


Make sure you also update the tfvars file for your applications accordingly. The task block above sources the module to deploy the FAST template and looks for the applications in the services section in the task block. For example in the above hcl file it will look for ```appA``` and ```appB```

```
cat << EOF > tenantA_AppA.tfvars

tenant="tenant_AppA"
app="AppA"
virtualAddress="10.0.0.201"
virtualPort=8080
defpool="appA_pool"
address="3.7.14.8"
username="admin"
password="Pxxeal"
port=8443

EOF

cat << EOF > tenantB_AppB.tfvars

tenant="tenant_AppB"
app="AppB"
virtualAddress="10.0.0.202"
virtualPort=8080
defpool="appB_pool"
address="5.7.14.4"
username="admin"
password="PxxxxayJ"
port=8443

EOF

```

 It uses the module registry https://registry.terraform.io/modules/scshitole/consul-sync-multi-tenant/bigip/latest and sources the module in the hcl file.


To  Run the Consul Terraform Sync binary use the command

```
consul-terraform-sync -config-file=f5nia.hcl

```



