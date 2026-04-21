{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "16G";
              content = {
                type = "luks";
                name = "enc-swap";
                extraFormatArgs = [ "--cipher" "aes-xts-plain64" "--key-size" "512" ];
                #crypttabExtraOpts = [ "tpm2-device=auto" ];
                content = {
                  type = "swap";
                };
              };
            };
            nixos = {
              size = "100%";
              content = {
                type = "luks";
                name = "enc";
                extraFormatArgs = [ "--cipher" "aes-xts-plain64" "--key-size" "512" ];
                #crypttabExtraOpts = [ "tpm2-device=auto" ];
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "nixos" ];
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ];
                    };
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ];
                    };
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ];
                      neededForBoot = true;
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd:3" "noatime" "discard=async" "space_cache=v2" "ssd" "commit=120" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
