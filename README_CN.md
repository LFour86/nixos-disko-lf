# NixOS-Disko-LF

这是一个使用 **Disko 声明式分区** 安装 `NixOS` 的教程，文件系统采用 `BTRFS`。在 NixOS Live ISO 中直接编写并执行 `disko.nix`，一次性完成 GPT 分区、LUKS2 双加密（主分区 + swap）、BTRFS 子卷创建以及高性能挂载选项。

本项目有以下特征/优点：
- 加入 **BTRFS 根目录回滚服务**（`rollback`），确保 impermanence 真正实现“每次重启后根目录纯净”。
- 保留单一密码的简化方案（推荐继续使用相同 LUKS 密码，后续再配 TPM2 自动解锁即可完全免输密码）。
- BTRFS 挂载参数优化。
- 安装流程完全声明式，安装成功后可直接使用 disko 维护磁盘配置。

**警告**：以下操作会**完全擦除**目标 SSD，请提前备份所有数据。假设磁盘为 `/dev/nvme0n1`（请先运行 `lsblk -f` 和 `blkid` 确认设备名）。

## 纯净安装

### 1. 准备环境（在 NixOS Live ISO 终端中以 root 执行）

```bash
# 安装必要工具
nix-env --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/" -iA nixos.git nixos.neovim nixos.mkpasswd

# 确认磁盘
lsblk -f
```

### 2. 使用 Disko 声明式配置文件

```bash
cd /etc/nixos
sudo git clone https://github.com/LFour86/nixos-disko-lf.git
```

然后，执行以下命令让 Disko **自动完成分区、LUKS2 加密、BTRFS 创建及挂载**（整个过程会提示输入两次 LUKS 密码）：

**注意：** 请根据自己的需求来修改 `disko.nix`。

```bash
sudo nix --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/" --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /etc/nixos/nixos-disko-lf/disko.nix
```

执行完成后，所有分区、加密容器和子卷已自动挂载到 `/mnt`。

### 3. 生成配置并编辑（添加回滚服务、impermanence 等）

```bash
sudo nixos-generate-config --root /mnt

# 覆盖自动生成的 configuration.nix
sudo cp -r /etc/nixos/nixos-disko-lf/configuration.nix /mnt/etc/nixos/  # 注意个性化修改configuration.nix
```

**注意：** 不要 `imports` 自动生成的 `hardware-configuration.nix`，其与 `disko.nix` 冲突。

**预设用户密码（安全声明式方案）**

由于系统开启了根目录回滚，为了防止重启后账户密码丢失，我们需要在安装前将密码哈希持久化到 /persist 目录。

```bash
# 创建存放密码的持久化目录
sudo mkdir -p /mnt/persist/passwords

# 生成你的用户密码哈希（替换 lfour 为你的用户名）
# 输入命令后会提示你输入并确认密码
mkpasswd -m sha-512 | sudo tee /mnt/persist/passwords/lfour

# 生成 root 用户密码哈希
mkpasswd -m sha-512 | sudo tee /mnt/persist/passwords/root

# 设置严格权限，确保安全
sudo chmod 700 /mnt/persist/passwords
sudo chmod 600 /mnt/persist/passwords/*
```

保存文件。

### 4. 完成安装

```bash
sudo nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/" --root /mnt
sudo reboot
```

重启后，引导时只需输入**一次** LUKS 密码（主分区），swap 会自动跟随解锁。impermanence + rollback 服务将确保每次重启后 `/` 目录保持纯净状态。

### 5. 安装成功后的维护
- 系统已完全声明式，后续磁盘变更可直接修改 `/persist/etc/nixos/disko.nix` 并运行：
  ```bash
  disko -- --mode disko /persist/etc/nixos/disko.nix
  ```
然后使用 `nixos-rebuild` 命令更新系统。
