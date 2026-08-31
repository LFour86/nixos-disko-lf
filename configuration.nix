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

  boot.kernelPackages = pkgs.linuxPackages_latest;

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
        
        extraGroups = [ 
          "wheel" 
          "networkmanager" 
          "video" 
          "audio" 
        ];
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

  programs.dconf.enable = true;
  services = {
    gnome.gnome-keyring.enable = true;
    desktopManager = {
      # GNOME
      gnome.enable = true;

      # KDE
      #plasma6.enable = true;
    };
    
    displayManager = {
      defaultSession = "gnome";

      # GDM
      gdm.enable = true;

      # PLM
      #plamsa-login-manager.enable = true;;
    };
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # File system
  fileSystems."/persist".neededForBoot = true;

  # Impermanence
  environment.persistence."/persist" = {
    hideMounts = true;
    
    directories = [
      # Suggested subdirectory breakdown
      "/etc/NetworkManager/system-connections"
      "/etc/nixos"
      "/etc/waydroid-extra"

      # If use SSH: ONLY if host keys are persisted instead of sops-managed
      # (default with ssh.nix = sops host key, so nothing here is needed;
      #  "/etc/ssh" recursively persists all host keys — no extra file entries)
      #"/etc/ssh"

      "/var/lib/AccountsService"
      "/var/lib/bluetooth"
      "/var/lib/cups"
      "/var/lib/hermes"
      "/var/lib/NetworkManager"
      "/var/lib/nixos"
      "/var/lib/systemd/backlight"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/credential"
      "/var/lib/systemd/credentials"
      "/var/lib/systemd/linger"
      "/var/lib/tailscale"
      "/var/log"
    ];
    
    files = [
      "/etc/machine-id"
      "/var/lib/systemd/random-seed"
    ];
  };

  boot.kernelParams = [
    "dm_mod.dm_mq_queue_depth=2048"
  ];

  # BTRFS ephemeral root
  boot.initrd.systemd.enable = true;

  boot.initrd.availableKernelModules = [ "tpm" "tpm_tis" "tpm_crb" ];
    
  boot.initrd.systemd.extraBin = {
    cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
    tpm2_pcrread = "${pkgs.tpm2-tools}/bin/tpm2_pcrread";
  };
  
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
    age
    btrfs-progs 
    clash-verge-rev
    disko
    firefox
    git
    sops
    neovim
    tpm2-tools
  ];

  system.stateVersion = "26.05";
}
