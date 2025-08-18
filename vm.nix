# Settings which should only be applied if run as a VM, not on bare metal.
{
  lib,
  config,
  modulesPath,
  ...
}:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
  config = {
    virtualisation = {
      diskSize = 300 * 1024;
      memorySize = 64 * 1024;
      cores = 32;

      # Don't use direct boot for the VM to verify that the bootloader is working.
      directBoot.enable = false;
      installBootLoader = false;
      useBootLoader = true;
      useEFIBoot = true;
      mountHostNixStore = false;
      efi.keepVariables = false;

      # NixOS overrides filesystems for VMs by default
      fileSystems = lib.mkForce { };
      useDefaultFilesystems = false;

      # Start a headless VM with serial console.
      graphics = false;
    };
  };
}
