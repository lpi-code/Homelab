machine:
  type: controlplane
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
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:${talos_version}
  kubelet:
    extraArgs:
      {}
  kernel:
    modules:
      - name: br_netfilter
      - name: overlay
  systemDiskEncryption:
    state:
      provider: luks2
      keys:
        - nodeID: {}
      options:
        - no_read_workqueue
        - no_write_workqueue
    ephemeral:
      provider: luks2
      keys:
        - nodeID: {}
      options:
        - no_read_workqueue
        - no_write_workqueue
  time:
    servers:
      - time.cloudflare.com
      - time.google.com
  logging:
    destinations:
      - format: json_lines
        endpoint: tcp://127.0.0.1:31009
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
  proxy:
    disabled: false
  discovery:
    enabled: true
  etcd:
    extraArgs:
      {}
  apiServer:
    certSANs:
      - ${temp_ip}
    extraArgs:
      {}
  controllerManager:
    extraArgs:
      {}
  scheduler:
    extraArgs:
      {}
  coreDNS:
    disabled: false
  inlineManifests: []
  extraManifests: []
  adminKubeconfig:
    certLifetime: 24h0m0s
  allowSchedulingOnControlPlanes: false