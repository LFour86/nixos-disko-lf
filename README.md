# NixOS-Disko-LF

[简体中文](./README_CN.md)

This is a tutorial for installing `NixOS` with **declarative partitioning using Disko**, using the `BTRFS` filesystem. Directly write and execute a `disko.nix` on a NixOS Live ISO to complete GPT partitioning, LUKS2 dual encryption (main partition + swap), BTRFS subvolume creation, and high-performance mount options in one step.

This project has the following features/advantages:

- Add a **BTRFS root rollback service** (`rollback`), ensuring that impermanence truly achieves a “pristine root directory after every reboot”.
- Keep the simplified single password scheme (recommend continuing with the same LUKS password; later, configure TPM2 auto-unlock to completely eliminate password entry).
- Optimize BTRFS mount parameters.
- Fully declarative installation flow; after successful installation, you can use Disko directly to maintain the disk configuration.

**Warning**: The following operation will **completely erase** the target SSD. Back up all data beforehand. The disk is assumed to be `/dev/nvme0n1` (run `lsblk -f` and `blkid` first to confirm the device name).

## Clean Installation

### 1. Prepare the Environment (in the NixOS Live ISO terminal)

```bash
# Install necessary tools
nix-env -iA nixos.git nixos.neovim nixos.mkpasswd

# Confirm the disk
lsblk -f
```

### 2. Use the Disko Declarative Configuration

```bash
cd /etc/nixos
sudo git clone https://github.com/LFour86/nixos-disko-lf.git
```

Then run the following command to let Disko **automatically complete partitioning, LUKS2 encryption, BTRFS creation, and mounting** (you will be prompted to enter the LUKS password twice during the process):

**Note:** Modify `disko.nix` according to your own needs.

```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /etc/nixos/nixos-disko-lf/disko.nix
```

When execution finishes, all partitions, encrypted containers, and subvolumes are automatically mounted at `/mnt`.

### 3. Generate and Edit Configuration

```bash
sudo nixos-generate-config --root /mnt

# Overwrite the automatically generated configuration.nix
sudo cp -r /etc/nixos/nixos-disko-lf/configuration.nix /mnt/etc/nixos/  # Remember to personalize configuration.nix
```

**Note:** Do not `imports` the automatically generated `hardware-configuration.nix`; it conflicts with `disko.nix`.

**Preset User Passwords**

Since the system enables root rollback, we need to persist password hashes to the `/persist` directory before installation to prevent losing account passwords after a reboot.

```bash
# Create the persistent directory for passwords
sudo mkdir -p /mnt/persist/passwords

# Generate the password hash for your user (replace lfour with your username)
# After executing the command, you will be prompted to enter and confirm the password
mkpasswd -m sha-512 | sudo tee /mnt/persist/passwords/lfour

# Generate the password hash for the root user
mkpasswd -m sha-512 | sudo tee /mnt/persist/passwords/root

# Set strict permissions to ensure security
sudo chmod 700 /mnt/persist/passwords
sudo chmod 600 /mnt/persist/passwords/*
```

### 4. Complete the Installation

```bash
sudo nixos-install --root /mnt
sudo reboot
```

After rebooting, you only need to enter the LUKS password **once** (for the main partition) during boot; swap will automatically be unlocked as well. The impermanence + rollback service ensures that the `/` directory remains pristine after every restart.

