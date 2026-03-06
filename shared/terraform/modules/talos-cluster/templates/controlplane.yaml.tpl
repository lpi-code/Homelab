machine:
  type: controlplane
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
cluster:
  controlPlane:
    endpoint: ${cluster_endpoint}
  clusterName: ${cluster_name}
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  discovery:
    enabled: true
  allowSchedulingOnControlPlanes: false
