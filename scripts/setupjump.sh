#!/usr/bin/env bash

set -ex

start_service() {
  mv $1.service /usr/lib/systemd/system/
  systemctl enable $1.service
  systemctl start $1.service
}

setup_deps() {
  add-apt-repository universe -y
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  curl -sL 'https://deb.dl.getenvoy.io/public/gpg.8115BA8E629CC074.key' | gpg --dearmor -o /usr/share/keyrings/getenvoy-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/getenvoy-keyring.gpg] https://deb.dl.getenvoy.io/public/deb/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/getenvoy.list
  apt update -qy
  version="${consul_version}"
  consul_package="consul-enterprise="$${version:1}"*"
  apt install -qy apt-transport-https gnupg2 curl lsb-release nomad $${consul_package} getenvoy-envoy unzip jq apache2-utils nginx

  curl -fsSL https://get.docker.com -o get-docker.sh
  sh ./get-docker.sh
}

setup_networking() {
  # echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-arptables
  # echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-ip6tables
  # echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-iptables
  curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$([ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz
  mkdir -p /opt/cni/bin
  tar -C /opt/cni/bin -xzf cni-plugins.tgz
}

setup_consul() {
  mkdir --parents /etc/consul.d /var/consul
  chown --recursive consul:consul /etc/consul.d
  chown --recursive consul:consul /var/consul

  echo "${consul_ca}" | base64 -d >/etc/consul.d/ca.pem
  echo "${consul_config}" | base64 -d >client.temp.0
  ip=$(hostname -I | awk '{print $1}')
  jq '.ca_file = "/etc/consul.d/ca.pem"' client.temp.0 >client.temp.1
  jq --arg token "${consul_acl_token}" '.acl += {"tokens":{"agent":"\($token)"}}' client.temp.1 >client.temp.2
  jq '.ports = {"grpc":8502}' client.temp.2 >client.temp.3
  jq '.bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"'${vpc_cidr}'\" | attr \"address\" }}"' client.temp.3 >/etc/consul.d/client.json
}

cd /home/ubuntu/

echo "${consul_service}" | base64 -d >consul.service

setup_networking
setup_deps

setup_consul

cat << EOF > /etc/consul.d/nginx.json
{
  "service": {
    "name": "jump",
    "port": 80,
    "checks": [
      {
        "id": "web",
        "name": "nginx TCP Check",
        "tcp": "localhost:80",
        "interval": "10s",
        "timeout": "1s"
      }
    ],
   "token": "${consul_acl_token}"
  }
}
EOF


start_service "consul"

# nomad and consul service is type simple and might not be up and running just yet.
sleep 10

cd /home/ubuntu/

mkdir -p cts

cd cts

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


#Download Consul Terraform Sync

curl --silent --remote-name https://releases.hashicorp.com/consul-terraform-sync/0.6.0+ent/consul-terraform-sync_0.6.0+ent_linux_amd64.zip

#Install Consul Terraform Sync

unzip consul-terraform-sync_0.6.0+ent_linux_amd64.zip

sudo chown root:root consul-terraform-sync
sudo mv consul-terraform-sync /usr/local/bin/
consul -terraform-sync -autocomplete-install
complete -C /usr/local/bin/consul-terraform-sync consul-terraform-sync

cd /tmp
#install vault
#   Download
curl --silent --remote-name https://releases.hashicorp.com/vault/1.5.0/vault_1.5.0_linux_amd64.zip

#   Install
unzip vault_1.5.0_linux_amd64.zip
sudo chown root:root vault
sudo mv vault /usr/local/bin/
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

cat <<-EOF > vault.service
[Unit]
Description=Vault
Documentation=https://www.vaultproject.io/
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
Environment=GOMAXPROCS=nproc
ExecStart=/usr/local/bin/vault server -dev -dev-root-token-id="root" -dev-listen-address=0.0.0.0:8200
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 755 vault.service
sudo mv vault.service /etc/systemd/system/

#   Enable the Service
sudo systemctl enable vault
sudo service vault start

sleep 10

#   Tell Vault we're using http
echo -e "export VAULT_ADDR=http://127.0.0.1:8200" >> ~/.bash_profile
export VAULT_ADDR=http://127.0.0.1:8200

#   Export VAULT_TOKEN
echo -e "export VAULT_TOKEN=root" >> ~/.bash_profile
export VAULT_TOKEN=root

cd
echo "done"

cd /tmp
curl --silent --remote-name https://releases.hashicorp.com/vault/1.5.0/vault_1.5.0_linux_amd64.zip
unzip vault_1.5.0__linux_amd64.zip
sudo chown root:root vault
sudo mv vault /usr/local/bin/
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

cat <<-EOF > vault.service
[Unit]
Description=Vault
Documentation=https://www.vaultproject.io/
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
Environment=GOMAXPROCS=nproc
ExecStart=/usr/local/bin/vault server -dev -dev-root-token-id="root" -dev-listen-address=0.0.0.0:8200
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 755 vault.service
sudo mv vault.service /etc/systemd/system/

#   Enable the Service
sudo systemctl enable vault
sudo service vault start

sleep 10

#   Tell Vault we're using http
echo -e "export VAULT_ADDR=http://127.0.0.1:8200" >> ~/.bash_profile
export VAULT_ADDR=http://127.0.0.1:8200

#   Export VAULT_TOKEN
echo -e "export VAULT_TOKEN=root" >> ~/.bash_profile
export VAULT_TOKEN=root

