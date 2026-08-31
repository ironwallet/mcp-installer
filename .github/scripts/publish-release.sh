#!/usr/bin/env bash
# GitHub Actions: GitHub Release from CDN v* objects, then PUT latest.json.
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
files_json=""

os_for_name() {
  case "$1" in
    *.exe) echo windows ;;
    *.dmg) echo mac ;;
    *) echo linux ;;
  esac
}

while read -r hash name; do
  [[ -n "${hash:-}" && -n "${name:-}" ]] || continue
  os="$(os_for_name "$name")"
  echo "GET ${cdn_prefix}/${os}/${name}"
  curl -fsSL "${cdn_prefix}/${os}/${name}" -o "$name"
  echo "${hash}  ${name}" | sha256sum -c -
  assets+=("$name")
  size="$(wc -c <"$name" | tr -d ' ')"
  arch=amd64
  case "$name" in
    *-arm64*) arch=arm64 ;;
  esac
  url="${cdn_prefix}/${os}/${name}"
  entry=$(printf '{"os":"%s","arch":"%s","name":"%s","url":"%s","size":%s,"sha256":"%s"}' \
    "$os" "$arch" "$name" "$url" "$size" "$hash")
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
assets+=(checksums.txt)

if curl -fsSL "${cdn_prefix}/checksums.txt.sig" -o checksums.txt.sig; then
  assets+=(checksums.txt.sig)
fi

released="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"version":"%s","tag":"%s","released":"%s","files":[%s]}\n' \
  "$version" "$tag" "$released" "$files_json" >latest.json

notes="$(mktemp)"
{
  if [[ -f "$ROOT/CHANGELOG.md" ]]; then
    awk -v ver="$version" '
      $0 ~ "^## \\[" ver "\\]" {p=1; print; next}
      p && /^## \[/ {exit}
      p {print}
    ' "$ROOT/CHANGELOG.md"
    echo
  fi
  printf 'Canonical downloads: %s/\n' "$cdn_prefix"
} >"$notes"

if gh release view "$tag" >/dev/null 2>&1; then
  echo "GitHub Release ${tag} already exists; not mutating assets"
else
  gh release create "$tag" \
    --title "$tag" \
    --notes-file "$notes" \
    "${assets[@]}"
  echo "created GitHub Release ${tag}"
fi

export AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY"
export AWS_DEFAULT_REGION="${MINIO_REGION:-us-east-1}"
export AWS_EC2_METADATA_DISABLED=true

echo "PUT ${MINIO_BUCKET}/download/latest.json"
aws s3api put-object \
  --endpoint-url "$MINIO_ENDPOINT" \
  --bucket "$MINIO_BUCKET" \
  --key download/latest.json \
  --body latest.json \
  --content-type application/json \
  --cache-control "public,max-age=120" >/dev/null

echo "latest: ${CDN_PUBLIC_BASE}/${MINIO_BUCKET}/download/latest.json"
echo "version: ${cdn_prefix}/"
