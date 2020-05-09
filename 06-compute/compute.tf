resource "ibm_is_ssh_key" "iac_app_key" {
  name       = "${var.project_name}-${var.environment}-key"
  public_key = var.public_key
}

data "local_file" "db" {
  filename = "${path.module}/db.min.json"
}

resource "ibm_is_instance" "iac_app_instance" {
  name    = "${var.project_name}-${var.environment}-instance"
  image   = "r006-14140f94-fcc4-11e9-96e7-a72723715315"
  profile = "cx2-2x4"

  primary_network_interface {
    name            = "eth1"
    subnet          = ibm_is_subnet.iac_app_subnet.id
    security_groups = [ibm_is_security_group.iac_app_security_group.id]
  }

  vpc  = ibm_is_vpc.iac_app_vpc.id
  zone = "us-south-1"
  keys = [ibm_is_ssh_key.iac_app_key.id]

  user_data = <<-EOUD
            #!/bin/bash
            echo '${data.local_file.db.content_base64}' | base64 --decode > /var/lib/db.min.json

            # https://askubuntu.com/questions/1154892/prevent-question-restart-services-during-package-upgrades-without-asking
            echo '* libraries/restart-without-asking boolean true' | debconf-set-selections

            # With Python3:
            # apt update
            # apt install -y python3-pip
            # pip3 install json-server.py
            #
            # json-server -b :${var.port} /var/lib/db.min.json &

            # With NodeJS:
            apt update
            curl -sL https://deb.nodesource.com/setup_13.x | sudo -E bash -
            apt-get install -y nodejs
            npm install -g json-server

            json-server --watch /var/lib/db.min.json --port ${var.port} --host 0.0.0.0 &
            EOUD

  tags = ["iac-${var.project_name}-${var.environment}"]
}