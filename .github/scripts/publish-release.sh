#!/usr/bin/env bash
# GitHub Actions: GitHub Release from CDN v* objects, then PUT latest.json,
# LATEST, and 302 objects under download/latest/** → download/vX.Y.Z/**.
# Fail closed if VERSION is bad, CDN prefix is missing, or MinIO secrets are unset.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ ! -f VERSION ]]; then
  echo "missing VERSION" >&2
  exit 1
fi
version="$(tr -d '[:space:]' <VERSION)"
version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be X.Y.Z (got ${version:-empty})" >&2
  exit 1
fi
tag="v${version}"

CDN_PUBLIC_BASE="${CDN_PUBLIC_BASE:-https://cdn.ironwallet.io}"
MINIO_BUCKET="${MINIO_BUCKET:-mcp}"
cdn_prefix="${CDN_PUBLIC_BASE}/${MINIO_BUCKET}/download/${tag}"

for v in MINIO_ENDPOINT MINIO_ACCESS_KEY MINIO_SECRET_KEY MINIO_BUCKET; do
  eval "test -n \"\${$v:-}\"" || {
    echo "missing secret $v" >&2
    exit 1
  }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

code="$(curl -sS -o checksums.txt -w '%{http_code}' "${cdn_prefix}/checksums.txt")"
if [[ "$code" != "200" ]]; then
  echo "CDN ${cdn_prefix}/checksums.txt returned HTTP ${code}; GitLab must publish v* first" >&2
  exit 1
fi

declare -a assets=()
declare -a latest_redirects=()
files_json=""

os_for_name() {
  case "$1" in
    *.exe) echo windows ;;
    *.dmg) echo mac ;;
    *) echo linux ;;
  esac
}

# New prefixes omit version from the object name; older checksums still list -X.Y.Z-.
latest_name() {
  printf '%s\n' "$1" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+-/-/'
}

asset_name() {
  local n="$1"
  if [[ "$n" =~ -[0-9]+\.[0-9]+\.[0-9]+- ]]; then
    printf '%s\n' "$n"
  else
    printf '%s\n' "${n/ironwallet-mcp-installer-/ironwallet-mcp-installer-${version}-}"
  fi
}

while read -r hash name; do
  [[ -n "${hash:-}" && -n "${name:-}" ]] || continue
  os="$(os_for_name "$name")"
  echo "GET ${cdn_prefix}/${os}/${name}"
  curl -fsSL "${cdn_prefix}/${os}/${name}" -o "$name"
  echo "${hash}  ${name}" | sha256sum -c -
  attach="$(asset_name "$name")"
  if [[ "$attach" != "$name" ]]; then
    mv "$name" "$attach"
  fi
  assets+=("$work/$attach")
  latest_redirects+=("download/latest/${os}/$(latest_name "$name")|${cdn_prefix}/${os}/${name}")
  size="$(wc -c <"$attach" | tr -d ' ')"
  arch=amd64
  case "$name" in
    *-arm64*) arch=arm64 ;;
  esac
  url="${cdn_prefix}/${os}/${name}"
  entry=$(printf '{"os":"%s","arch":"%s","name":"%s","url":"%s","size":%s,"sha256":"%s"}' \
    "$os" "$arch" "$attach" "$url" "$size" "$hash")
  if [[ -n "$files_json" ]]; then
    files_json="${files_json},${entry}"
  else
    files_json="$entry"
  fi
done <checksums.txt

if [[ ${#assets[@]} -eq 0 ]]; then
  echo "checksums.txt listed no files" >&2
  exit 1
fi
assets+=("$work/checksums.txt")
latest_redirects+=("download/latest/checksums.txt|${cdn_prefix}/checksums.txt")

if curl -fsSL "${cdn_prefix}/checksums.txt.sig" -o checksums.txt.sig; then
  assets+=("$work/checksums.txt.sig")
  latest_redirects+=("download/latest/checksums.txt.sig|${cdn_prefix}/checksums.txt.sig")
fi
latest_redirects+=("download/latest/|${cdn_prefix}/")

released="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"version":"%s","tag":"%s","released":"%s","files":[%s]}\n' \
  "$version" "$tag" "$released" "$files_json" >latest.json

notes="$(mktemp)"
{
  node "$ROOT/.github/scripts/changelog-section.cjs" "$version" "$ROOT/CHANGELOG.md"
  printf '\n## Downloads\n\n'
  for spec in "${latest_redirects[@]}"; do
    key="${spec%%|*}"
    dest="${spec#*|}"
    [[ "$key" == "download/latest/" ]] && continue
    printf -- '- [%s](%s)\n' "${key##*/}" "$dest"
  done
} >"$notes"

# Downloads live in $work, which is not a git checkout. gh must not infer the
# repo from .git; GITHUB_REPOSITORY is set on Actions.
export GH_REPO="${GITHUB_REPOSITORY:-ironwallet/mcp-installer}"
gh_target=()
if [[ -n "${GITHUB_SHA:-}" ]]; then
  gh_target=(--target "$GITHUB_SHA")
fi

if gh release view "$tag" --repo "$GH_REPO" >/dev/null 2>&1; then
  echo "GitHub Release ${tag} already exists; not mutating assets"
else
  gh release create "$tag" \
    --repo "$GH_REPO" \
    --title "$tag" \
    --notes-file "$notes" \
    "${gh_target[@]}" \
    "${assets[@]}"
  echo "created GitHub Release ${tag}"
fi

export AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY"
export AWS_DEFAULT_REGION="${MINIO_REGION:-us-east-1}"
export AWS_EC2_METADATA_DISABLED=true
export AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

put_latest() {
  echo "PUT ${MINIO_BUCKET}/$1"
  aws s3api put-object \
    --endpoint-url "$MINIO_ENDPOINT" \
    --bucket "$MINIO_BUCKET" \
    --key "$1" \
    --body "$2" \
    --content-type "$3" \
    --cache-control "public,max-age=120" >/dev/null
}

put_latest_redirect() {
  local key="$1" dest="$2"
  echo "PUT ${MINIO_BUCKET}/${key} -> ${dest}"
  aws s3api put-object \
    --endpoint-url "$MINIO_ENDPOINT" \
    --bucket "$MINIO_BUCKET" \
    --key "$key" \
    --website-redirect-location "$dest" \
    --cache-control "public,max-age=120" >/dev/null
}

put_latest download/latest.json latest.json application/json
printf '%s\n' "$tag" >LATEST
put_latest download/LATEST LATEST text/plain

echo "rm s3://${MINIO_BUCKET}/download/latest/"
aws s3 rm "s3://${MINIO_BUCKET}/download/latest/" \
  --recursive \
  --endpoint-url "$MINIO_ENDPOINT" >/dev/null || true

for spec in "${latest_redirects[@]}"; do
  put_latest_redirect "${spec%%|*}" "${spec#*|}"
done

echo "latest: ${CDN_PUBLIC_BASE}/${MINIO_BUCKET}/download/latest.json"
echo "LATEST: ${CDN_PUBLIC_BASE}/${MINIO_BUCKET}/download/LATEST"
echo "version: ${cdn_prefix}/"
