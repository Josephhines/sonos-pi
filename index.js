const Gpio = require('onoff').Gpio;
const axios = require('axios');
const config = require('./config.json');

// --- Configuration ---
const SONOS_API = config.sonosApiUrl;
const ROOM = config.roomName; // The room this controller manages
const TARGET_ROOM = config.targetJoinRoom; // The room to join if not grouped
const LED_PIN = config.ledPin;
const BUTTON_PIN = config.buttonPin;
const DEBOUNCE = config.debounceTimeout;

// --- GPIO Setup ---
// LED: Output
let led;
// Button: Input with internal Pull-Up (falling edge trigger)
let button;

try {
    led = new Gpio(LED_PIN, 'out');
    button = new Gpio(BUTTON_PIN, 'in', 'falling', { debounceTimeout: DEBOUNCE });
} catch (e) {
    console.error("Error initializing GPIO. Are you running on a Raspberry Pi?");
    console.error(e);
    // Mock GPIO for testing on non-Pi systems
    led = { writeSync: (val) => console.log(`[MOCK] LED -> ${val}`) };
    button = { watch: () => {} };
}

console.log(`Sonos Controller started for room: ${ROOM}`);

// --- State ---
let isGrouped = false;

// --- Functions ---

/**
 * Check the current state of the Sonos room and update LED.
 */
async function checkState() {
    try {
        // Get state for the specific room
        const response = await axios.get(`${SONOS_API}/${encodeURIComponent(ROOM)}/state`);
        const state = response.data;

        // Determine if grouped.
        // Usually, a standalone room has a zoneGroup where members.length == 1
        // If members.length > 1, it's in a group.
        // Alternatively, check if 'groupName' differs or check 'subGrouping'.
        
        // node-sonos-http-api state object usually has a 'zoneState' or we can check /zones
        
        // Let's query /zones to be sure about grouping
        const zonesResponse = await axios.get(`${SONOS_API}/zones`);
        const zones = zonesResponse.data;

        const myZone = zones.find(z => z.members.some(m => m.roomName === ROOM));

        if (myZone && myZone.members.length > 1) {
            isGrouped = true;
            led.writeSync(1); // LED ON
        } else {
            isGrouped = false;
            led.writeSync(0); // LED OFF
        }
        
    } catch (error) {
        console.error("Error fetching Sonos state:", error.message);
        // Blink LED to indicate error?
        led.writeSync(0);
    }
}

/**
 * Toggle Group Membership
 */
async function toggleGroup() {
    console.log("Button Pressed!");
    
    // Refresh state first to be accurate
    await checkState();

    if (isGrouped) {
        console.log(`Leaving group...`);
        try {
            await axios.get(`${SONOS_API}/${encodeURIComponent(ROOM)}/leave`);
        } catch (err) {
            console.error("Failed to leave group:", err.message);
        }
    } else {
        console.log(`Joining ${TARGET_ROOM}...`);
        try {
            await axios.get(`${SONOS_API}/${encodeURIComponent(ROOM)}/join/${encodeURIComponent(TARGET_ROOM)}`);
        } catch (err) {
            console.error(`Failed to join ${TARGET_ROOM}:`, err.message);
        }
    }
    
    // Update state after action
    setTimeout(checkState, 2000); // Wait a bit for Sonos to update
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

// 3. Poll State every 5 seconds to keep LED in sync (in case changed via App)
setInterval(checkState, 5000);

// 4. Cleanup on Exit
process.on('SIGINT', _ => {
    led.writeSync(0);
    if (led.unexport) led.unexport();
    if (button.unexport) button.unexport();
    process.exit();
});
