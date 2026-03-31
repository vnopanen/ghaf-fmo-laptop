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
  };

  config = mkIf cfg.enable (
    let
      scriptPackage = pkgs.writeShellApplication {
        name = "publish-avahi-ntp";
        runtimeInputs = [
          pkgs.avahi
          pkgs.gawk
          pkgs.ipcalc
        ];
        text = builtins.readFile ./publish-avahi-ntp.sh;
      };
    in
    {
      systemd = {
        paths.fmo-update-avahi-ntp = {
          description = "Monitor the NTP IP address file for Avahi publisher restarts";
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathModified = [ cfg.ipPath ];
            Unit = "fmo-update-avahi-ntp-restart.service";
          };
        };

        services.fmo-update-avahi-ntp = {
          description = "Publish the Avahi NTP host and service";
          enable = true;
          wantedBy = [ "multi-user.target" ];
          after = [ "avahi-daemon.service" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${scriptPackage}/bin/publish-avahi-ntp --ip-path ${cfg.ipPath} --host-name ${cfg.hostName}";
          };
        };

        services.fmo-update-avahi-ntp-restart = {
          description = "Restart the Avahi NTP publisher after IP address changes";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl restart fmo-update-avahi-ntp.service";
          };
        };
      };
    }
  );
}
