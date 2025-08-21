# GenieACS Auto Installer 🚀

This script automatically installs and configures **GenieACS**, **MongoDB 8.0**, **Node.js 20.x**, and **Nginx** on Ubuntu 20.04 / 22.04 / 24.04.

It also sets up firewall rules and systemd services so everything runs out of the box.

---

## ✅ Features

* Installs **Node.js 20.x**
* Installs **MongoDB 8.0 Community Edition**
* Installs and configures **GenieACS (v1.2.13)**
* Installs **Nginx** as a reverse proxy for the UI
* Configures **UFW firewall** (80, 443, 7547, 7557, 7567)
* Creates **systemd services** for GenieACS (cwmp, nbi, fs, ui)
* Auto restarts and enables services on boot

---

## 🔧 Requirements

* Ubuntu 20.04 / 22.04 / 24.04
* Run as **root** (`sudo`)

---

## 📥 Installation

One-liner install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kintoyyy/genieacs-installer/main/install.sh)"
```

Or clone and run manually:

```bash
git clone https://github.com/Kintoyyy/genieacs-installer.git
cd genieacs-installer
sudo ./install.sh
```

---

## 🌐 Access

After installation, open:

* **UI:** http\://`<server-ip>`

  * **User:** `admin`
  * **Pass:** `admin`

* **CWMP:** Port `7547`

* **NBI:** Port `7557`

* **FS:** Port `7567`

---

## ❌ Quick Uninstall

To completely remove GenieACS, MongoDB, and Nginx:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kintoyyy/genieacs-installer/main/uninstall.sh)"
```

This will remove installed packages, systemd services, and logs/config files.

---

## 📜 Notes

* Default JWT secret is set to `secret` (edit `/opt/genieacs/genieacs.env` for production).
* Logs are stored in `/var/log/genieacs/`.
* Services are managed with `systemctl` (e.g., `systemctl status genieacs-ui`).
