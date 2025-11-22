#!/bin/bash
set -e

echo "=============================================="
echo "   Sonos Controller Installation Script"
echo "=============================================="

# 1. Install Dependencies
echo "[1/5] Installing System Dependencies..."
sudo apt update
sudo apt install -y nodejs npm git build-essential gpiod raspi-utils

# 2. Setup Directories
echo "[2/5] Creating Project Directories..."
mkdir -p ~/sonos-button
cd ~/sonos-button

# 3. Create Project Files
echo "[3/5] Creating Code Files..."

# package.json
cat > package.json <<'EOF'
{
  "name": "sonos-button-controller",
  "version": "1.0.0",
  "description": "Physical button controller for Sonos using node-sonos-http-api",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "onoff": "^6.0.3"
  }
}
EOF

# config.json
cat > config.json <<'EOF'
{
  "sonosApiUrl": "http://localhost:5005",
  "mainRoom": "Living Room",
  "targetJoinRoom": "Living Room",
  "buttonPin": 27,
  "debounceTimeout": 500,
  "rooms": [
    { "name": "Living Room", "pin": 17 },
    { "name": "Kitchen", "pin": 22 },
    { "name": "Dining Room", "pin": 23 },
    { "name": "Office", "pin": 24 },
    { "name": "Future A", "pin": 25 }
  ]
}
EOF

# index.js
cat > index.js <<'EOF'
const Gpio = require('onoff').Gpio;
const axios = require('axios');
const config = require('./config.json');

// --- Configuration ---
const SONOS_API = config.sonosApiUrl;
const MAIN_ROOM = config.mainRoom; // The room this controller manages (the 'primary' one)
const TARGET_ROOM = config.targetJoinRoom;
const BUTTON_PIN = config.buttonPin;
const DEBOUNCE = config.debounceTimeout;
const ROOM_LEDS = config.rooms || [];

// --- GPIO Setup ---
// LED Map: { "Kitchen": GpioObj, ... }
let leds = {};
// Button: Input with internal Pull-Up (falling edge trigger)
let button;

try {
    // Initialize LEDs
    ROOM_LEDS.forEach(item => {
        try {
            leds[item.name] = new Gpio(item.pin, 'out');
            console.log(`Initialized LED for ${item.name} on GPIO ${item.pin}`);
            
            // Startup Sequence: Blink 3 times to verify hardware
            let blinkCount = 0;
            const interval = setInterval(() => {
                const val = blinkCount % 2;
                leds[item.name].writeSync(val ^ 1); // Toggle (Start ON)
                blinkCount++;
                if (blinkCount >= 6) {
                    clearInterval(interval);
                    leds[item.name].writeSync(0); // Ensure OFF
                }
            }, 200);

        } catch (err) {
            console.error(`Failed to init LED for ${item.name}:`, err.message);
        }
    });

    // Initialize Button
    button = new Gpio(BUTTON_PIN, 'in', 'falling', { debounceTimeout: DEBOUNCE });
} catch (e) {
    console.error("Error initializing GPIO. Are you running on a Raspberry Pi?");
    console.error(e);
    // Mock GPIO for testing on non-Pi systems
    button = { watch: () => {} };
    // Mock LEDs
    leds = {}; 
    ROOM_LEDS.forEach(item => {
        leds[item.name] = { writeSync: (val) => console.log(`[MOCK] LED (${item.name}) -> ${val}`) };
    });
}

console.log(`Sonos Controller started for main room: ${MAIN_ROOM}`);

// --- State ---
let isGrouped = false;

// --- Functions ---

/**
 * Check the current state of the Sonos system and update LEDs.
 */
async function checkState() {
    try {
        // We need to see the global zone state to know who is grouped with whom.
        const zonesResponse = await axios.get(`${SONOS_API}/zones`);
        const zones = zonesResponse.data;

        // 1. Find the Zone where the Coordinator is the TARGET_ROOM
        // We want to see who is grouped with the Target Room (e.g., Living Room)
        const groupZone = zones.find(z => z.coordinator.roomName === TARGET_ROOM);

        if (!groupZone) {
            // If the target room isn't a coordinator (or not found), essentially nobody is in its group (or it's a member of someone else).
            // We turn all LEDs OFF in this case (or just the Target Room LED if it's found elsewhere? Let's stick to strict logic).
            // User Requirement: "If the member is part of 'Group Coordinator: Living Room'..."
            Object.values(leds).forEach(l => l.writeSync(0));
            isGrouped = false;
            return;
        }

        // 2. Determine Group Status for MAIN_ROOM (Are we in that group?)
        isGrouped = groupZone.members.some(m => m.roomName === MAIN_ROOM);

        // 3. Update LEDs based on membership in the TARGET GROUP
        ROOM_LEDS.forEach(item => {
            const roomName = item.name;
            const led = leds[roomName];
            if (!led) return;

            const isInTargetGroup = groupZone.members.some(m => m.roomName === roomName);
            
            if (isInTargetGroup) {
                if (led.readSync() === 0) console.log(`Turning ON LED for ${roomName}`);
                led.writeSync(1);
            } else {
                if (led.readSync() === 1) console.log(`Turning OFF LED for ${roomName}`);
                led.writeSync(0);
            }
        });
        
    } catch (error) {
        console.error("Error fetching Sonos state:", error.message);
        // Optionally blink all LEDs to indicate API error
    }
}

