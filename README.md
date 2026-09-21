# homelab

Simple kubernetes homelab infra for my little intel nuc: `ansible-playbook -K talos-build.yaml`

To tear down, run `sudo bash cleanup.sh`

## setup

 - Kubernetes: Talos installed on a KVM instance with gvisor and kata container extensions enabled
 - Dual NIC setup: (1) management interface on libvirt NAT (kubectl and Internet egress), (2) data plane interface bridged directly to home LAN using macvtap (handles all inbound traffic) -- this piggybacking is not nice but I might need some hardware upgrades before I can do better
 - Cilium: Replaces kube-proxy and denies egress from pods to home LAN via network policy and routing through libvirt NAT

## todo
 - adopt for DMZ VLAN (install the old switch from the cupboard...)
 - remove some hard-coded names and IPs (use more templating)

