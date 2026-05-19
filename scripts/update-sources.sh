#!/usr/bin/env bash
set -euo pipefail

repo="${NYM_VPN_REPO:-nymtech/nym-vpn-client}"
api="${GITHUB_API_URL:-https://api.github.com}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

headers=(
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

github_get() {
  curl -fsSL --retry 3 --retry-delay 2 "${headers[@]}" "$1"
}

hash_to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

url_hash() {
  local url="$1"
  local file="$tmp/url-hash-${RANDOM}-${RANDOM}"
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$file"
  nix hash file --type sha256 --sri "$file"
}

asset_url() {
  local release_file="$1"
  local name="$2"
  jq -er --arg name "$name" \
    '.assets[] | select(.name == $name) | .browser_download_url' \
    "$release_file"
}

asset_hash() {
  local release_file="$1"
  local name="$2"
  local digest
  digest="$(
    jq -r --arg name "$name" \
      '.assets[] | select(.name == $name) | .digest // ""' \
      "$release_file"
  )"

  if [[ "$digest" == sha256:* ]]; then
    hash_to_sri "${digest#sha256:}"
    return
  fi

  local checksum_url checksum
  checksum_url="$(asset_url "$release_file" "${name}.sha256sum")"
  checksum="$(github_get "$checksum_url" | awk '{ print $1 }')"
  hash_to_sri "$checksum"
}

release_by_tag() {
  local tag="$1"
  local release_file="$tmp/release-${tag//[^A-Za-z0-9_.-]/_}.json"

  if [[ ! -s "$release_file" ]]; then
    jq -er --arg tag "$tag" '.[] | select(.tag_name == $tag)' "$all_releases" >"$release_file" ||
      github_get "${api}/repos/${repo}/releases/tags/${tag}" >"$release_file"
  fi

  printf '%s\n' "$release_file"
}

asset_name_by_arch() {
  local release_file="$1"
  local prefix="$2"
  local suffix="$3"
  local arch_pattern="$4"

  jq -er \
    --arg prefix "$prefix" \
    --arg suffix "$suffix" \
    --arg arch_pattern "$arch_pattern" \
    '[.assets[].name | select(startswith($prefix) and endswith($suffix) and test($arch_pattern))][0]' \
    "$release_file"
}

all_releases="$tmp/releases.json"
printf '[]' >"$all_releases"

for page in 1 2 3 4 5; do
  page_file="$tmp/releases-page-${page}.json"
  github_get "${api}/repos/${repo}/releases?per_page=100&page=${page}" >"$page_file"

  if [[ "$(jq 'length' "$page_file")" == "0" ]]; then
    break
  fi

  jq -s 'add' "$all_releases" "$page_file" >"$tmp/releases-next.json"
  mv "$tmp/releases-next.json" "$all_releases"
done

selected_release_set="$tmp/selected-release-set.json"
if ! jq -er '
    def stable_tag($kind):
      (.draft | not)
      and (.prerelease | not)
      and (.tag_name | test("^nym-vpn-" + $kind + "-v[0-9]+\\.[0-9]+\\.[0-9]+$"));
    def release_version($kind):
      .tag_name | sub("^nym-vpn-" + $kind + "-v"; "");
    def semver:
      split(".") | map(tonumber);
    def has_asset($name):
      any(.assets[].name; . == $name);
    def has_app_assets($version):
      has_asset("nym-vpn_" + $version + "_linux_x64")
      and has_asset("nym-vpn_" + $version + "_linux_arm64");
    def has_core_assets($version):
      has_asset("nym-vpnd_" + $version + "_amd64.deb")
      and has_asset("nym-vpnd_" + $version + "_arm64.deb")
      and has_asset("nym-vpnc_" + $version + "_amd64.deb")
      and has_asset("nym-vpnc_" + $version + "_arm64.deb");

    [
      .[] | select(stable_tag("app"))
      | . as $release
      | ($release | release_version("app")) as $version
      | select($release | has_app_assets($version))
      | {
          version: $version,
          appTag: $release.tag_name,
          sort: ($version | semver)
        }
    ] as $apps
    | [
      .[] | select(stable_tag("core"))
      | . as $release
      | ($release | release_version("core")) as $version
      | select($release | has_core_assets($version))
      | {
          version: $version,
          coreTag: $release.tag_name,
          sort: ($version | semver)
        }
    ] as $cores
    | [
      $apps[] as $app
      | $cores[] as $core
      | select($app.version == $core.version)
      | {
          version: $app.version,
          appTag: $app.appTag,
          coreTag: $core.coreTag,
          sort: $app.sort
        }
    ]
    | sort_by(.sort)
    | reverse
    | .[0]
  ' "$all_releases" >"$selected_release_set"; then
  echo "Could not find matching stable NymVPN app/core releases in ${repo}" >&2
  exit 1
fi

app_tag="$(jq -er '.appTag' "$selected_release_set")"
core_tag="$(jq -er '.coreTag' "$selected_release_set")"
app_version="$(jq -er '.version' "$selected_release_set")"
core_version="$app_version"

