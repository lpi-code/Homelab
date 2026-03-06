machine:
  type: worker
  certSANs:
    - 127.0.0.1
    - localhost
    - ${node_ip}
  network:
    hostname: ${hostname}
    interfaces:
      - interface: eth0
%{ if use_static_ips ~}
        addresses:
          - ${node_ip}/24
        routes:
          - network: 0.0.0.0/0
            gateway: ${gateway}
%{ else ~}
        dhcp: true
%{ endif ~}
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
  install:
    disk: /dev/vda
    image: ghcr.io/siderolabs/installer:v${talos_version}
  time:
    servers:
      - ${gateway}
      - time.cloudflare.com
      - time.google.com
