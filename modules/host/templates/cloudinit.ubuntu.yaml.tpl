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
