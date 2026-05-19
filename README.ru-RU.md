# nymix

[English](README.md) | [简体中文](README.zh-CN.md) | [فارسی](README.fa-IR.md) | [Türkçe](README.tr-TR.md)

Пакеты Nix и модуль NixOS для запуска официального Linux-релиза NymVPN.

Этот flake пригодится, если вы хотите использовать NymVPN в NixOS с настольным
приложением, клиентом командной строки `nym-vpnc` и системным демоном
`nym-vpnd`, уже связанными через systemd, D-Bus и polkit.

## Что входит

- `nym-vpn`: настольное приложение NymVPN.
- `nym-vpnc`: клиент командной строки NymVPN.
- `nym-vpnd`: демон NymVPN.
- Модуль NixOS: `nymix.nixosModules.default`.
- Overlay для пакетов: `nymix.overlays.default`.

Поддерживаемые системы: `x86_64-linux` и `aarch64-linux`.

Вам нужен Nix с включенными flakes.

## Настройка NixOS

Добавьте `nymix` в inputs вашего flake:

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

Затем пересоберите систему:

```sh
sudo nixos-rebuild switch --flake .#your-host
```

После пересборки откройте **NymVPN** из меню приложений или запустите CLI:

```sh
nym-vpnc --help
```

Модуль NixOS также запускает демон:

```sh
systemctl status nym-vpnd
```

## Установка отдельных компонентов

`services.nym.enable = true` включает приложение, CLI и демон. Если вы хотите
выбрать компоненты вручную, включите их по отдельности:

```nix
{
  services.nym = {
    app.enable = true;
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

Например, для конфигурации с упором на CLI можно включить только клиент и демон:

```nix
{
  services.nym = {
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

Когда демон включен, модуль включает D-Bus и polkit, устанавливает политику
демона и разрешает активным локальным сеансам обращаться к демону без
дополнительного запроса пароля.

## Прямой запуск пакетов

Пакеты можно запускать напрямую, без модуля NixOS:

```sh
nix run github:nmnmcc/nymix#nym-vpn
nix run github:nmnmcc/nymix#nym-vpnc -- --help
nix run github:nmnmcc/nymix#nym-vpnd -- --help
```

Для полноценной VPN-настройки в NixOS лучше использовать модуль выше. Он
настраивает службу демона и права доступа.

Если вы хотите добавить пакеты в свой package set, используйте overlay:

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

## Обновление

Если ваша система использует `nymix` как flake input, обновляйте его как любой
другой input:

```sh
nix flake update nymix
sudo nixos-rebuild switch --flake .#your-host
```

Этот репозиторий фиксирует upstream-релизы NymVPN app и core в `sources.json`.
Приложение, CLI и демон держатся на одной upstream-паре версий `X.Y.Z`, чтобы
разные версии не смешивались случайно.

## Диагностика

Проверьте, запущен ли демон:

```sh
systemctl status nym-vpnd
```

Посмотрите логи демона с текущей загрузки:

```sh
journalctl -u nym-vpnd -b
```

Если Nix сообщает, что пакет недоступен для вашей платформы, убедитесь, что
ваш хост использует `x86_64-linux` или `aarch64-linux`.

## Лицензия

Упакованные бинарные файлы NymVPN распространяются upstream-проектом NymVPN.
Этот flake упаковывает эти Linux-релизы для Nix и NixOS.
