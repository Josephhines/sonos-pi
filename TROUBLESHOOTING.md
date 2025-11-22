# Troubleshooting Guide

If you are seeing the error:
> **"Job for sonos-controller.service failed because the control process exited with error code."**

This usually happens for one of two reasons:
1.  **Systemd is using an old version of the file.** (Most likely)
2.  **The code is crashing immediately.**

Follow these steps to fix it.

## Step 1: Reload Systemd
If you edited the `sonos-controller.service` file (or copied a new one) but didn't tell Linux to reload it, it will keep trying to run the old version (which had the failing `raspi-gpio` command).

Run this command:
```bash
sudo systemctl daemon-reload
```

Then try starting it again:
```bash
sudo systemctl restart sonos-controller.service
```

## Step 2: Check the Real Error
If it still fails, we need to see *why*. Run the code manually to see the error message on your screen.

1.  Stop the service:
    ```bash
    sudo systemctl stop sonos-controller.service
    ```
2.  Run the code manually:
    ```bash
    # Go to the folder
    cd ~/sonos-button
    
    # Run it
    sudo node index.js
    ```

**What happens?**

### Scenario A: "Module not found" or "Error: onoff"
If you see an error about `onoff` or missing modules, the installation failed.
**Fix:**
```bash
sudo apt install -y build-essential
rm -rf node_modules
npm install
```
Then try running `sudo node index.js` again.

### Scenario B: It runs successfully!
If you see "Sonos Controller started..." and the button works, then the code is fine, and the issue is just the Service file.
**Fix:**
1.  Double-check `sonos-controller.service`. It should look like this:
    ```ini
    [Unit]
    Description=Sonos Button Controller
    After=network.target sonos-api.service

    [Service]
    ExecStart=/usr/bin/node /home/pi/sonos-button/index.js
    Restart=always
    User=root
    Environment=PATH=/usr/bin:/usr/local/bin
    WorkingDirectory=/home/pi/sonos-button

    [Install]
    WantedBy=multi-user.target
    ```
2.  Copy it again:
    ```bash
    sudo nano /etc/systemd/system/sonos-controller.service
    # Paste the content above
    # Save and Exit
    ```
3.  **Reload and Restart**:
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart sonos-controller.service
    ```

## Step 3: Check System Logs
If it still fails, check the detailed logs:
```bash
journalctl -u sonos-controller.service -n 50 --no-pager
```
Look for the *last* error message.

---

## Issue: "Sonos API Connection Failed" (Error code ECONNREFUSED)

If `test_sonos.js` fails with "Connection Failed", it means the `sonos-api.service` is not running or not reachable.

### 1. Check API Service Status
```bash
sudo systemctl status sonos-api.service
```
*   If it says **active (running)**, try restarting it: `sudo systemctl restart sonos-api.service`
*   If it says **failed**, check the logs:

### 2. Check API Logs
```bash
journalctl -u sonos-api.service -n 50 --no-pager
```
**Common Error**: "Error: Cannot find module ..."
**Fix**: You might need to reinstall dependencies for the API.
```bash
cd ~/node-sonos-http-api
npm install --production
```

### 3. Test API Manually
Stop the service and try running it yourself to see the output:
```bash
sudo systemctl stop sonos-api.service
cd ~/node-sonos-http-api
npm start
```

**Important:** This command will "block" your terminal (it keeps running until you stop it).
*   **To run the verification test while this is running:**
    1.  Leave this terminal window open.
    2.  Open a **new** terminal window (connect via SSH again).
    3.  In the new window, run: `node ~/sonos-button/test_sonos.js`

If the test works now, it means your `sonos-api.service` file might be wrong or disabled.
*   Press `Ctrl+C` in the first window to stop the manual server.
*   Try `sudo systemctl enable --now sonos-api.service` to start the system service again.

---

## Issue: LEDs are not lighting up

If the debug logs say "Turning ON LED" but the light stays off:

1.  **Run the Hardware Test**:
    This isolates the LEDs from the Sonos system.
    ```bash
    sudo node ~/sonos-button/hardware_test.js
    ```
    *   If this script fails with an error, your software setup is broken (re-run `install.sh`).
    *   If the script runs but **no lights appear**, your wiring is incorrect.

2.  **Check GPIO vs Physical Pins**:
    The code uses **BCM (GPIO)** numbers, but the board uses **Physical** numbers.
    *   **GPIO 17** is **Physical Pin 11**.
    *   **GPIO 22** is **Physical Pin 15**.
    *   **GPIO 23** is **Physical Pin 16**.
    *   **GPIO 24** is **Physical Pin 18**.
    *   **GPIO 25** is **Physical Pin 22**.

3.  **Check Polarity**:
    *   LED **Long Leg (+)** must go to the GPIO Pin.
    *   LED **Short Leg (-)** must go to the Resistor -> Ground.
    *   *Test*: Move the wire from the GPIO pin to **Physical Pin 1 (3.3V)**. If it lights up there, your LED/Resistor/Ground is good, and the issue is the GPIO pin selection or software.
