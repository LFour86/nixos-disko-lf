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
        #initialPassword = "your_password";
        hashedPasswordFile = "/persist/passwords/root";
      };
      lfour = {
        isNormalUser = true;
        #initialPassword = "your_password";
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
  fileSystems."/" = { options = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };
  fileSystems."/home" = { options = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };
  fileSystems."/persist" = {
    options = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ];
    neededForBoot = true;
  };
  fileSystems."/var/lib/flatpak" = { options = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };
  fileSystems."/nix" = { options = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };

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
    after = [ "systemd-cryptsetup@enc.service" ]; # Run after LUKS partition is decrypted
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      # Create a temporary mount point
      mkdir -p /btrfs_tmp
      
      # Mount the BTRFS root (subvolid=5) to access all subvolumes
      mount -o subvolid=5 /dev/mapper/enc /btrfs_tmp

      # Check if the root subvolume exists
      if [[ -d /btrfs_tmp/root ]]; then
        echo "Cleaning up existing root subvolume and its children..."
        
        # List all subvolumes under /root, extract paths, sort in reverse order (deepest first)
        # and delete them one by one to avoid "directory not empty" errors
        btrfs subvolume list -o /btrfs_tmp/root | awk '{print $NF}' | sort -r | while read -r subvolume; do
          echo "Deleting nested subvolume: $subvolume"
          btrfs subvolume delete "/btrfs_tmp/$subvolume"
        done
        
        # Finally delete the root subvolume itself
        echo "Deleting /root subvolume..."
        btrfs subvolume delete /btrfs_tmp/root
      fi

      # Create a new, empty root subvolume for a fresh boot
      echo "Creating new pristine root subvolume..."
      btrfs subvolume create /btrfs_tmp/root

      # Clean up: unmount and remove the temporary directory
      umount /btrfs_tmp
      rmdir /btrfs_tmp
    '';
  };


  environment.systemPackages = with pkgs; [
    disko
    git
    neovim
    tpm2-tools
  ];

  system.stateVersion = "25.11";
}
