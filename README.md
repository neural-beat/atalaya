# Atalaya

**English** · [Español](README.es.md)

**Your Linux server, in plain sight — over SSH, with nothing to install on it.**

<p align="center">
  <img src="docs/dashboard.png" width="760" alt="Atalaya dashboard">
</p>

Every server dashboard asks you to install something first: an agent, a web
panel, a container, an open port. Atalaya asks for none of that. It logs in over
SSH, the way you already do, and reads what is there.

## What it shows

- **Live dashboard**: CPU, memory, load, temperature, network and disks, sampled
  as often as you want.
- **Cards you arrange yourself**: drag them into the order you actually read,
  make them wider, and the wide ones grow a chart.
- **Containers**: every Docker container with its state, plus start, stop,
  restart and logs.
- **Services**: what systemd is running, with a plain-language explanation of
  what the common ones are for — no more wondering what `chrony` does.
- **Your scripts, as buttons**: Atalaya finds the `.sh` files in your home
  folder and explains each one **using the comments you wrote inside it**. Run
  them and watch the output arrive live.
- **Updates, grouped**: security, kernel, programs, libraries and the rest, with
  checkboxes. You pick what gets installed. It only ever upgrades packages that
  are already installed.

<p align="center">
  <img src="docs/scripts.png" width="380" alt="Scripts explained by their own comments">
  <img src="docs/updates.png" width="380" alt="Updates grouped by kind">
</p>

> The screenshots run in demo mode (`ATALAYA_DEMO=1`), with made-up servers and
> made-up scripts. Nothing there is a real machine.

## What it does not do

- It does not phone home. The app talks to your server and to nothing else.
- It does not install an agent, a daemon or a web panel on your server.
- It does not store passwords in a file. They go to the macOS Keychain.
- It will not restart `ssh` for you, because that is how you would lock yourself
  out.

## Requirements

- macOS 14 or newer, Apple Silicon or Intel.
- A Linux server you can reach over SSH, with a user that can log in.
- Optional: `sudo` for system updates, restarting services and shutting down.
  Docker features need a user in the `docker` group.

## Install

**[⬇ Download Atalaya 0.1.0](https://github.com/neural-beat/atalaya/releases/latest/download/Atalaya-0.1.0.zip)**

> **Download `Atalaya-0.1.0.zip`, not "Source code (zip)".** The source archive
> holds the code, not the app: there is no `.app` inside it.


1. Download the app from Releases, unzip it and drag `Atalaya.app` to your
   Applications folder.
2. **Right-click the app → Open → Open.** Atalaya is signed but not notarised by
   Apple, so a plain double-click is refused the first time.
3. Add your server: host, user, and either a password or your SSH key.

If the machine is already in your `~/.ssh/known_hosts`, Atalaya trusts only that
key. If it is not, the first connection is trusted and the app says so.

## Build it yourself

```bash
git clone https://github.com/neural-beat/atalaya.git
cd atalaya
./build.sh
open build/Atalaya.app
```

`Tools/setup-signing.sh` creates a stable local signing identity so macOS treats
each rebuild as the same app. It is free and offline; it is not Apple
notarisation.

## Updates

Atalaya checks GitHub once a day and tells you when a newer version is out. It
never downloads or installs anything on its own — it points you at the release
page. You can also check whenever you like from the About window.

## In development

The next release is being worked on: SFTP file management with Quick Look and
transfer progress, safe inspection and installation of Docker Compose
repositories, and several servers open as tabs. These features are not part of
the first public release yet.

## Licence

GPL-3.0-or-later. Made by [neural-beat](https://github.com/neural-beat).
