#!/usr/bin/env bash
# Copyright 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

ip_file=""
ntp_host_name=""
address_pid=""
service_pid=""

cleanup() {
  if [[ -n "$service_pid" ]]; then
    kill "$service_pid" 2>/dev/null || true
    wait "$service_pid" 2>/dev/null || true
  fi
  if [[ -n "$address_pid" ]]; then
    kill "$address_pid" 2>/dev/null || true
    wait "$address_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip-path)
      ip_file="$2"
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

if [[ -z "$ip_file" || -z "$ntp_host_name" ]]; then
  echo "Missing required arguments" >&2
  exit 1
fi

if [[ -f "$ip_file" ]]; then
  ip_address="$(gawk 'NF { print $1; exit }' "$ip_file")"
else
  ip_address=""
fi

if [[ -z "$ip_address" ]] || ! ipcalc -c "$ip_address" >/dev/null 2>&1; then
  echo "Invalid or missing IP address in $ip_file" >&2
  exit 1
fi

avahi-publish-address -f "$ntp_host_name" "$ip_address" &
address_pid="$!"

avahi-publish-service -f -H "$ntp_host_name" "NTP Server" _ntp._udp 123 &
service_pid="$!"

wait "$address_pid" "$service_pid"
