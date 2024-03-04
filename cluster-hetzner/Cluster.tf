terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.45.0"
    }
  }
}

variable "hcloud_token" {
  sensitive = true 
}

variable "ssh_key" {
  sensitive = true 
}

variable "location" {
  type = string
  default = "hel1"
}

variable "server_type" {
  type = string
  default = "cpx31"
}

variable "nodes" {
  type = number
  default = 3
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_network" "server_net" {
  name     = "server_net"
  ip_range = "10.0.1.0/24"
}

resource "hcloud_network_subnet" "server_net_subnet" {
  network_id   = hcloud_network.server_net.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_server" "master" {
  name        = "master"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  labels = {
    "cluster" : "cluster"
  }
  ssh_keys = [ var.ssh_key ]
}

resource "hcloud_server_network" "master_network" {
  server_id  = hcloud_server.master.id
  subnet_id = hcloud_network_subnet.server_net_subnet.id
}

resource "hcloud_server" "node" {
  count = var.nodes
  name        = "node${count.index}"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  labels = {
    "cluster" : "cluster"
  }
  ssh_keys = [ var.ssh_key ]
}

resource "hcloud_server_network" "node_network" {
  count     = var.nodes
  server_id  = hcloud_server.node[count.index].id
  subnet_id = hcloud_network_subnet.server_net_subnet.id
}

resource "hcloud_load_balancer" "load_balancer" {
  name               = "load_balancer"
  load_balancer_type = "lb11"
  location           = var.location
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  label_selector   = "cluster=cluster"
}

resource "hcloud_load_balancer_service" "load_balancer_http" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "http"
}

resource "hcloud_load_balancer_service" "load_balancer_https" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443
}