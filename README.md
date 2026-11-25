# dotfile-nixos

Noctalia Family（Umbriel + Noctalia + Noctalia Greeter）を載せた 2 ホストの
NixOS flake です。GitHub Actions が毎週 `flake.lock` を更新して全ホストを
ビルドし、成功したロックだけをリモートへコミットします。各マシンはその
リモートを正として、毎週 `nixos-rebuild boot` で次の起動世代を用意します。

- **sashi-main** — desktop / gaming / development / compute
- **sashi-letsnote** — laptop / browsing / development

> 旧構成のホスト名 `sashi-mainpc` は `sashi-main` に改名しています。
> 実際の `hostname` を変えるまでは `./rebuild.sh` が旧名を自動で読み替えます。

## ディレクトリ構成

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   ├── sashi-main/
│   │   ├── default.nix              # ホストの import とオプション有効化
│   │   ├── hardware-configuration.nix
│   │   ├── hardware.nix             # r8125 / v4l2loopback / iGPU 無効化
│   │   ├── keychron.nix, fiio.nix   # 周辺機器の udev ルール
│   │   ├── home.nix
│   │   ├── umbriel.nix              # 3 モニタ固有の出力・workspace 設定
│   │   └── noctalia.nix             # バー・壁紙・ロック画面
│   └── sashi-letsnote/
│       ├── default.nix
│       ├── hardware-configuration.nix  # ★ 実機の生成結果に置き換える
│       ├── home.nix
│       └── noctalia.nix
├── system/
│   ├── boot/                        # systemd-boot, CachyOS kernel, BBR3
│   ├── core/                        # Nix/ロケール/ユーザー/自動更新/GC/polkit/shred
│   ├── develop/                     # nix-ld, 開発 CLI, libvirt (任意)
│   ├── network/                     # NM, resolved, Avahi, Tailscale, SearXNG
│   ├── graphics/                    # ベンダー非依存の graphics 基盤
│   ├── nvidia/                      # NVIDIA driver, VA-API, OpenCL, 環境変数
│   └── desktop-environment/         # Umbriel/Noctalia Greeter/PipeWire/IME/gaming
├── sashi/
│   ├── core/                        # 両ホスト共通の home-manager 設定
│   ├── gaming/                      # sashi-main のみ
│   └── lib/                         # Umbriel/Noctalia の共通設定（純粋な関数）
├── packages/
│   ├── mozkey/                      # fcitx5-mozkey のパッケージ定義
│   └── rename-music-by-tags/        # 旧 path: input をリポジトリ内へ移動
├── .github/workflows/update-flake.yml
└── rebuild.sh
```

## モジュール分類

### `system/boot`

| 分類 | 内容 |
| --- | --- |
| option | `boot.loader.systemd-boot`, EFI variables |
| option | `sashi.boot.cachyos.enable`（既定 `true`） |
| option | `sashi.boot.cachyos.nativeOptimization`（既定 `false`） |
| package | `linuxPackages_cachyos-bore` |
| option | `tcp_bbr3` の読み込みと `net.ipv4.tcp_congestion_control = "bbr3"` |
| overlay | Linux 7.2 以降の `modules.cer` 不在に対する kernel module aggregator 修正 |

`nativeOptimization` は現在の構成では **無効** です。`-march=native` を有効に
するとカーネルの derivation がビルドした CPU に依存し、GitHub Actions が
ビルドした成果物とホストがインストールする成果物が一致しなくなります。
リモートを正とする構成では無効のままを推奨します。

### `system/core`

| 分類 | 内容 |
| --- | --- |
| option | `nix.settings`（flakes, trusted-users, `accept-flake-config`） |
| option | `nixpkgs.config.allowUnfree`, CA blacklist |
| option | `time.timeZone`, `i18n` ロケール |
| option | `users.users.sashi`（`networkmanager`, `wheel`） |
| package | `fuse3`, `appimage-run`（libicu 追加） |
| option | `programs.ssh.enableAskPassword`, `yubikey-touch-detector` |
| option | `services.pcscd` |
| option | `security.polkit` |
| module | `gc.nix`, `shred.nix`, `auto-upgrade.nix` |

### `system/develop`

| 分類 | 内容 |
| --- | --- |
| option | `programs.nix-ld` + `icu/openssl/zlib/curl/libunwind/fuse` |
| package | `git`, `openssh`, `vim-full`, `gcc`, `gnumake`, `pkg-config`, `jq`, `ripgrep`, `fd`, `unzip`, `zip` |
| package | `rename-music-by-tags`（リポジトリ内パッケージ） |
| option | `sashi.develop.virtualisation.enable`（既定 `false`） |
| option | libvirt/QEMU, virt-manager, spice USB, virbr0:5000, dconf |

### `system/network`

| 分類 | 内容 |
| --- | --- |
| option | NetworkManager + systemd-resolved（mDNS, LLMNR off, DNSSEC off） |
| option | Avahi（nssmdns4, firewall 開放） |
| option | Tailscale |
| option | ローカル専用 SearXNG（`127.0.0.1:8080`, JSON API） |

### `system/graphics`

| 分類 | 内容 |
| --- | --- |
| option | `hardware.graphics.enable`, `enable32Bit` |

### `system/nvidia`

| 分類 | 内容 |
| --- | --- |
| option | `services.xserver.videoDrivers = [ "nvidia" ]` |
| option | open kernel module, modesetting, nvidia-settings |
| package | `nvidia-vaapi-driver`, `ocl-icd` |
| option | `OpenCL/vendors/nvidia.icd` の登録 |
| env | `LIBVA_*`, `LD_LIBRARY_PATH`, `NVD_BACKEND`, `GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME` など |

### `system/desktop-environment`

| 分類 | 内容 |
| --- | --- |
| option | `programs.umbriel` |
| option | `services.displayManager.noctalia-greeter` |
| option | PipeWire（44.1–768 kHz, resample quality 15） |
| option | CUPS, Flatpak, gvfs, udisks2, tumbler, dconf |
| option | Firefox（VA-API 有効化） |
| package | `obs-studio` |
| option | fcitx5 + Mozkey（`ime.nix`） |
| env | `QT_QPA_PLATFORMTHEME=qt6ct`, `NIXOS_OZONE_WL` など |
| option | `sashi.desktop.gaming.enable`（Steam/Gamescope/AAGL） |
| option | `sashi.desktop.gamescopeVulkanDevice` |

### `sashi/core`（home-manager）

| 分類 | 内容 |
| --- | --- |
| package | `keepassxc`, `yubioath-flutter`, `thunderbird`, `tor-browser`, `opencode`, `uv`, `nodejs_22`, `arduino-ide`, `nautilus`, `foot` など |
| package | `mpd`, `euphonica`, `picard`, `whipper` ラッパー, `mkvtoolnix` |
| option | Flatpak remotes / apps / Peergos override |
| option | MIME apps, GTK/dconf, pointer cursor |
| option | rclone の keepass/taildrive マウント, MPD user unit |
| option | `programs.noctalia.enable`（設定はホスト側）, `aria2`, `qbittorrent` |
| option | SSH/Git/GitHub CLI |

### `sashi/gaming`（home-manager / sashi-main のみ）

| 分類 | 内容 |
| --- | --- |
| package | `lutris`, `bottles` |
| option | Discord, Flatseal, PrismLauncher, osu! の Flatpak |

### ホスト固有

| ホスト | 内容 |
| --- | --- |
| sashi-main | NVIDIA, gaming, libvirt, r8125, Keychron/FiiO udev, 3 モニタ Umbriel/Noctalia |
| sashi-letsnote | NVIDIA/gaming なし, 単一パネル Umbriel/Noctalia, hardware-config はプレースホルダ |

## 自動更新・自動アップグレード

### GitHub Actions（`.github/workflows/update-flake.yml`）

毎週日曜 12:00 UTC（21:00 JST）に:

1. `nix flake update` を実行
2. `sashi-main` と `sashi-letsnote` の `system.build.toplevel` を `nix build`
3. 両方成功した場合だけ `flake.lock` をコミットして `main` へ push

ビルドが失敗した場合、リモートの `flake.lock` は前回成功時のまま残ります。
`workflow_dispatch` で手動実行もできます。リポジトリの Actions 権限を
**Read and write** にし、`main` の branch protection が bot の push を
妨げないようにしてください。

ローカルの再ビルドは翌日月曜 22:00 JST に走るため、CI が遅延しても
通常は同じ週の更新をそのまま取得できます。

### ローカル（`system/core/auto-upgrade.nix`）

既定で有効です。

| タイマー | 動作 |
| --- | --- |
| `nixos-remote-upgrade.timer` | 毎週月曜 22:00 に `nixos-rebuild boot --refresh --accept-flake-config --flake github:sashisashi569/dotfile-nixos#<host>` |
| `nixos-remote-upgrade-catchup.timer` | 起動 10 分後に、直近の週次スロットが未実行なら同じ再ビルドを開始 |

