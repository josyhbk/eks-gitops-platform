#!/usr/bin/env bash
# Wait until every Argo CD Application the root renders is Synced and Healthy,
# with no sync still running (hooks such as admission webhook jobs count).
# Exit 1 with the stragglers listed after TIMEOUT seconds (default 900).
set -euo pipefail
timeout=${TIMEOUT:-900}
end=$((SECONDS + timeout))
done_re=' Synced Healthy (Succeeded)?$'  # the phase is empty until a first sync runs

while :; do
  expected=$(kubectl -n argocd get application root -o jsonpath='{range .status.resources[*]}{.name}{"\n"}{end}' 2>/dev/null | grep -c . || true)
  status=$(kubectl -n argocd get applications -o jsonpath='{range .items[*]}{.metadata.name} {.status.sync.status} {.status.health.status} {.status.operationState.phase}{"\n"}{end}')
  pending=$(grep -Ev "$done_re" <<<"$status" || true)
  ready=$(grep -Ec "$done_re" <<<"$status" || true)
  # root plus every child it lists
  if [[ $expected -gt 0 && -z $pending && $ready -eq $((expected + 1)) ]]; then
    echo "all $ready applications synced and healthy"
    exit 0
  fi
  if ((SECONDS >= end)); then
    echo "timed out after ${timeout}s, not ready:" >&2
    echo "${pending:-root has not listed its children yet}" >&2
    exit 1
  fi
  sleep 10
done
