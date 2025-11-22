# Sonos Controller Project

This repository contains all the code and instructions to build a physical Sonos controller using a Raspberry Pi Zero 2 W.

## Project Structure

*   `SETUP.md`: **Start Here**. Instructions for installing the OS, Node.js, and the Sonos API.
*   `WIRING.md`: Instructions for connecting the Button and LED to the Pi.
*   `install.sh`: A script to automate the installation of code and services.
*   `index.js`: The main controller logic.
*   `sonos-controller.service`: Systemd service to auto-start the button controller.
*   `sonos-api.service`: Systemd service to auto-start the Sonos API.
*   `package.json` & `config.json`: Dependencies and settings.

## How to "Upload" code using Jules

Since "Jules" is the AI assistant (me), I cannot directly push files to your physical device over the internet. However, I have created all the necessary files in this virtual repository.

**To get this code onto your Raspberry Pi, you have two options:**

### Option A: The "Easy" Script (Recommended)
This is the fastest method.
1.  SSH into your Raspberry Pi.
2.  Go to your home directory: `cd ~`
3.  Create the installer: `nano install.sh`
4.  Paste the content of `install.sh` from this repository (copy it from your browser).
5.  Run it: `bash install.sh`

### Option B: Git Clone (Step-by-Step Guide)
If you prefer to download the code directly using Git, follow these steps. This assumes you are viewing this project on a platform like GitHub or GitLab.

**1. Get the Repository URL**
*   Look at the top of the page you are reading right now.
*   Find the green/blue button that says **"Code"** or **"Clone"**.
*   Copy the **HTTPS** URL (it ends in `.git`).

**2. Install Git on your Pi**
*   SSH into your Pi.
*   Run: `sudo apt update && sudo apt install -y git`

**3. Clone the Repository**
*   Run the clone command with the URL you copied:
    ```bash
    git clone https://github.com/Josephhines/sonos-pi.git
    ```

**4. Enter the Project Folder**
*   Go into the new folder:
    ```bash
    cd sonos-pi
    ```

**5. Switch to the Correct Branch**
*   Since we are working on specific features, the code might not be on the main branch yet.
*   Check the name of the branch you are viewing (e.g., `sonos-controller-hardware-test-fix`).
*   Run:
    ```bash
    git checkout <branch_name>
    ```
    *(Example: `git checkout sonos-controller-hardware-test-fix`)*

**6. Run the Installation**
*   Now that the files are on your Pi, simply run:
    ```bash
    bash install.sh
    ```

### Option C: Manual Copy
1.  Create each file (`nano index.js`) and paste the content manually.

## Updating the Code
If you have already installed the controller and want to update to the latest version (e.g., to get new features or fixes):

1.  **Re-run the Installer**:
    *   Update your `install.sh` file with the new content.
    *   Run `bash install.sh` again.
    *   This will overwrite your code files (`index.js`, `test_sonos.js`) with the new versions.
    *   *Note: It will also reset `config.json`. If you made custom changes, back them up first!*

## Quick Start Summary

1.  **Hardware**: Follow `WIRING.md`.
2.  **Software**: Follow `SETUP.md` (use the `install.sh` method for speed).
3.  **Crucial Step**: You must edit `/boot/firmware/config.txt` manually to enable the button pull-up resistor. The script will remind you to do this.
4.  **Configure**: Edit `~/sonos-button/config.json` to set your Room Names.

## Troubleshooting

See `TROUBLESHOOTING.md` for detailed steps on how to fix common errors like:
*   **"Job for sonos-controller.service failed..."**
*   **"Module not found"** errors.

Enjoy your physical Sonos controller!
