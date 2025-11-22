const axios = require('axios');
const config = require('./config.json');

const SONOS_API = config.sonosApiUrl;

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
