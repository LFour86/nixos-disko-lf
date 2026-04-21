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

  users.users.lfour = {
    isNormalUser = true;
    description = "LFour";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
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
  fileSystems."/nix" = { options = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ]; };

  # swap
  swapDevices = [ { device = "/dev/mapper/enc-swap"; } ];

  # impermanence
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/log"
      "/var/lib"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  boot.kernelParams = [
    "dm_mod.dm_mq_queue_depth=2048"
  ];

  boot.initrd.secrets = {
    "/persist/etc/luks-swap.key" = "/persist/etc/luks-swap.key";
  };

  # BTRFS ephemeral root
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    wantedBy = [ "initrd.target" ];
    after = [ "systemd-cryptsetup@enc.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /btrfs_tmp
      mount -o subvolid=5 /dev/mapper/enc /btrfs_tmp

      if [[ -d /btrfs_tmp/root ]]; then
        echo "Deleting old root subvolume..."
        btrfs subvolume delete -r /btrfs_tmp/root 2>/dev/null || true
      fi

      echo "Creating new pristine root subvolume..."
      btrfs subvolume create /btrfs_tmp/root

      umount /btrfs_tmp
      rmdir /btrfs_tmp || true
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
