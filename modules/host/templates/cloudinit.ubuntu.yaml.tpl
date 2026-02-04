#cloud-config

debug: True

package_update: true
package_upgrade: true
packages:
  - telnet
  - vim
  - open-iscsi
  - nfs-common
  - policycoreutils
  - network-manager

write_files:

${cloudinit_write_files_common}

- path: /etc/netplan/60-my-private-network.yaml
  permissions: "0600"
  content: |
    network:
      version: 2
      renderer: networkd
      ethernets:
        eth1:
          dhcp4: true

# Apply DNS config
%{ if has_dns_servers ~}
manage_resolv_conf: true
resolv_conf:
  nameservers:
%{ for dns_server in dns_servers ~}
    - ${dns_server}
%{ endfor ~}
%{ endif ~}

# Add ssh authorized keys
ssh_authorized_keys:
%{ for key in sshAuthorizedKeys ~}
  - ${key}
%{ endfor ~}

# Make sure the hostname is set correctly
hostname: ${hostname}
preserve_hostname: true

runcmd:

${cloudinit_runcmd_common}

# Configure default routes based on public ip availability
%{if private_network_only~}
# Private-only setup: detect the private interface dynamically
- |
  route_dev() {
    awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
  }
  PRIV_IF=$(ip -4 route get '${network_gw_ipv4}' 2>/dev/null | route_dev)
  if [ -z "$PRIV_IF" ]; then
    PRIV_IF=$(ip -4 route show scope link 2>/dev/null | route_dev)
  fi
  if [ -n "$PRIV_IF" ]; then
    ip route replace default via '${network_gw_ipv4}' dev "$PRIV_IF" metric 100
  else
    echo "WARN: could not determine private interface for default route" >&2
  fi
%{else~}
# Standard setup: detect public interface dynamically (ARM uses enp7s0, x86 uses eth0)
- |
  route_dev() {
    awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
  }
  PUB_IF=$(ip -4 route get 172.31.1.1 2>/dev/null | route_dev)
  # Verify we didn't accidentally pick the private interface (can happen if network_ipv4_cidr overlaps 172.31.0.0/16)
  PRIV_IF=$(ip -4 route get '${network_gw_ipv4}' 2>/dev/null | route_dev)
  if [ -n "$PRIV_IF" ] && [ "$PUB_IF" = "$PRIV_IF" ]; then
    echo "WARN: detected interface $PUB_IF matches private interface, clearing to trigger fallback" >&2
    PUB_IF=""
  fi
  if [ -z "$PUB_IF" ]; then
    echo "WARN: could not detect public interface, falling back to eth0" >&2
    PUB_IF="eth0"
  fi
  ip route replace default via 172.31.1.1 dev "$PUB_IF" metric 100
  ip -6 route replace default via fe80::1 dev "$PUB_IF" metric 100
%{endif~}

- apt remove -y hc-utils
- netplan generate
- netplan apply
- sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
- sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
- systemctl restart ssh
- systemctl stop systemd-resolved
- systemctl disable systemd-resolved
- rm /etc/resolv.conf
- echo "nameserver 1.1.1.1" > /etc/resolv.conf
- echo "nameserver 1.0.0.1" >> /etc/resolv.conf
- echo -e 'blacklist {\n  devnode "^sd[a-z0-9]+"\n}\n' >> /etc/multipath.conf
- systemctl enable iscsid
- ln -s -f bash /bin/sh
- mkdir -p /var/lib/ca-certificates
- echo "$(date) - Terraform deployment successfully finished" > /etc/node-ready
