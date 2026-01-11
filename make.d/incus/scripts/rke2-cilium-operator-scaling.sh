#!/usr/bin/env -S bash -exu -o pipefail

source <( flox activate --dir /var/lib/rancher/rke2 )

: "Wait for at least one node to be ready"
kubectl wait --for=condition=Ready \
  nodes --all --timeout=300s || exit 0

: "Wait for Cilium DaemonSet to exist"
kubectl wait \
  --for=jsonpath='{.metadata.name}'=cilium \
  daemonset/cilium -n kube-system \
  --timeout=300s || exit 0

: "Wait for Cilium operator deployment to exist"
kubectl wait \
  --for=jsonpath='{.metadata.name}'=cilium-operator \
  deployment/cilium-operator -n kube-system \
  --timeout=300s || exit 0

: "Wait for Cilium DaemonSet to have at least one ready pod"
kubectl wait \
  --for=jsonpath='{.status.numberReady}'=1 \
  daemonset/cilium -n kube-system \
  --timeout=300s || exit 0

: "Dynamic Cilium Operator Scaling"
count=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)
case $count in
1)
  replicas=1;;
2)
  replicas=2;;
*)
  replicas=3;;
esac

: "Scaling cilium-operator to $replicas replicas for $count control plane nodes"
kubectl scale deployment cilium-operator \
  -n kube-system --replicas=$replicas

: "Wait for cilium-operator rollout to complete"
kubectl rollout status \
  deployment/cilium-operator -n kube-system \
  --timeout=1s || true
