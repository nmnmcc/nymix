# nymix

[English](README.md) | [简体中文](README.zh-CN.md) | [Русский](README.ru-RU.md) | [Türkçe](README.tr-TR.md)

بسته‌های Nix و یک ماژول NixOS برای اجرای نسخه رسمی لینوکس NymVPN.

اگر می‌خواهید NymVPN را روی NixOS با برنامه دسکتاپ، کلاینت خط فرمان
`nym-vpnc` و daemon سیستمی `nym-vpnd` داشته باشید، این flake آن‌ها را از
طریق systemd، D-Bus و polkit آماده می‌کند.

## چه چیزهایی دارد

- `nym-vpn`: برنامه دسکتاپ NymVPN.
- `nym-vpnc`: کلاینت خط فرمان NymVPN.
- `nym-vpnd`: daemon مربوط به NymVPN.
- ماژول NixOS در `nymix.nixosModules.default`.
- overlay بسته‌ها در `nymix.overlays.default`.

سیستم‌های پشتیبانی‌شده `x86_64-linux` و `aarch64-linux` هستند.

به Nix با flakes فعال نیاز دارید.

## راه‌اندازی در NixOS

`nymix` را به inputs در flake خود اضافه کنید:

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

سپس سیستم را بازسازی کنید:

```sh
sudo nixos-rebuild switch --flake .#your-host
```

بعد از بازسازی، **NymVPN** را از launcher دسکتاپ باز کنید یا CLI را اجرا کنید:

```sh
nym-vpnc --help
```

ماژول NixOS همچنین daemon را اجرا می‌کند:

```sh
systemctl status nym-vpnd
```

## نصب فقط بعضی از اجزا

`services.nym.enable = true` برنامه، CLI و daemon را فعال می‌کند. اگر می‌خواهید
خودتان اجزا را انتخاب کنید، آن‌ها را جداگانه فعال کنید:

```nix
{
  services.nym = {
    app.enable = true;
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

برای نمونه، یک راه‌اندازی متمرکز بر CLI می‌تواند فقط کلاینت و daemon را فعال کند:

```nix
{
  services.nym = {
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

وقتی daemon فعال باشد، ماژول D-Bus و polkit را فعال می‌کند، policy مربوط به
daemon را نصب می‌کند و به نشست‌های محلی فعال اجازه می‌دهد بدون درخواست رمز
اضافی به daemon دسترسی داشته باشند.

## اجرای مستقیم بسته‌ها

می‌توانید بسته‌ها را بدون ماژول NixOS مستقیما اجرا کنید:

```sh
nix run github:nmnmcc/nymix#nym-vpn
nix run github:nmnmcc/nymix#nym-vpnc -- --help
nix run github:nmnmcc/nymix#nym-vpnd -- --help
```

برای راه‌اندازی کامل VPN روی NixOS، بهتر است از ماژول بالا استفاده کنید. این
ماژول سرویس daemon و دسترسی‌ها را برای شما تنظیم می‌کند.

اگر می‌خواهید بسته‌ها را به package set خودتان اضافه کنید، از overlay استفاده کنید:

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

## به‌روزرسانی

اگر سیستم شما از `nymix` به عنوان flake input استفاده می‌کند، آن را مثل هر input
دیگری به‌روزرسانی کنید:

```sh
nix flake update nymix
sudo nixos-rebuild switch --flake .#your-host
```

این مخزن نسخه‌های upstream مربوط به NymVPN app و core را در `sources.json` ثابت
می‌کند. برنامه، CLI و daemon روی یک جفت نسخه upstream با قالب `X.Y.Z` نگه داشته
می‌شوند تا نسخه‌های ناسازگار تصادفا با هم نصب نشوند.

## عیب‌یابی

بررسی کنید daemon در حال اجراست یا نه:

```sh
systemctl status nym-vpnd
```

لاگ‌های daemon از boot فعلی را ببینید:

```sh
journalctl -u nym-vpnd -b
```

اگر Nix می‌گوید بسته برای پلتفرم شما در دسترس نیست، مطمئن شوید میزبان شما
`x86_64-linux` یا `aarch64-linux` است.

## مجوز

باینری‌های بسته‌بندی‌شده NymVPN توسط پروژه upstream خود NymVPN منتشر می‌شوند.
این flake همان نسخه‌های لینوکس را برای Nix و NixOS بسته‌بندی می‌کند.
