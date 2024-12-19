# For Ubuntu nodes we start at configured offset of the subnets cidr array
resource "hcloud_network_subnet" "ubuntu_agent" {
  count        = length(var.ubuntu_agent_nodepools)
  network_id   = data.hcloud_network.k3s.id
  type         = "cloud"
  network_zone = var.network_region
  ip_range     = local.network_ipv4_subnets[count.index + var.ubuntu_agent_subnet_offset]
}