/**
 * Toggle Group Membership
 */
async function toggleGroup() {
    console.log("Button Pressed!");
    
    // Refresh state first to ensure accuracy
    await checkState();

    if (isGrouped) {
        console.log(`Leaving group...`);
        try {
            await axios.get(`${SONOS_API}/${encodeURIComponent(MAIN_ROOM)}/leave`);
        } catch (err) {
            console.error("Failed to leave group:", err.message);
        }
    } else {
        console.log(`Joining ${TARGET_ROOM}...`);
        try {
            await axios.get(`${SONOS_API}/${encodeURIComponent(MAIN_ROOM)}/join/${encodeURIComponent(TARGET_ROOM)}`);
        } catch (err) {
            console.error(`Failed to join ${TARGET_ROOM}:`, err.message);
        }
    }
    
    // Update state after action (delay to allow Sonos to process)
    setTimeout(checkState, 2000); 
}

// --- Main Loop / Event Listeners ---

// 1. Watch Button
button.watch(async (err, value) => {
    if (err) {
        console.error('Button error', err);
        return;
    }
    // Value is 0 (falling edge) because of pull-up
    toggleGroup();
});

// 2. Initial State Check
checkState();

// 3. Poll State every 5 seconds
setInterval(checkState, 5000);

// 4. Cleanup on Exit
process.on('SIGINT', _ => {
    Object.values(leds).forEach(l => {
        try { l.writeSync(0); l.unexport(); } catch(e){}
    });
    if (button.unexport) button.unexport();
    process.exit();
});
EOF

# test_sonos.js
cat > test_sonos.js <<'EOF'
const axios = require('axios');
const config = require('./config.json');

const SONOS_API = config.sonosApiUrl;
const TARGET_ROOM = config.targetJoinRoom;
const ROOM_LEDS = config.rooms || [];

async function testConnection() {
    console.log(`Testing connection to Sonos API at ${SONOS_API}...`);
    try {
        const response = await axios.get(`${SONOS_API}/zones`, { timeout: 2000 });
        const zones = response.data;
        
        console.log("\n✅ Connection Successful!");
        console.log(`Found ${zones.length} Zone(s):`);
        
        zones.forEach(zone => {
            const coordinator = zone.coordinator.roomName;
            // members is an array of objects { roomName: '...' }
            const members = zone.members.map(m => m.roomName).join(', ');
            console.log(`- [Group Coordinator: ${coordinator}] Members: ${members}`);
        });

        // Check LED logic simulation
        console.log(`\n🔍 Checking LED status for group coordinator: '${TARGET_ROOM}'...`);
        
        // Debugging: List all coordinators found
        console.log("   (Debug) Found Coordinators: " + zones.map(z => `'${z.coordinator.roomName}'`).join(', '));

        // Find zone case-insensitively to be safe
        const groupZone = zones.find(z => z.coordinator.roomName.toLowerCase() === TARGET_ROOM.toLowerCase());

        if (!groupZone) {
             console.warn(`   ⚠️ Warning: Coordinator '${TARGET_ROOM}' NOT found in active zones. All LEDs should be OFF.`);
        } else {
             console.log(`   (Debug) Found Target Zone. Members: ${groupZone.members.map(m => m.roomName).join(', ')}`);
        }

        ROOM_LEDS.forEach(room => {
            let ledStatus = "OFF";
            if (groupZone) {
                 // Check if this room is a member of the target coordinator's group (Case insensitive check)
                 const isMember = groupZone.members.some(m => m.roomName.toLowerCase() === room.name.toLowerCase());
                 if (isMember) ledStatus = "ON";
            }
            // Log the status
            console.log(`- Room: ${room.name.padEnd(15)} | LED would be: ${ledStatus} (GPIO ${room.pin})`);
        });

        // Hardware Test Prompt
        console.log("\n⚠️  Hardware Verification:");
        console.log("   To test if your LEDs are physically wired correctly, you can run a simple toggle script.");
        console.log("   Run: node -e 'const G = require(\"onoff\").Gpio; [17,22,23,24,25].forEach(p=> { try{ let l=new G(p,\"out\"); l.writeSync(1); setTimeout(()=>l.writeSync(0), 1000); }catch(e){console.log(e)} })'");
        console.log("   (This will turn ON all configured LEDs for 1 second)");
        
    } catch (error) {
        console.error("\n❌ Connection Failed!");
        if (error.code) {
            console.error(`Error Code: ${error.code}`);
        }
        console.error(`Message: ${error.message}`);
        
        if (error.code === 'ECONNREFUSED') {
             console.error("\n[Suggestion] The Sonos API service is not listening on port 5005.");
             console.error("Try running: sudo systemctl status sonos-api.service");
        }
    }
}

