const config = require('./config.json');
let Gpio;

try {
    Gpio = require('onoff').Gpio;
} catch (e) {
    console.error("\n❌ CRITICAL ERROR: 'onoff' library could not be loaded.");
    console.error("This usually means 'npm install' failed or 'build-essential' is missing.");
    console.error("Try running: sudo apt install build-essential && npm install\n");
    process.exit(1);
}

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
console.log("This script will cycle through each configured LED.");
console.log("Please watch your breadboard.\n");

async function runSequence() {
    for (const room of ROOMS) {
        const gpio = room.pin;
        const physical = PIN_MAP[gpio] || "Unknown";
        
        console.log(`👉 Testing [${room.name}]`);
        console.log(`   - GPIO: ${gpio}`);
        console.log(`   - Physical Pin: ${physical}`);
        
        try {
            const led = new Gpio(gpio, 'out');
            
            console.log("   - Status: ON  💡");
            led.writeSync(1);
            
            await new Promise(r => setTimeout(r, 2000)); // Wait 2 seconds
            
            console.log("   - Status: OFF ⚫");
            led.writeSync(0);
            led.unexport();
            
        } catch (err) {
            console.error(`   ❌ ERROR accessing GPIO ${gpio}: ${err.message}`);
            if (err.code === 'EACCES') {
                console.error("      (Permission denied. Try running with 'sudo')");
            }
        }
        
        console.log("----------------------------------------");
        await new Promise(r => setTimeout(r, 1000)); // Pause between lights
    }
    console.log("✅ Test Sequence Complete.");
}

runSequence();
