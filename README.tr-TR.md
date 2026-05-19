# nymix

[English](README.md) | [简体中文](README.zh-CN.md) | [Русский](README.ru-RU.md) | [فارسی](README.fa-IR.md)

Resmi NymVPN Linux sürümünü çalıştırmak için Nix paketleri ve bir NixOS modülü.

NixOS üzerinde NymVPN kullanmak, masaüstü uygulamasını, `nym-vpnc` komut satırı
istemcisini ve `nym-vpnd` sistem daemon'ını systemd, D-Bus ve polkit ile hazır
şekilde almak istiyorsanız bu flake bunun içindir.

## İçindekiler

- `nym-vpn`: NymVPN masaüstü uygulaması.
- `nym-vpnc`: NymVPN komut satırı istemcisi.
- `nym-vpnd`: NymVPN daemon'ı.
- `nymix.nixosModules.default` altında bir NixOS modülü.
- `nymix.overlays.default` altında bir paket overlay'i.

Desteklenen sistemler `x86_64-linux` ve `aarch64-linux`.

Flakes etkinleştirilmiş Nix gerekir.

## NixOS kurulumu

`nymix` değerini flake inputs içine ekleyin:

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

Sonra sistemi yeniden oluşturun:

```sh
sudo nixos-rebuild switch --flake .#your-host
```

Yeniden oluşturduktan sonra **NymVPN** uygulamasını masaüstü başlatıcısından açın
veya CLI'ı çalıştırın:

```sh
nym-vpnc --help
```

NixOS modülü daemon'ı da başlatır:

```sh
systemctl status nym-vpnd
```

## Sadece bazı bileşenleri kurmak

`services.nym.enable = true` uygulamayı, CLI'ı ve daemon'ı etkinleştirir.
Bileşenleri kendiniz seçmek isterseniz ayrı ayrı etkinleştirebilirsiniz:

```nix
{
  services.nym = {
    app.enable = true;
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

Örneğin CLI odaklı bir kurulum yalnızca istemciyi ve daemon'ı etkinleştirebilir:

```nix
{
  services.nym = {
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

Daemon etkinleştirildiğinde modül D-Bus ve polkit'i açar, daemon policy'sini
kurar ve aktif yerel oturumların ek parola istemi olmadan daemon'a erişmesine
izin verir.

## Paketleri doğrudan kullanmak

Paketleri NixOS modülü olmadan doğrudan çalıştırabilirsiniz:

```sh
nix run github:nmnmcc/nymix#nym-vpn
nix run github:nmnmcc/nymix#nym-vpnc -- --help
nix run github:nmnmcc/nymix#nym-vpnd -- --help
```

NixOS üzerinde tam VPN kurulumu için yukarıdaki modülü tercih edin. Daemon
servisini ve izinleri sizin için yapılandırır.

Paketleri kendi package set'inize eklemek isterseniz overlay'i kullanın:

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

## Güncelleme

Sisteminiz `nymix` değerini bir flake input olarak kullanıyorsa, onu diğer
input'lar gibi güncelleyin:

```sh
nix flake update nymix
sudo nixos-rebuild switch --flake .#your-host
```

Bu depo upstream NymVPN app ve core sürümlerini `sources.json` içinde sabitler.
Uygulama, CLI ve daemon aynı upstream `X.Y.Z` sürüm çifti üzerinde tutulur; böylece
farklı sürümler yanlışlıkla birlikte kurulmaz.

## Sorun giderme

Daemon'ın çalışıp çalışmadığını kontrol edin:

```sh
systemctl status nym-vpnd
```

Geçerli boot için daemon loglarını okuyun:

```sh
journalctl -u nym-vpnd -b
```

Nix paketinizin platformunuzda kullanılamadığını söylüyorsa, host sisteminizin
`x86_64-linux` veya `aarch64-linux` olduğundan emin olun.

## Lisans

Paketlenen NymVPN binary'leri upstream NymVPN projesi tarafından dağıtılır. Bu
flake, bu Linux sürümlerini Nix ve NixOS için paketler.
