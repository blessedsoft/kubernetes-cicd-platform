#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${1:?namespace is required}"
IMAGE="${2:?image is required}"
TIMEOUT="${DEPLOY_TIMEOUT:-5m}"

kubectl -n "$NAMESPACE" apply -f "k8s/$NAMESPACE.yaml"
kubectl -n "$NAMESPACE" set image deployment/sec-project app="$IMAGE"

if ! kubectl -n "$NAMESPACE" rollout status deployment/sec-project --timeout="$TIMEOUT"; then
  echo "Deployment failed; rolling back"
  kubectl -n "$NAMESPACE" rollout undo deployment/sec-project
  kubectl -n "$NAMESPACE" rollout status deployment/sec-project --timeout="$TIMEOUT" || true
  echo "Rollback completed for $NAMESPACE"
  exit 1
fi

kubectl -n "$NAMESPACE" wait --for=condition=available deployment/sec-project --timeout="$TIMEOUT"
echo "Deployment healthy: $NAMESPACE -> $IMAGE"
echo "Notification: sec-project deployed successfully to $NAMESPACE"
