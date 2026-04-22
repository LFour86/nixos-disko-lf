{ config, lib, pkgs, ... }:

{
  imports = [
    # Do not import hardware-configuration.nix
    ./disko.nix
    "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
    "${builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz"}/nixos.nix"
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages;

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Substituters mirrors
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://cache.nixos.org"
      ];
    };
  };

  users = {
    mutableUsers = false;
    users = {
      root = {
        hashedPasswordFile = "/persist/passwords/root";
      };
      lfour = {
        uid = 1000;
        isNormalUser = true;
        hashedPasswordFile = "/persist/passwords/lfour";
        description = "LFour";
        extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
      };
    };
  };

  time.timeZone = "Asia/Shanghai";

  # System locale
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  #programs.dconf.enable = true;
  #services = {
    # Gnome
    #gnome.gnome-keyring.enable = true;
    #desktopManager.gnome.enable = true;
    #displayManager = {
      #defaultSession = "gnome";
      #gdm = {
        #enable = true;
        #wayland = true;
      #};
    #};
  #};

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # File system
  fileSystems."/" = { options = [ "subvol=root" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };
  fileSystems."/home" = { options = [ "subvol=home" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };
  fileSystems."/persist" = {
    options = [ "subvol=persist" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ];
    neededForBoot = true;
  };
  fileSystems."/var/lib/flatpak" = { options = [ "subvol=flatpak" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };
  fileSystems."/nix" = { options = [ "subvol=nix" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };

  # swap
  swapDevices = [ { device = "/dev/mapper/enc-swap"; } ];

  # impermanence
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/log"
      #"/var/lib"  # suggested subdirectory breakdown
      "/var/lib/bluetooth"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/random-seed"
      "/var/lib/libvirt"
      "/var/lib/docker"
      #"var/lib/NetworkManager"
      #"var/lib/lastlog"
      #"/var/lib/systemd/linger"

      "/etc/NetworkManager/system-connections"

      # If use SSH
      "/etc/ssh"
    ];
    files = [
      "/etc/machine-id"

      # If use SSH
      # "/etc/ssh/ssh_host_rsa_key"
      # "/etc/ssh/ssh_host_ed25519_key"
    ];
  };

  boot.kernelParams = [
    "dm_mod.dm_mq_queue_depth=2048"
  ];

  # BTRFS ephemeral root
  boot.initrd.systemd.enable = true;
  
  boot.initrd.systemd.extraBin.btrfs = "${pkgs.btrfs-progs}/bin/btrfs"; # Ensure btrfs tool is available in initrd  
  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    wantedBy = [ "initrd.target" ];
    after = [ "systemd-cryptsetup@enc.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
      set -euo pipefail

      mkdir -p /btrfs_tmp
      mount -o subvolid=5 /dev/mapper/enc /btrfs_tmp

      # Ensure /sysroot is not mounted before we delete the subvolume
      if mountpoint -q /sysroot 2>/dev/null; then
        echo "Warning: /sysroot is already mounted, unmounting it to avoid conflicts..."
        umount /sysroot || true
      fi

      if [[ -d /btrfs_tmp/root ]]; then
        echo "Removing existing root subvolume and all descendants recursively..."
        btrfs subvolume delete -R /btrfs_tmp/root
      fi

      echo "Creating new pristine root subvolume..."
      btrfs subvolume create /btrfs_tmp/root

      umount /btrfs_tmp
      rmdir /btrfs_tmp
  '';
};

  environment.systemPackages = with pkgs; [
    btrfs-progs 
    disko
    git
    neovim
    tpm2-tools
  ];

  system.stateVersion = "25.11";
}
