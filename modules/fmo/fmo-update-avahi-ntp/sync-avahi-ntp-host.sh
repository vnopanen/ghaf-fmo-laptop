#!/usr/bin/env bash
# Copyright 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

ip_file=""
target_file=""
ntp_host_name=""
desired_file="$(mktemp)"

cleanup() {
  rm -f "$desired_file"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip-path)
      ip_file="$2"
      shift 2
      ;;
    --hosts-file)
      target_file="$2"
      shift 2
      ;;
    --host-name)
      ntp_host_name="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ip_file" || -z "$target_file" || -z "$ntp_host_name" ]]; then
  echo "Missing required arguments" >&2
  exit 1
fi

if [[ -f "$ip_file" ]]; then
  ip_address="$(gawk 'NF { print $1; exit }' "$ip_file")"
else
  ip_address=""
fi

if [[ -n "$ip_address" ]] && ipcalc -c "$ip_address" >/dev/null 2>&1; then
  printf '%s %s\n' "$ip_address" "$ntp_host_name" > "$desired_file"
else
  : > "$desired_file"
fi

if [[ ! -f "$target_file" ]] || ! cmp -s "$desired_file" "$target_file"; then
  install -m 0644 "$desired_file" "$target_file"
  systemctl try-restart avahi-daemon.service
fi
