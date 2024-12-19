variable "ubuntu_image" {
  description = "Ubuntu image to be used."
  type        = string
}

variable "ubuntu_agent_subnet_offset" {
  description = "Subnet offset for Ubuntu agent nodes in case you mix MicroOS & Ubuntu agents"
  type        = number
  default     = 127
}


variable "ubuntu_agent_nodepools" {
  description = "Number of Ubuntu agent nodes."
  type = list(object({
    name                       = string
    server_type                = string
    location                   = string
    backups                    = optional(bool)
    floating_ip                = optional(bool)
    labels                     = list(string)
    taints                     = list(string)
    longhorn_volume_size       = optional(number)
    swap_size                  = optional(string, "")
    zram_size                  = optional(string, "")
    kubelet_args               = optional(list(string), ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"])
    selinux                    = optional(bool, true)
    placement_group_compat_idx = optional(number, 0)
    placement_group            = optional(string, null)
    count                      = optional(number, null)
    nodes = optional(map(object({
      server_type                = optional(string)
      location                   = optional(string)
      backups                    = optional(bool)
      floating_ip                = optional(bool)
      labels                     = optional(list(string))
      taints                     = optional(list(string))
      longhorn_volume_size       = optional(number)
      swap_size                  = optional(string, "")
      zram_size                  = optional(string, "")
      kubelet_args               = optional(list(string), ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"])
      selinux                    = optional(bool, true)
      placement_group_compat_idx = optional(number, 0)
      placement_group            = optional(string, null)
      append_index_to_node_name  = optional(bool, true)
    })))
  }))
  default = []

  validation {
    condition = length(
      [for agent_nodepool in var.ubuntu_agent_nodepools : agent_nodepool.name]
      ) == length(
      distinct(
        [for agent_nodepool in var.ubuntu_agent_nodepools : agent_nodepool.name]
      )
    )
    error_message = "Names in ubuntu_agent_nodepools must be unique."
  }

  validation {
    condition     = alltrue([for agent_nodepool in var.ubuntu_agent_nodepools : (agent_nodepool.count == null) != (agent_nodepool.nodes == null)])
    error_message = "Set either nodes or count per ubuntu_agent_nodepool, not both."
  }


  validation {
    condition = alltrue([for agent_nodepool in var.ubuntu_agent_nodepools :
      alltrue([for agent_key, agent_node in coalesce(agent_nodepool.nodes, {}) : can(tonumber(agent_key)) && tonumber(agent_key) == floor(tonumber(agent_key)) && 0 <= tonumber(agent_key) && tonumber(agent_key) < 154])
    ])
    # 154 because the private ip is derived from tonumber(key) + 101. See private_ipv4 in agents.tf
    error_message = "The key for each individual node in a nodepool must be a stable integer in the range [0, 153] cast as a string."
  }

  validation {
    condition = sum([for agent_nodepool in var.ubuntu_agent_nodepools : length(coalesce(agent_nodepool.nodes, {})) + coalesce(agent_nodepool.count, 0)]) <= 100
    # 154 because the private ip is derived from tonumber(key) + 101. See private_ipv4 in agents.tf
    error_message = "Hetzner does not support networks with more than 100 servers."
  }

}
