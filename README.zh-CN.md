# nymix

[English](README.md) | [Русский](README.ru-RU.md) | [فارسی](README.fa-IR.md) | [Türkçe](README.tr-TR.md)

用于运行官方 NymVPN Linux 版本的 Nix 包和 NixOS 模块。

如果你想在 NixOS 上使用 NymVPN，并希望桌面应用、`nym-vpnc` 命令行客户端和
`nym-vpnd` 系统守护进程通过 systemd、D-Bus 与 polkit 配好，这个 flake 就是
为此准备的。

## 包含内容

- `nym-vpn`：NymVPN 桌面应用。
- `nym-vpnc`：NymVPN 命令行客户端。
- `nym-vpnd`：NymVPN 守护进程。
- NixOS 模块：`nymix.nixosModules.default`。
- 包覆盖层：`nymix.overlays.default`。

支持的系统是 `x86_64-linux` 和 `aarch64-linux`。

你需要启用 flakes 的 Nix。

## NixOS 配置

把 `nymix` 加到你的 flake inputs：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nymix.url = "github:nmnmcc/nymix";
  };

  outputs =
    {
      nixpkgs,
      nymix,
      ...
    }:
    {
      nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nymix.nixosModules.default
          {
            services.nym.enable = true;
          }
        ];
      };
    };
}
```

然后重建系统：

```sh
sudo nixos-rebuild switch --flake .#your-host
```

重建完成后，可以从桌面启动器打开 **NymVPN**，也可以使用命令行客户端：

```sh
nym-vpnc --help
```

NixOS 模块也会启动守护进程：

```sh
systemctl status nym-vpnd
```

## 只安装部分组件

`services.nym.enable = true` 会启用桌面应用、CLI 和守护进程。如果你想自己选择
组件，可以分别启用：

```nix
{
  services.nym = {
    app.enable = true;
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

例如，只使用 CLI 的配置可以只启用客户端和守护进程：

```nix
{
  services.nym = {
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

启用守护进程时，模块会启用 D-Bus 和 polkit、安装守护进程策略，并允许本地活跃
会话访问守护进程，无需额外输入密码。

## 直接使用包

你也可以不使用 NixOS 模块，直接运行这些包：

```sh
nix run github:nmnmcc/nymix#nym-vpn
nix run github:nmnmcc/nymix#nym-vpnc -- --help
nix run github:nmnmcc/nymix#nym-vpnd -- --help
```

如果要在 NixOS 上完整使用 VPN，建议使用上面的模块。它会为你配置守护进程服务
和权限。

如果你想把这些包加入自己的 package set，可以使用 overlay：

```nix
{
  nixpkgs.overlays = [
    nymix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    nym-vpn
    nym-vpnc
    nym-vpnd
  ];
}
```

## 更新

如果你的系统把 `nymix` 作为 flake input 使用，可以像更新其他 input 一样更新它：

```sh
nix flake update nymix
sudo nixos-rebuild switch --flake .#your-host
```

本仓库在 `sources.json` 中固定上游 NymVPN app 和 core 版本。桌面应用、CLI 与守护
进程会保持在同一个上游 `X.Y.Z` 版本组合上，避免意外混用不同版本。

## 排错

检查守护进程是否正在运行：

```sh
systemctl status nym-vpnd
```

查看当前启动周期的守护进程日志：

```sh
journalctl -u nym-vpnd -b
```

如果 Nix 提示当前平台不可用，请确认你的主机是 `x86_64-linux` 或 `aarch64-linux`。

## 许可证

打包的 NymVPN 二进制文件由上游 NymVPN 项目分发。本 flake 将这些 Linux 版本打包
给 Nix 和 NixOS 使用。
