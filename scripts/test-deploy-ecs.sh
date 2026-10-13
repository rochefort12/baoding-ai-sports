#!/usr/bin/env bash
# Isolated Linux test harness: fake Docker only, no registry, SSH or data service calls.
set -euo pipefail
root=/opt/aisports-ci-test
commit=$(printf 'a%.0s' {1..40})
digest=$(printf 'b%.0s' {1..64})
release="$root/releases/$commit-12345"
mkdir -p "$root/bin" "$root/config" "$root/logs" "$root/legacy-files" "$release"
export MOCK_ROOT="$root" MOCK_LOG="$root/docker.log"
export PATH="$root/bin:$PATH"
cat > "$root/bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG"
case "$1" in
    version) echo 29.0.0 ;;
    info) echo x86_64 ;;
    login) cat >/dev/null; printf '{}\n' > "$DOCKER_CONFIG/config.json" ;;
    inspect)
        if [[ $* == *'.Config.Image'* ]]; then
            case "$2" in
                *-backend) key=BACKEND_IMAGE ;;
                *-frontend) key=FRONTEND_IMAGE ;;
                *-ai-gateway) key=GATEWAY_IMAGE ;;
            esac
            grep "^$key=" "$MOCK_ROOT"/releases/*/images.env | cut -d= -f2-
        elif [[ ${MOCK_FOREIGN_OWNER:-0} == 1 ]]; then echo /opt/other-deployment
        else echo "$MOCK_ROOT"; fi ;;
    compose)
        if [[ " $* " == *' pull '* && ${MOCK_FAIL_PULL:-0} == 1 ]]; then exit 42; fi ;;
    exec) : ;;
    *) echo 'Unexpected Docker command' >&2; exit 1 ;;
esac
MOCK
chmod 700 "$root/bin/docker"
printf '# synthetic config\n' > "$root/config/server.env"
printf '# synthetic config\n' > "$root/config/backend.env"
printf 'AI_INTERNAL_TOKEN=synthetic-not-a-real-secret\n' > "$root/config/gateway.env"
printf '{"synthetic":true}\n' > "$release/release.json"
printf '# synthetic compose\n' > "$release/compose.ecs.yml"
prepare() {
    : > "$MOCK_LOG"
    printf 'synthetic-not-a-real-token\n' > "$release/registry-token"
    printf 'BACKEND_IMAGE=ghcr.io/example/aisports-backend@sha256:%s\nFRONTEND_IMAGE=ghcr.io/example/aisports-frontend@sha256:%s\nGATEWAY_IMAGE=ghcr.io/example/aisports-ai-gateway@sha256:%s\n' "$digest" "$digest" "$digest" > "$release/images.env"
}
invoke() { bash /scripts/deploy-ecs.sh "$root" "$commit" 12345 example/AISports ci-user; }
assert_clean() { [[ ! -f "$release/registry-token" ]]; [[ -z $(find "$release" -path '*/.docker-auth.*/config.json' -print) ]]; }
assert_not_updated() {
    if grep -q -- ' up ' "$MOCK_LOG"; then echo 'Applications changed before validation passed' >&2; return 1; fi
    assert_clean
}
prepare
invoke
cmp "$release/release.json" "$root/current-release.json"
assert_clean
if grep -Eq '(^| )(down|prune)( |$)' "$MOCK_LOG"; then echo 'Unexpected data-lifecycle operation' >&2; exit 1; fi
prepare
if MOCK_FAIL_PULL=1 invoke; then echo 'Pull failure was accepted' >&2; exit 1; fi
assert_not_updated
prepare
printf 'BACKEND_IMAGE=ghcr.io/example/aisports-backend:latest\n' > "$release/images.env"
if invoke; then echo 'Floating image was accepted' >&2; exit 1; fi
assert_not_updated
prepare
if MOCK_FOREIGN_OWNER=1 invoke; then echo 'Foreign owner was accepted' >&2; exit 1; fi
assert_not_updated
prepare
exec 8>"$root/deploy.lock"
flock -n 8
if invoke; then echo 'Concurrent deployment was accepted' >&2; exit 1; fi
exec 8>&-
assert_not_updated
echo 'PASS: five simulated native Linux deployment scenarios, no real deployment'