- `boot` なので稼働中のシステムは変更せず、次回再起動で新世代を選択します。
- 週次タイマーは `Persistent=false` です。取りこぼしは起動後 10 分の
  キャッチアップが担当するため、systemd が起動直後に即実行することはありません。
- キャッチアップは `last-success` と直近の週次スロットを比較します。
  ビルド失敗時も次の起動で再試行されます。
- 実行ログ: `journalctl -u nixos-remote-upgrade -u nixos-remote-upgrade-catchup`
- タイマー確認: `systemctl list-timers 'nixos-remote-upgrade*'`

主なオプション（`system/core/auto-upgrade.nix`）:

| option | 既定値 |
| --- | --- |
| `sashi.autoUpgrade.enable` | `true` |
| `sashi.autoUpgrade.flake` | `"github:sashisashi569/dotfile-nixos"` |
| `sashi.autoUpgrade.hostname` | `config.networking.hostName` |
| `sashi.autoUpgrade.dayOfWeek` | `"Mon"` |
| `sashi.autoUpgrade.time` | `"22:00"` |
| `sashi.autoUpgrade.bootDelay` | `"10min"` |

リモート URL を変えた場合は `sashi.autoUpgrade.flake` を実際のリポジトリに
合わせてください。GitHub Actions の cron も同じ曜日・時刻を基準にしています。

