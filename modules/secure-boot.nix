{
  config,
  pkgs,
  lib,
  ...
}:
let
  enroll-secure-boot = pkgs.writeShellScriptBin "enroll-secure-boot" ''
    set -xeu
    # Allow modification of efivars
    find \
      /sys/firmware/efi/efivars/ \
      \( -name "db-*" -o -name "KEK-*" \) \
      -exec chattr -i {} \;
    esp_keystore="/boot/EFI/KEYS"
    # Append the new allowed signatures, but keep Microsofts and other vendors signatures.
    efi-updatevar -a -f "$esp_keystore/db.auth" db
    # Install Key Exchange Key
    efi-updatevar -f "$esp_keystore/KEK.auth" KEK
    # Install Platform Key (Leaving setup mode and enters user mode)
    efi-updatevar -f "$esp_keystore/PK.auth" PK
  '';

  ensureSecureBootEnrollment = pkgs.writeShellScript "ensure-secure-boot-enrollment" ''
    set -eu

    sb_status="$(bootctl 2>/dev/null \
    | awk '/Secure Boot:/ {print $3 " " $4}')"

    if [ "$sb_status" = "disabled (setup)" ]
    then
      echo "Secure Boot in Setup Mode, enrolling" | systemd-cat -p info
      ${lib.getExe enroll-secure-boot}
      echo "enrolled. Rebooting..." | systemd-cat -p info
      systemctl isolate reboot.target
    elif [ "$sb_status" = "enabled (user)" ]
    then
      echo "Secure Boot active" | systemd-cat -p info
    else
      echo "Secure Boot neither active nor in setup mode. Halting..." | systemd-cat -p crit
      systemctl isolate halt.target
    fi
  '';

in
{
  environment.systemPackages = [
    pkgs.efitools
    enroll-secure-boot
  ];

  boot.initrd.supportedFilesystems.vfat = true;
  boot.initrd.systemd = {
    initrdBin = [
      pkgs.gawk
      pkgs.efitools
    ];

    storePaths = [
      enroll-secure-boot
      ensureSecureBootEnrollment
    ];

    mounts =
      let
        esp = config.image.repart.partitions."00-esp".repartConfig;
      in
      [
        {
          where = "/boot";
          what = "/dev/disk/by-partlabel/${esp.Label}";
          type = esp.Format;
          unitConfig = {
            DefaultDependencies = false;
          };
          requiredBy = [ "initrd-fs.target" ];
          before = [ "initrd-fs.target" ];
        }
      ];

    services = {
      ensure-secure-boot-enrollment = {
        description = "Ensure secure boot is active. If setup mode, enroll. if disabled, halt";
        wantedBy = [ "initrd.target" ];
        before = [ "systemd-repart.service" ];
        unitConfig = {
          AssertPathExists = "/boot/EFI/KEYS";
          RequiresMountsFor = [
            "/boot"
          ];
          DefaultDependencies = false;
          OnFailure = "halt.target";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = ensureSecureBootEnrollment;
        };
      };
    };
  };
}
