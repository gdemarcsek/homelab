# homelab

Simple kubernetes homelab infra for my little intel nuc: `ansible-playbook -K talos-build.yaml`

## 1. Network Topology
- **Core Router**: MikroTik RouterOS v7.
  - Bridge VLAN Filtering enabled.
  - DNS: Secure DoH via Cloudflare with full CA bundle verification (`verify-doh-cert=yes`).
  - Management services: WinBox and SSH restricted to `192.168.88.0/24` (and `192.168.99.0/24` for OOB).
- **Managed Switch**: Zyxel GS1200 series.
  - Port 8: Access mode, untagged VLAN 50 (PVID 50).
- **Physical Segments**:
  - LAN: `192.168.88.0/24` (Trusted personal devices, Mac).
  - DMZ (VLAN 50): `10.50.50.0/24` (Talos, K8s, Fedora server).
  - Guest (VLAN 60): `192.168.60.0/24` (Untrusted Wi-Fi, `wlan-guest`).
  - OOB: `192.168.99.0/24` (Physical off-bridge backdoor port).

## 2. Server & Hypervisor Stack
- **Host**: Intel NUC running Fedora Server 40+.
  - Physical interface: `enp89s0` connected to Zyxel Port 8.
  - Host IP: `10.50.50.11/24` (Default Gateway: `10.50.50.1`).
- **Hypervisor**: KVM / QEMU managed via libvirt.
- **VM Configuration (`talos-k8s`)**:
  - Dual vNIC setup:
    1. Management/Control Plane: `mac=52:54:00:00:00:01` connected to libvirt `network=default` (NAT `192.168.122.0/24`).
    2. Data Plane: `mac=52:54:00:00:00:02` connected via `macvtap` bridge mode to `enp89s0` (VLAN 50, IP `10.50.50.10`).
  - System Extensions: `siderolabs/gvisor`, `siderolabs/kata-containers`.

## 3. Kubernetes & Cilium
- **Talos Version**: v1.7.6.
- **CNI**: Cilium v1.16.1 (Kube-proxy replacement mode enabled).
  - L2 Announcements: Enabled on `enx525400000002` (data plane vNIC).
  - LoadBalancer IP Pool: `10.50.50.200-220`.
  - Target Service: Kata Nginx LoadBalancer (port 80).

## 4. Pending / Next Evolutionary Steps

Kubernetes Control Plane and Data Plane isolation on the architecture level

1. **802.1Q Hypervisor Trunking**:
   - Change Zyxel Port 8 from Access PVID 50 to Trunk (VLAN 40 Tagged, VLAN 50 Tagged).
   - Create Linux bridges on Fedora (`br-mgmt` on VLAN 40, `br-data` on VLAN 50).
   - Eliminate libvirt NAT (`network=default`) and `macvtap` so Control Plane is directly routable from LAN via VLAN 40 (`10.50.40.0/24`).
2. **Multi-node cluster**: Deploy 3 KVM instances of Talos to build a multi-node virtual cluster on the 64GB RAM NUC running Fedora Server. Each node should be given 18 GB of RAM and 4 to 6 vCPUs. Configure VM virtual disk cache to writeback.
3. **Remote Ingress**:
   - Deploy `cloudflared` tunnel as a Kubernetes deployment on the NUC to proxy subdomains to internal LoadBalancer services.
4. **IaC Transition**:
   - Use Terraform with the `bpg/routeros` provider against the RouterOS REST API, backed by SOPS for secret management.
5. **Service Mesh**:
   - Add SPIFFE/SPIRE workload identity, back it with TPM, install a service mesh and improve telemetry. Use ACME for auto TLS and ensure services have domain names to use locally.

## Network Map

```
+-------------------------------------------------------------------------------------------------------+
|                                        PHYSICAL & L2 TOPOLOGY                                         |
+-------------------------------------------------------------------------------------------------------+

                                              [ Internet / WAN ]
                                                      |
                                                      | (ISP Cable -> SageCom ISP Router in PPPoE Passthrough)
                                                      v
                                        +----------------------------+
                                        |   MikroTik Router (Core)   |
                                        |        RouterOS v7         |
                                        +----------------------------+
                                          |          |            |
                     +--------------------+          |            +-----------------------+
                     | (Access PVID 60)              | (Trunk:    | (Dedicated Off-Bridge | (Bridge / Untagged)
                     v                               |  VLAN 50)  |  Emergency Backdoor)  v
            +----------------------+                     |            v                     [ LAN Wi-Fi / Ports ]
            | Virtual AP:          |                     |    +---------------+               - 192.168.88.0/24
            | wlan-guest           |                     |    | etherX (OOB)  |               - MacBook Pro
            | SSID: MikroTik-Guest |                     |    | 192.168.99.1  |               - Trusted Admin
            | Auth: WPA2/WPA3      |                     |    +---------------+
            +----------------------+                     v
                                            +------------------+
                                            |   Zyxel Switch   |
                                            +------------------+
                                                     |
                                                     | Port 8 (Access PVID 50 / Untagged)
                                                     v
                                  +------------------------------------+
                                  |     NUC: Fedora Server 40+         |
                                  | Physical IP: 10.50.50.11 (enp89s0) |
                                  +------------------------------------+
                                    |                                |
         [ libvirt NAT (default) ]  |                                | [ macvtap (bridge mode) ]
         virbr0 (192.168.122.0/24)  |                                | Directly on enp89s0
                                    v                                v
                          +----------------------------------------------------+
                          |               Talos Linux KVM VM                   |
                          |                   (talos-k8s)                      |
                          |                                                    |
                          |  NIC 1 (52:54:00:00:00:01 / enx525400000001)       |
                          |  IP: 192.168.122.x (Control Plane: API / etcd)     |
                          |                                                    |
                          |  NIC 2 (52:54:00:00:00:02 / enx525400000002)       |
                          |  IP: 10.50.50.10 (Data Plane / NodePort)           |
                          |                                                    |
                          |  Cilium CNI (Kube-Proxy Replacement):              |
                          |  - L2 Announcements on NIC 2                       |
                          |  - LoadBalancer VIP Pool: 10.50.50.200-220         |
                          |  - Target App: Kata Nginx (port 80)                |
                          +----------------------------------------------------+

```