testConnection();
EOF

# hardware_test.js
cat > hardware_test.js <<'EOF'
const config = require('./config.json');
const { execSync } = require('child_process');

// Mapping of BCM GPIO numbers to Physical Board Pins (Raspberry Pi 40-pin header)
const PIN_MAP = {
    17: 11,
    22: 15,
    23: 16,
    24: 18,
    25: 22,
    27: 13
};

const ROOMS = config.rooms || [];

console.log("\n========================================");
console.log("   Sonos Controller: Hardware Test");
console.log("========================================");
console.log("This script uses 'pinctrl' (standard Raspberry Pi tool) to bypass library issues.");
console.log("Please watch your breadboard.\n");

async function runSequence() {
    console.log("🛑 Stopping service to free up GPIO pins...");
    try {
        execSync('sudo systemctl stop sonos-controller.service');
    } catch (e) { console.log("   (Service was not running or could not be stopped)"); }

    for (const room of ROOMS) {
        const gpio = room.pin;
        const physical = PIN_MAP[gpio] || "Unknown";
        
        console.log(`👉 Testing [${room.name}]`);
        console.log(`   - GPIO: ${gpio}`);
        console.log(`   - Physical Pin: ${physical}`);
        
        try {
            console.log("   - Status: ON  💡");
            // Use pinctrl to set Output High (op dh)
            execSync(`pinctrl set ${gpio} op dh`, { stdio: 'pipe' }); 
            
            await new Promise(r => setTimeout(r, 2000)); // Wait 2 seconds
            
            console.log("   - Status: OFF ⚫");
            // Use pinctrl to set Output Low (op dl)
            execSync(`pinctrl set ${gpio} op dl`, { stdio: 'pipe' });
            
        } catch (err) {
            console.error(`   ❌ ERROR: Failed to control GPIO ${gpio}.`);
            // Print stderr from the command
            if (err.stderr) {
                console.error(`      Details: ${err.stderr.toString().trim()}`);
            } else {
                console.error(`      Details: ${err.message}`);
            }
            console.error("      (Ensure 'raspi-utils' is installed and you are running with permissions)");
        }
        
        console.log("----------------------------------------");
        await new Promise(r => setTimeout(r, 1000)); // Pause between lights
    }
    console.log("✅ Test Sequence Complete.");
    console.log("🔄 Restarting service...");
    try {
        execSync('sudo systemctl start sonos-controller.service');
    } catch (e) { console.log("   (Failed to restart service)"); }
}

runSequence();
EOF

# 4. Install Dependencies
echo "[4/5] Installing NPM packages..."
npm install

# 5. Setup Services
echo "[5/5] Setting up Systemd Services..."

# sonos-api.service
cat <<'EOF' | sudo tee /etc/systemd/system/sonos-api.service > /dev/null
[Unit]
Description=Node Sonos HTTP API
After=network.target

[Service]
ExecStart=/usr/bin/npm start
Restart=always
User=pi
Environment=PATH=/usr/bin:/usr/local/bin
WorkingDirectory=/home/pi/node-sonos-http-api

[Install]
WantedBy=multi-user.target
EOF

# sonos-controller.service
cat <<'EOF' | sudo tee /etc/systemd/system/sonos-controller.service > /dev/null
[Unit]
Description=Sonos Button Controller
After=network.target sonos-api.service

[Service]
# Runs as root to ensure full GPIO access
User=root
# Note: We removed the raspi-gpio command because it fails on newer Raspberry Pi OS versions.
# You must ensure the Pull-Up resistor for GPIO 27 is enabled via /boot/firmware/config.txt
# See SETUP.md for details.

ExecStart=/usr/bin/node /home/pi/sonos-button/index.js
Restart=always
Environment=PATH=/usr/bin:/usr/local/bin
WorkingDirectory=/home/pi/sonos-button
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable sonos-api.service
sudo systemctl enable sonos-controller.service

echo "=============================================="
echo "   Installation Complete!"
echo "=============================================="
echo "IMPORTANT NEXT STEPS:"
echo "1. Edit config.json if you need to change Room names:"
echo "   nano ~/sonos-button/config.json"
echo "2. Test the connection (Optional):"
echo "   node ~/sonos-button/test_sonos.js"
echo "3. Verify Hardware (LEDs):"
echo "   node ~/sonos-button/hardware_test.js"
echo "4. Setup GPIO Pull-up (MANDATORY on Bookworm):"
echo "   sudo nano /boot/firmware/config.txt"
echo "   Add: gpio=27=ip,pu"
echo "5. Reboot:"
echo "   sudo reboot"
