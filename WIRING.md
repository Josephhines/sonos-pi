# Wiring Guide for Sonos Controller (Multi-LED)

This guide explains how to wire the Button and **5 LEDs** to your Raspberry Pi Zero 2 W. Each LED will represent a specific Sonos Room/Speaker to indicate if it is part of the group.

## Components Needed
*   **Raspberry Pi Zero 2 W** (with headers soldered)
*   **Breadboard** (Large or half-size recommended)
*   **Tactile Button**
*   **5x LEDs** (You can use different colors for different rooms)
*   **5x Resistors** (220Ω or 330Ω) - One for each LED
*   **Jumper Wires** (Male-to-Female / Male-to-Male)

## Pinout Assignments (BCM Numbering)

We will use the following GPIO pins. You can change these in `config.json` if needed.

| Component | GPIO Pin | Physical Pin | Assigned Room (Default) |
| :--- | :--- | :--- | :--- |
| **Button** | **GPIO 27** | **Pin 13** | Toggles Grouping (Living Room) |
| **LED 1** | **GPIO 17** | **Pin 11** | Living Room |
| **LED 2** | **GPIO 22** | **Pin 15** | Kitchen |
| **LED 3** | **GPIO 23** | **Pin 16** | Dining Room |
| **LED 4** | **GPIO 24** | **Pin 18** | Office |
| **LED 5** | **GPIO 25** | **Pin 22** | Future A |
| **Ground** | **GND** | **Pin 6, 9, 14, 20...** | Common Ground |

## Wiring Instructions

### 1. Wiring the Button
1.  Connect one leg of the button to **GPIO 27 (Pin 13)**.
2.  Connect the other leg to **GND (e.g., Pin 14)**.

### 2. Wiring the LEDs
Repeat this for all 5 LEDs, using the pins listed above.

1.  **Anode (+)** (Long leg): Connect to the **GPIO Pin** (e.g., GPIO 17 for LED 1).
2.  **Cathode (-)** (Short leg): Connect to a **Resistor**.
3.  **Resistor**: Connect the other end to **GND**.

*Tip: On a breadboard, connect the "Ground Rail" (blue line) to a GND pin on the Pi, then connect all resistors/button grounds to that rail.*

## Visual Diagram

```mermaid
graph LR
    subgraph Raspberry Pi Zero 2 W
        P27[GPIO 27 / Pin 13]
        P17[GPIO 17 / Pin 11]
        P22[GPIO 22 / Pin 15]
        P23[GPIO 23 / Pin 16]
        P24[GPIO 24 / Pin 18]
        P25[GPIO 25 / Pin 22]
        GND[GND / Pins 6,9,14,20...]
    end

    subgraph Components
        Btn[Button]
        L1[LED 1 (Living)]
        L2[LED 2 (Kitchen)]
        L3[LED 3 (Dining)]
        L4[LED 4 (Office)]
        L5[LED 5 (Fut A)]
        R1[Resistor]
        R2[Resistor]
        R3[Resistor]
        R4[Resistor]
        R5[Resistor]
    end

    %% Connections
    P27 --- Btn
    Btn --- GND

    P17 --- L1 --- R1 --- GND
    P22 --- L2 --- R2 --- GND
    P23 --- L3 --- R3 --- GND
    P24 --- L4 --- R4 --- GND
    P25 --- L5 --- R5 --- GND

    classDef pi fill:#d0f0c0,stroke:#333,stroke-width:2px;
    class P27,P17,P22,P23,P24,P25,GND pi;
```
