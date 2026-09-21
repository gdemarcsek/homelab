#!/bin/bash

virsh destroy talos-k8s 2>/dev/null || true
virsh undefine talos-k8s --remove-all-storage --nvram

rm    ./talosconfig \
      ./kubeconfig \
      ./controlplane.yaml \
      ./worker.yaml \
      ./patch.yaml
