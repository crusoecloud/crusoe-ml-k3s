terraform {
  required_providers {
    crusoe = {
      source = "registry.terraform.io/crusoecloud/crusoe"
    }
  }
}

locals {
  my_ssh_privkey_path="/Users/amrragab/.ssh/id_ed25519"
  my_ssh_pubkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIdc3Aaj8RP7ru1oSxUuehTRkpYfvxTxpvyJEZqlqyze amrragab@MBP-Amr-Ragab.local"
  worker_instance_type = "h100-80gb-sxm-ib.8x"
  worker_image = "ubuntu22.04-nvidia-sxm-docker:latest"
  ib_partition_id = "6dcef748-dc30-49d8-9a0b-6ac87a27b4f8"
  count_workers = 2
  headnode_instance_type="c1a.8x"
  deploy_location = "us-east1-a"
  haproxy_local = <<-EOT
    global
        log /dev/log local0
        log /dev/log local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

    defaults
        log global
        mode tcp
        timeout connect 5000
        timeout client 50000
        timeout server 50000

    frontend k3s_cluster
        bind *:6443
        mode tcp
        default_backend k3s_nodes

    backend k3s_nodes
        mode tcp
        balance roundrobin
        server k3s_node1 ${crusoe_compute_instance.k3s_0.network_interfaces[0].private_ipv4.address}:6443 check
        server k3s_node2 ${crusoe_compute_instance.k3s_1.network_interfaces[0].private_ipv4.address}:6443 check
        server k3s_node3 ${crusoe_compute_instance.k3s_2.network_interfaces[0].private_ipv4.address}:6443 check
  EOT
}

resource "local_file" "haproxy_config" {
  filename = "haproxy.cfg"
  content  = local.haproxy_local
}


resource "crusoe_compute_instance" "k3s_lb" {
    depends_on = [local_file.haproxy_config]
    name = "crusoe-k3s-lb"
    type = local.headnode_instance_type
    ssh_key = local.my_ssh_pubkey
    location = local.deploy_location
    image = "ubuntu22.04:latest"
    startup_script = file("k3haproxy-install.sh")

    provisioner "local-exec" {
      command = "crusoe compute vms get ${self.name} -f json > /tmp/metadata.${self.name}.json"
    }

    provisioner "file" {
      source      = "haproxy.cfg"
      destination = "/tmp/haproxy.cfg"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }
}

resource "crusoe_compute_instance" "k3s_0" {
    name = "crusoe-k3s-0"
    type = local.headnode_instance_type
    ssh_key = local.my_ssh_pubkey
    location = local.deploy_location
    image = "ubuntu22.04:latest"
    startup_script = file("k3install-main.sh")

    provisioner "local-exec" {
      command = "crusoe compute vms get ${self.name} -f json > /tmp/metadata.${self.name}.json"
    }
    provisioner "file" {
      source      = "k3-0-serve-token.py"
      destination = "/opt/k3-0-serve-token.py"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }
    provisioner "file" {
      source      = "/tmp/metadata.${crusoe_compute_instance.k3s_0.name}.json"
      destination = "/root/k3-0-main.json"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }
}

resource "crusoe_compute_instance" "k3s_1" {
    depends_on = [crusoe_compute_instance.k3s_0]
    name = "crusoe-k3s-1"
    type = local.headnode_instance_type
    ssh_key = local.my_ssh_pubkey
    location = local.deploy_location
    image = "ubuntu22.04:latest"
    startup_script = file("k3install-child.sh")

    provisioner "file" {
      source      = "/tmp/metadata.${crusoe_compute_instance.k3s_0.name}.json"
      destination = "/root/k3-0-main.json"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }
}

resource "crusoe_compute_instance" "k3s_2" {
    depends_on = [crusoe_compute_instance.k3s_0]
    name = "crusoe-k3s-2"
    type = local.headnode_instance_type
    ssh_key = local.my_ssh_pubkey
    location = local.deploy_location
    image = "ubuntu22.04:latest"
    startup_script = file("k3install-child.sh")

    provisioner "file" {
      source      = "/tmp/metadata.${crusoe_compute_instance.k3s_0.name}.json"
      destination = "/root/k3-0-main.json"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }
}

resource "null_resource" "copy-lb-file" {
  depends_on = [crusoe_compute_instance.k3s_lb]
  provisioner "file" {
      source      = "/tmp/metadata.${crusoe_compute_instance.k3s_lb.name}.json"
      destination = "/root/k3-lb-main.json"
      connection {
        type = "ssh"
        user = "root"
        host = "${crusoe_compute_instance.k3s_0.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }

}

resource "crusoe_compute_instance" "workers" {
    depends_on = [crusoe_compute_instance.k3s_lb]
    count = local.count_workers
    name = "crusoe-k3s-worker-${count.index}"
    type = local.worker_instance_type
    ssh_key = local.my_ssh_pubkey
    location = local.deploy_location
    image = local.worker_image
    startup_script = file("k3install-worker.sh")
    host_channel_adapters = [{ib_partition_id = local.ib_partition_id}]
    provisioner "file" {
      source      = "/tmp/metadata.${crusoe_compute_instance.k3s_0.name}.json"
      destination = "/root/k3-0-main.json"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }

    provisioner "file" {
      source      = "/tmp/metadata.${crusoe_compute_instance.k3s_lb.name}.json"
      destination = "/root/k3-lb-main.json"
      connection {
        type = "ssh"
        user = "root"
        host = "${self.network_interfaces[0].public_ipv4.address}"
        private_key = file("${local.my_ssh_privkey_path}")
      }
    }
}

resource "crusoe_vpc_firewall_rule" "k3_rule" {
  network           = crusoe_compute_instance.k3s_lb.network_interfaces[0].network
  name              = "k3s-pub-access"
  action            = "allow"
  direction         = "ingress"
  protocols         = "tcp"
  source            = "0.0.0.0/0"
  source_ports      = "1-65535"
  destination       = crusoe_compute_instance.k3s_lb.network_interfaces[0].private_ipv4.address
  destination_ports = "6443"
}

output "k30-instance_public_ip" {
  value = crusoe_compute_instance.k3s_0.network_interfaces[0].public_ipv4.address
}
