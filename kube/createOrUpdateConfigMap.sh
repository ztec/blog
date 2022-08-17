#!/bin/sh
kubectl create configmap nginx-config \
  --from-file=nginx.conf --from-file=default.conf \
  -n trantor \
  -o yaml \
  --dry-run=client | kubectl apply -f -