> 概要の「隔週」と詳細仕様の「毎週」が食い違うため、実装は詳細仕様の
> **毎週** に合わせています。隔週にしたい場合は、Action に ISO 週の偶奇で
> スキップするステップを追加し、ローカル側も `dayOfWeek`/`time` だけでなく
> キャッチアップの周期判定を 2 週間に変更してください。

## セットアップ

### 1. リモート URL を合わせる

`flake.nix` の inputs はそのままで構いませんが、以下を実際のリポジトリに
合わせてください。

- `sashi.autoUpgrade.flake`（既定 `github:sashisashi569/dotfile-nixos`）
- GitHub Actions の `ref: main` と push 先

### 2. sashi-letsnote の hardware-configuration.nix

`hosts/sashi-letsnote/hardware-configuration.nix` はプレースホルダです。
実機で以下を実行し、出力で置き換えてください。

```bash
nixos-generate-config --show-hardware-config
```

LUKS・ESP の UUID・CPU microcode などは必ず実機の値にします。

### 3. 初回ビルド

```bash
# sashi-main（旧 hostname のままでも rebuild.sh が読み替えます）
pkexec ./rebuild.sh boot
sudo reboot

# sashi-letsnote
pkexec env NIXOS_HOST=sashi-letsnote ./rebuild.sh boot
```

`pkexec` は Wayland セッションの polkit ダイアログを使うためです。
コンソールからなら `sudo` でも構いません。

### 4. hostname の変更（任意）

```bash
sudo hostnamectl set-hostname sashi-main
```

`networking.hostName = "sashi-main"` は既に設定済みなので、次回の
`nixos-rebuild switch` でも反映されます。

## 手動での確認

```bash
# 両ホストの評価だけ
nix eval --raw .#nixosConfigurations.sashi-main.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.sashi-letsnote.config.system.build.toplevel.drvPath

# 両ホストのビルド（CI と同じ）
nix build --accept-flake-config --no-link \
  .#nixosConfigurations.sashi-main.config.system.build.toplevel \
  .#nixosConfigurations.sashi-letsnote.config.system.build.toplevel

# home-manager 設定だけ
nix build --accept-flake-config --no-link \
  .#nixosConfigurations.sashi-main.config.home-manager.users.sashi.home.activationPackage
```

## 設計上の変更点

- **`music-tools` をリポジトリ内へ移動** — 旧 `path:/home/sashi/...` の
  flake input は GitHub Actions のクリーンなランナーで評価できないため、
  `packages/rename-music-by-tags` として同梱しました。
- **`nativeOptimization` を既定 off** — リモート CI のビルド結果とホストの
  インストール結果を一致させるためです。旧構成の `-march=native` を復元
  したい場合は `hosts/sashi-main/default.nix` で
  `sashi.boot.cachyos.nativeOptimization = true;` を設定してください
  （その場合 CI のカーネルビルドはホストのカーネルとは別物になります）。
- **ホスト固有の Noctalia/Umbriel 設定を分離** — 共通キーバインドと外観は
  `sashi/lib/`、モニタ出力・壁紙・バーは `hosts/<host>/` に置いています。
- **`flake.lock` は CI のビルド成功時のみ更新** — 失敗した更新はリモートに
  残らないため、ローカルの自動再ビルドは常に最後の成功ロックを取得します。
- **Noctalia の UI 状態オーバーライド** — Settings UI で変更すると
  `~/.local/state/noctalia/settings.toml` が宣言設定より優先されます。
  リモートを正に保つため、home-manager の activation で同ファイルを削除して
  います。UI で試した設定を残したい場合は、この activation を外してください。
