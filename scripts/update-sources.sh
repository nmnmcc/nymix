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
    def has_any_asset($names):
      any(.assets[].name; . as $asset | any($names[]; . == $asset));
    def has_app_assets($version):
      has_any_asset([
        "NymVPN_" + $version + "_amd64.AppImage",
        "NymVPN_" + $version + "_x64.AppImage"
      ])
      and has_any_asset([
        "NymVPN_" + $version + "_aarch64.AppImage",
        "NymVPN_" + $version + "_arm64.AppImage"
      ]);
    def has_core_assets($version):
      has_asset("nym-vpnd_" + $version + "_amd64.deb")
      and has_asset("nym-vpnd_" + $version + "_arm64.deb");

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
          daemonTag: $release.tag_name,
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
          daemonTag: $core.daemonTag,
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
daemon_tag="$(jq -er '.daemonTag' "$selected_release_set")"
app_version="$(jq -er '.version' "$selected_release_set")"
daemon_version="$app_version"

app_release="$(release_by_tag "$app_tag")"
daemon_release="$(release_by_tag "$daemon_tag")"

x86_app_name="$(asset_name_by_arch "$app_release" "NymVPN_${app_version}_" ".AppImage" '(^|_)(amd64|x64)(\.|$)')"
arm_app_name="$(asset_name_by_arch "$app_release" "NymVPN_${app_version}_" ".AppImage" '(^|_)(aarch64|arm64)(\.|$)')"
x86_daemon_name="$(asset_name_by_arch "$daemon_release" "nym-vpnd_" ".deb" '(^|_)amd64(\.|$)')"
arm_daemon_name="$(asset_name_by_arch "$daemon_release" "nym-vpnd_" ".deb" '(^|_)arm64(\.|$)')"

x86_app_url="$(asset_url "$app_release" "$x86_app_name")"
arm_app_url="$(asset_url "$app_release" "$arm_app_name")"
x86_daemon_url="$(asset_url "$daemon_release" "$x86_daemon_name")"
arm_daemon_url="$(asset_url "$daemon_release" "$arm_daemon_name")"

x86_app_hash="$(asset_hash "$app_release" "$x86_app_name")"
arm_app_hash="$(asset_hash "$app_release" "$arm_app_name")"
x86_daemon_hash="$(asset_hash "$daemon_release" "$x86_daemon_name")"
arm_daemon_hash="$(asset_hash "$daemon_release" "$arm_daemon_name")"

jq -n \
  --arg app_tag "$app_tag" \
  --arg app_version "$app_version" \
  --arg daemon_tag "$daemon_tag" \
  --arg daemon_version "$daemon_version" \
  --arg repo "$repo" \
  --arg release_version "$app_version" \
  --arg release_set_key "${app_tag}/${daemon_tag}" \
  --arg x86_app_url "$x86_app_url" \
  --arg x86_app_hash "$x86_app_hash" \
  --arg arm_app_url "$arm_app_url" \
  --arg arm_app_hash "$arm_app_hash" \
  --arg x86_daemon_url "$x86_daemon_url" \
  --arg x86_daemon_hash "$x86_daemon_hash" \
  --arg arm_daemon_url "$arm_daemon_url" \
  --arg arm_daemon_hash "$arm_daemon_hash" \
  '{
    releaseSet: {
      key: $release_set_key,
      repo: $repo,
      channel: "stable",
      source: "github-releases",
      version: $release_version,
      pairingStrategy: "highest stable X.Y.Z version present in both app and core releases with required Linux assets",
      appTag: $app_tag,
      daemonTag: $daemon_tag
    },
    app: {
      tag: $app_tag,
      version: $app_version,
      appImage: {
        "x86_64-linux": {
          url: $x86_app_url,
          hash: $x86_app_hash
        },
        "aarch64-linux": {
          url: $arm_app_url,
          hash: $arm_app_hash
        }
      }
    },
    daemon: {
      tag: $daemon_tag,
      version: $daemon_version,
      deb: {
        "x86_64-linux": {
          url: $x86_daemon_url,
          hash: $x86_daemon_hash
        },
        "aarch64-linux": {
          url: $arm_daemon_url,
          hash: $arm_daemon_hash
        }
      }
    }
  }' >"${root}/sources.json"

echo "Updated NymVPN app ${app_version} and daemon ${daemon_version}"
