#!/usr/bin/env bash
# ECS application deployment. Dependencies: native Bash/coreutils/flock and Docker Compose.
set -euo pipefail
umask 077
root=${1:?}; commit=${2:?}; run_id=${3:?}; repository=${4:?}; registry_user=${5:?}
[[ $root =~ ^/(opt|srv)/[a-zA-Z0-9/_-]+$ && $commit =~ ^[a-f0-9]{40}$ && $run_id =~ ^[1-9][0-9]*$ && $repository =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]] || { echo 'Invalid deployment identity' >&2; exit 1; }
root=${root%/}
release="$root/releases/$commit-$run_id"
config="$root/config"
token_file="$release/registry-token"
docker_auth=''
cleanup() {
    rm -f -- "$token_file"
    if [[ -n $docker_auth ]]; then
        rm -f -- "$docker_auth/config.json"
        rmdir -- "$docker_auth" 2>/dev/null || true
    fi
}
trap cleanup EXIT
# Keep fd9 locked through credential cleanup as well as application replacement.
exec 9>"$root/deploy.lock"
flock -n 9 || { echo 'Another ECS deployment is running' >&2; exit 1; }
for file in server.env backend.env gateway.env; do
    [[ -f "$config/$file" ]] || { echo "Missing private configuration: $file" >&2; exit 1; }
done
[[ -d "$root/logs" && -d "$root/legacy-files" ]] || { echo 'Prepare UID10001 writable directories first' >&2; exit 1; }
while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ^([A-Z][A-Z0-9_]*)= ]]; then
        [[ ${BASH_REMATCH[1]} =~ ^(AI_[A-Z0-9_]+|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY)$ ]] || { echo 'Unexpected gateway credential' >&2; exit 1; }
    fi
done < "$config/gateway.env"
docker version --format '{{.Server.Version}}' >/dev/null
docker compose version >/dev/null
architecture=$(docker info --format '{{.Architecture}}')
[[ $architecture == x86_64 || $architecture == amd64 ]] || { echo 'This release requires an amd64 ECS' >&2; exit 1; }
for service in backend ai-gateway frontend; do
    if owner=$(docker inspect "aisports-dev-ecs-$service" --format '{{index .Config.Labels "aisports.deployment.root"}}' 2>/dev/null); then
        [[ $owner == "$root" ]] || { echo 'Target container belongs to another deployment' >&2; exit 1; }
    fi
done
# Parse only three immutable image values; never execute an env file as shell code.
declare -A images=()
while IFS='=' read -r key value || [[ -n $key ]]; do
    case "$key" in
        BACKEND_IMAGE) service=backend ;;
        FRONTEND_IMAGE) service=frontend ;;
        GATEWAY_IMAGE) service=ai-gateway ;;
        *) echo 'Unexpected image key' >&2; exit 1 ;;
    esac
    [[ ! ${images[$service]+present} ]] || { echo 'Duplicate image key' >&2; exit 1; }
    prefix="ghcr.io/${repository,,}-$service@"
    [[ $value == "$prefix"* && ${value#"$prefix"} =~ ^sha256:[a-f0-9]{64}$ ]] || { echo 'Unexpected or unpinned image' >&2; exit 1; }
    images[$service]=$value
done < "$release/images.env"
[[ ${#images[@]} == 3 ]] || { echo 'Three images are required' >&2; exit 1; }
export BACKEND_IMAGE=${images[backend]} FRONTEND_IMAGE=${images[frontend]} GATEWAY_IMAGE=${images[ai-gateway]}
export ECS_DEPLOY_ROOT="$root" ECS_CONFIG_DIR="$config"
docker_auth=$(mktemp -d "$release/.docker-auth.XXXXXX")
export DOCKER_CONFIG="$docker_auth"
chmod 600 -- "$token_file"
docker login ghcr.io --username "$registry_user" --password-stdin < "$token_file" >/dev/null
compose=(docker compose --project-name aisports-dev-ecs --env-file "$config/server.env" --env-file "$release/images.env" -f "$release/compose.ecs.yml")
"${compose[@]}" config --quiet
# Pull all images before replacing apps. Data services are managed independently.
"${compose[@]}" pull backend ai-gateway frontend
if [[ -f "$root/current-release.json" ]]; then
    cp -- "$root/current-release.json" "$release/previous-release.json"
fi
"${compose[@]}" up -d --force-recreate --wait --wait-timeout 600 backend ai-gateway frontend
for service in backend ai-gateway frontend; do
    actual=$(docker inspect "aisports-dev-ecs-$service" --format '{{.Config.Image}}')
    [[ $actual == "${images[$service]}" ]] || { echo 'Running image differs from approved digest' >&2; exit 1; }
done
docker exec aisports-dev-ecs-frontend wget --quiet --spider http://127.0.0.1:8080/prod-api/auth/code
cp -- "$release/release.json" "$root/current-release.json"
echo 'Approved image digests deployed; data services and other projects retained'
# No automatic application or database rollback after a Flyway migration.