app_release="$(release_by_tag "$app_tag")"
core_release="$(release_by_tag "$core_tag")"

x86_app_binary_name="$(asset_name_by_arch "$app_release" "nym-vpn_${app_version}_linux_" "" '(^|_)(amd64|x64)(\.|$)')"
arm_app_binary_name="$(asset_name_by_arch "$app_release" "nym-vpn_${app_version}_linux_" "" '(^|_)(aarch64|arm64)(\.|$)')"
x86_vpnd_name="$(asset_name_by_arch "$core_release" "nym-vpnd_" ".deb" '(^|_)amd64(\.|$)')"
arm_vpnd_name="$(asset_name_by_arch "$core_release" "nym-vpnd_" ".deb" '(^|_)arm64(\.|$)')"
x86_vpnc_name="$(asset_name_by_arch "$core_release" "nym-vpnc_" ".deb" '(^|_)amd64(\.|$)')"
arm_vpnc_name="$(asset_name_by_arch "$core_release" "nym-vpnc_" ".deb" '(^|_)arm64(\.|$)')"

x86_app_binary_url="$(asset_url "$app_release" "$x86_app_binary_name")"
arm_app_binary_url="$(asset_url "$app_release" "$arm_app_binary_name")"
x86_vpnd_url="$(asset_url "$core_release" "$x86_vpnd_name")"
arm_vpnd_url="$(asset_url "$core_release" "$arm_vpnd_name")"
x86_vpnc_url="$(asset_url "$core_release" "$x86_vpnc_name")"
arm_vpnc_url="$(asset_url "$core_release" "$arm_vpnc_name")"
icon_url="https://raw.githubusercontent.com/${repo}/${app_tag}/nym-vpn-app/.pkg/icon.svg"

x86_app_binary_hash="$(asset_hash "$app_release" "$x86_app_binary_name")"
arm_app_binary_hash="$(asset_hash "$app_release" "$arm_app_binary_name")"
x86_vpnd_hash="$(asset_hash "$core_release" "$x86_vpnd_name")"
arm_vpnd_hash="$(asset_hash "$core_release" "$arm_vpnd_name")"
x86_vpnc_hash="$(asset_hash "$core_release" "$x86_vpnc_name")"
arm_vpnc_hash="$(asset_hash "$core_release" "$arm_vpnc_name")"
icon_hash="$(url_hash "$icon_url")"

jq -n \
  --arg app_tag "$app_tag" \
  --arg app_version "$app_version" \
  --arg core_tag "$core_tag" \
  --arg core_version "$core_version" \
  --arg repo "$repo" \
  --arg release_version "$app_version" \
  --arg release_set_key "${app_tag}/${core_tag}" \
  --arg x86_app_binary_url "$x86_app_binary_url" \
  --arg x86_app_binary_hash "$x86_app_binary_hash" \
  --arg arm_app_binary_url "$arm_app_binary_url" \
  --arg arm_app_binary_hash "$arm_app_binary_hash" \
  --arg icon_url "$icon_url" \
  --arg icon_hash "$icon_hash" \
  --arg x86_vpnd_url "$x86_vpnd_url" \
  --arg x86_vpnd_hash "$x86_vpnd_hash" \
  --arg arm_vpnd_url "$arm_vpnd_url" \
  --arg arm_vpnd_hash "$arm_vpnd_hash" \
  --arg x86_vpnc_url "$x86_vpnc_url" \
  --arg x86_vpnc_hash "$x86_vpnc_hash" \
  --arg arm_vpnc_url "$arm_vpnc_url" \
  --arg arm_vpnc_hash "$arm_vpnc_hash" \
  '{
    releaseSet: {
      key: $release_set_key,
      repo: $repo,
      channel: "stable",
      source: "github-releases",
      version: $release_version,
      pairingStrategy: "highest stable X.Y.Z version present in both app and core releases with required Linux app, vpnc, and vpnd assets",
      appTag: $app_tag,
      coreTag: $core_tag
    },
    app: {
      tag: $app_tag,
      version: $app_version,
      icon: {
        url: $icon_url,
        hash: $icon_hash
      },
      binary: {
        "x86_64-linux": {
          url: $x86_app_binary_url,
          hash: $x86_app_binary_hash
        },
        "aarch64-linux": {
          url: $arm_app_binary_url,
          hash: $arm_app_binary_hash
        }
      }
    },
    vpnc: {
      tag: $core_tag,
      version: $core_version,
      deb: {
        "x86_64-linux": {
          url: $x86_vpnc_url,
          hash: $x86_vpnc_hash
        },
        "aarch64-linux": {
          url: $arm_vpnc_url,
          hash: $arm_vpnc_hash
        }
      }
    },
    vpnd: {
      tag: $core_tag,
      version: $core_version,
      deb: {
        "x86_64-linux": {
          url: $x86_vpnd_url,
          hash: $x86_vpnd_hash
        },
        "aarch64-linux": {
          url: $arm_vpnd_url,
          hash: $arm_vpnd_hash
        }
      }
    }
  }' >"${root}/sources.json"

echo "Updated NymVPN app ${app_version} and core ${core_version}"
