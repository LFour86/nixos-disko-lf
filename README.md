# NixOS-Disko-LF

[简体中文](./README_CN.md)

This is a tutorial for installing **NixOS** using **Disko declarative partitioning** with **BTRFS** as the filesystem. Write and execute `disko.nix` directly in the NixOS Live ISO to perform GPT partitioning, dual LUKS2 encryption (root + swap), BTRFS subvolume creation, and optimized mount options in one step.

This project features:
- **BTRFS root rollback service** (`rollback`), ensuring impermanence truly yields a pristine root after every reboot.
- Simplified single-password approach (keep the same LUKS passphrase; TPM2 auto‑unlock can be added later for full passwordless boot).
- Optimized BTRFS mount options.
- Fully declarative installation; after setup, disk configuration can be maintained directly with disko.

**Warning**: The following steps will **completely wipe** the target SSD. Back up all data beforehand. The disk is assumed to be `/dev/nvme0n1` (verify with `lsblk -f` and `blkid`).

## Clean Installation

### 1. Prepare the Environment (run as root in NixOS Live ISO)

```bash
# (Optional) configure and update the channel
nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable nixpkgs
nix-channel --update

# Install required tools
nix-env -iA nixos.disko nixos.git nixos.neovim

# Verify disk
lsblk -f
```

### 2. Use the Declarative Disko Configuration

```bash
sudo mkdir -p /mnt/persist/etc/nixos
sudo git clone https://github.com/LFour86/nixos-disko-lf.git
sudo cp nixos-disko-lf/disko.nix ./
```

After saving, run the following command to let Disko **automatically partition, set up LUKS2 encryption, create BTRFS subvolumes, and mount everything** (you will be prompted twice for the LUKS passphrase):

**Note:** Adjust `disko.nix` to suit your needs.

```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /mnt/persist/etc/nixos/disko.nix
```

After execution, all partitions, encrypted containers, and subvolumes are mounted under `/mnt`.

### 3. Generate Configuration and Edit (add rollback service, impermanence, etc.)

```bash
sudo nixos-generate-config --root /mnt

# Overwrite the auto‑generated configuration.nix
sudo cp -r /mnt/persist/etc/nixos/nixos-disko-lf/configuration.nix /mnt/etc/nixos/  # Customize configuration.nix as needed
```

**Note:** Do **not** `imports` the auto‑generated `hardware-configuration.nix`; it conflicts with `disko.nix`.

Save the file.

### 4. Complete Installation

```bash
sudo nixos-install --root /mnt
sudo reboot
```

After reboot, enter the LUKS passphrase **once** (for root); swap will be unlocked automatically. Impermanence with the rollback service ensures a pristine `/` after every reboot.

### 5. Post-Installation Maintenance
- The system is fully declarative. To change disk configuration later, edit `/persist/etc/nixos/disko.nix` and run:
  ```bash
  nix run github:nix-community/disko -- --mode disko /persist/etc/nixos/disko.nix
  ```
Then update the system with `nixos-rebuild`.
