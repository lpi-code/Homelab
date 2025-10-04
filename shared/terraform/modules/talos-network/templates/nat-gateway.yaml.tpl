#cloud-config
package_update: true
package_upgrade: true

packages:
  - iptables
  - iptables-persistent
  - netfilter-persistent
  - curl
  - wget

write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    content: |
      network:
        version: 2
        ethernets:
          ens18:  # Management network (WAN)
            dhcp4: false
            addresses:
              - ${nat_gateway_management_ip}/24
            gateway4: ${management_gateway}
            nameservers:
              addresses:
                - 8.8.8.8
                - 8.8.4.4
          ens19:  # Cluster network (LAN)
            dhcp4: false
            addresses:
              - ${nat_gateway_cluster_ip}/24

  - path: /etc/sysctl.d/99-ip-forwarding.conf
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/iptables/rules.v4
    content: |
      *filter
      :INPUT ACCEPT [0:0]
      :FORWARD ACCEPT [0:0]
      :OUTPUT ACCEPT [0:0]
      
      # Allow established and related connections
      -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
      
      # Allow SSH
      -A INPUT -p tcp --dport 22 -j ACCEPT
      
      # Allow loopback
      -A INPUT -i lo -j ACCEPT
      
      # NAT rules for cluster network
      -A FORWARD -s ${talos_network_cidr} -j ACCEPT
      -A FORWARD -d ${talos_network_cidr} -j ACCEPT
      
      # Drop everything else
      -A INPUT -j DROP
      -A FORWARD -j DROP
      
      COMMIT
      
      *nat
      :PREROUTING ACCEPT [0:0]
      :INPUT ACCEPT [0:0]
      :OUTPUT ACCEPT [0:0]
      :POSTROUTING ACCEPT [0:0]
      
      # NAT cluster network to management network
      -A POSTROUTING -s ${talos_network_cidr} ! -d ${talos_network_cidr} -j MASQUERADE
      
      COMMIT

runcmd:
  - sysctl -p /etc/sysctl.d/99-ip-forwarding.conf
  - netplan apply
  - systemctl enable netfilter-persistent
  - systemctl start netfilter-persistent
  - iptables-restore < /etc/iptables/rules.v4

ssh_authorized_keys:
%{ for key in ssh_public_keys ~}
  - ${key}
%{ endfor ~}

final_message: "NAT Gateway setup complete! Management IP: ${nat_gateway_management_ip}, Cluster IP: ${nat_gateway_cluster_ip}"
