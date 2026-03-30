# Copyright 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.fmo-update-avahi-ntp;

  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.services.fmo-update-avahi-ntp = {
    enable = mkEnableOption "";
    hostName = mkOption {
      description = "Dedicated Avahi host name for the NTP service";
      type = types.str;
      default = "pmc-net-vm-ntp.local";
    };
    ipPath = mkOption {
      description = "Path to the file containing the NTP service IP address";
      type = types.path;
      default = "/var/common/ip-address";
    };
    hostsFile = mkOption {
      description = "Path to the Avahi hosts file";
      type = types.path;
      default = "/etc/avahi/hosts";
    };
  };

  config = mkIf cfg.enable (
    let
      scriptPackage = pkgs.writeShellApplication {
        name = "sync-avahi-ntp-host";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.diffutils
          pkgs.gawk
          pkgs.ipcalc
          pkgs.systemd
        ];
        text = builtins.readFile ./sync-avahi-ntp-host.sh;
      };
    in
    {
      systemd = {
        paths.fmo-update-avahi-ntp = {
          description = "Monitor the NTP IP address file for Avahi updates";
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathModified = [ cfg.ipPath ];
          };
        };

        services.fmo-update-avahi-ntp = {
          description = "Update the Avahi NTP host mapping";
          enable = true;
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${scriptPackage}/bin/sync-avahi-ntp-host --ip-path ${cfg.ipPath} --hosts-file ${cfg.hostsFile} --host-name ${cfg.hostName}";
          };
        };
      };
    }
  );
}
