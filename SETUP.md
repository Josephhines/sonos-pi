# Raspberry Pi Setup Guide

## 1. Install Raspberry Pi OS

1.  Download **Raspberry Pi Imager** from [raspberrypi.com/software](https://www.raspberrypi.com/software/).
2.  Insert your MicroSD card into your computer.
3.  Open Raspberry Pi Imager.
4.  **Choose Device**: Raspberry Pi Zero 2 W.
5.  **Choose OS**: Raspberry Pi OS (other) -> **Raspberry Pi OS Lite (64-bit)**. *The "Lite" version is best for headless setups as it has no desktop environment, saving resources.*
6.  **Choose Storage**: Select your SD card.
7.  **Configure Settings** (Click 'Next' then 'Edit Settings'):
    *   **General**:
        *   Set hostname: `sonos-pi`
        *   Set username and password (e.g., `pi` / `raspberry`)
        *   **Configure Wireless LAN**: Enter your WiFi SSID and Password. Change Country Code if necessary.
    *   **Services**:
        *   **Enable SSH**: Select "Use password authentication".
8.  **Write**: Click YES to write the OS to the card.
9.  Once finished, insert the SD card into the Pi and power it on.

## 2. Connect to the Pi

1.  Open your terminal (Command Prompt, PowerShell, or Terminal).
2.  SSH into the Pi:
    ```bash
    ssh pi@sonos-pi.local
    ```
    *(Enter the password you set in the Imager)*

## 3. Configure GPIO Pull-Up (Important!)
Because you likely have a newer Raspberry Pi OS that does not support `raspi-gpio`, you **must** manually configure the button's pull-up resistor in the system config.

1.  Open the firmware configuration file:
    ```bash
    sudo nano /boot/firmware/config.txt
    ```
    *(If that file is empty or missing, try `sudo nano /boot/config.txt`)*

2.  Scroll to the very bottom and add this line:
    ```text
    gpio=27=ip,pu
    ```

3.  Save and Exit: `Ctrl+O`, `Enter`, `Ctrl+X`.
4.  **Reboot** your Pi: `sudo reboot`

## 4. Install node-sonos-http-api
This tool creates a local HTTP server to control your Sonos system.

```bash
# Install System Dependencies (npm must be installed separately on Debian/Pi OS)
sudo apt update
sudo apt install -y git nodejs npm

# Clone the repository
git clone https://github.com/jishi/node-sonos-http-api.git

# Go into the directory
cd node-sonos-http-api

# Install dependencies
npm install --production

# Test run (it should find your Sonos system)
npm start
```
*   **Note:** You may see "Could not find file .../settings.json". This is normal.
*   Press `Ctrl+C` to stop the server.

## 5. Setup the Controller Code

### Method 1: The "Easier" Way (Installation Script)
Instead of creating files one by one, you can copy this single block of text, paste it into your terminal, and it will do everything for you.

1.  **Go to your home directory:**
    ```bash
    cd ~
    ```

2.  Create the installer file:
    ```bash
    nano install.sh
    ```
3.  Copy the content of `install.sh` from the repository/chat and paste it here.
4.  Save and Exit (`Ctrl+O`, `Enter`, `Ctrl+X`).
5.  Run the script:
    ```bash
    bash install.sh
    ```

### Method 2: The Manual Way
If you prefer to do it step-by-step:

1.  **Install Deps**: `sudo apt install -y build-essential`
2.  **Create Directory**: `mkdir -p ~/sonos-button && cd ~/sonos-button`
3.  **Create Files**: Use `nano` to create `package.json`, `config.json`, and `index.js` (copy content from this repo).
4.  **Install**: Run `npm install`.
5.  **Services**: Create `/etc/systemd/system/sonos-controller.service` manually.
6.  **Enable**: Run `sudo systemctl enable sonos-controller.service`.

## 6. Verification (Optional)
To verify the connection to your Sonos system is working:

```bash
node ~/sonos-button/test_sonos.js
```
This command will list your active Sonos zones and speakers in the terminal.
