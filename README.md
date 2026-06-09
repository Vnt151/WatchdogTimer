# Watchdog Timer System for Gowin FPGA (GW1N-1P5)

## Overview

A flexible watchdog timer system implemented on **Gowin GW1N-1P5** FPGA (Kiwi 1P5 board), featuring software-configurable timeouts, dual kick sources (hardware button and UART command), and LED status indicators.

---

## Features

| Feature | Description |
|---------|-------------|
| **Configurable timeouts** | tWD (watchdog) and tRST (fault reset) adjustable via UART |
| **Arming delay** | Configurable delay before monitoring starts |
| **Dual kick sources** | Physical button (S1) or UART command (0x03) |
| **Dual enable sources** | Physical button (S2) or software bit (CTRL[0]) |
| **UART interface** | 9600 baud, register read/write, status query |
| **LED indicators** | D4 (ENOUT), D3 (WDO) |

---

## Open-Drain Simulation (Method B)

The TPS3431 uses open-drain outputs for WDO and ENOUT. This implementation uses **Method B** (push-pull simplification):

- **Why**: Kiwi 1P5 board LEDs have no external pull-ups; demo only requires visual indication
- **WDO**: Active-low signal → inverted before driving LED (fault = LED on)
- **ENOUT**: Active-high signal → direct connection

### LED Display Convention

| LED | Signal | Meaning | State |
|-----|--------|---------|-------|
| **D4 (ENOUT)** | `enout_logic = 1` | Monitoring active | ON |
| **D4 (ENOUT)** | `enout_logic = 0` | Idle/Arming | OFF |
| **D3 (WDO)** | `wdo_logic = 0` | Fault timeout | ON |
| **D3 (WDO)** | `wdo_logic = 1` | Normal operation | OFF |

> WDO is active-low. LED lights during fault because `led3_wdo = ~wdo_logic`.

---

## Hardware Requirements

| Component | Description |
|-----------|-------------|
| **FPGA** | Gowin GW1N-1P5 (Kiwi 1P5 board) |
| **Clock** | Internal oscillator (25MHz) |
| **Buttons** | S1 (WDI), S2 (EN) – active low |
| **LEDs** | D3 (WDO), D4 (ENOUT) – active high |
| **UART** | USB-UART module (9600 baud) |

---

## Module Architecture
watchdog_top
├── Gowin_OSC # 25MHz internal oscillator
├── sys_timebase # tick_1us, tick_1ms generators
├── io_debounce # Button debouncing (20ms)
├── config_subsystem # UART + register file
│ ├── uart_transceiver # UART physical layer
│ └── regfile_and_parser # Command parser
├── watchdog_fsm_core # Main FSM logic
└── io_buffers # LED outputs (Method B)

---

## UART Protocol

### Configuration
- **Baud rate**: 9600
- **Data bits**: 8
- **Stop bits**: 1
- **Parity**: None

### Packet Format
55 CMD ADDR LEN [DATA...] CHKSUM

### Commands

| CMD | Name | Description | Response |
|-----|------|-------------|----------|
| 0x01 | Write | Write to register | 0xAA |
| 0x02 | Read | Read from register | Data bytes |
| 0x03 | Kick | Software kick | 0xAA |
| 0x04 | Get Status | Read status[7:0] | 1 byte |

### Registers

| Address | Register | Width | Default | Access |
|---------|----------|-------|---------|--------|
| 0x00 | CTRL | 32 | 0 | R/W |
| 0x04 | tWD | 32 | 1600 | R/W |
| 0x08 | tRST | 32 | 200 | R/W |
| 0x0C | arm_delay | 16 | 150 | R/W |
| 0x10 | STATUS | 32 | - | Read-only |

### Checksum Calculation
CHKSUM = CMD ^ ADDR ^ LEN ^ DATA[0] ^ ... ^ DATA[n]

## State Machine
IDLE ──(EN=1)──> ARMING ──(delay)──> MONITOR ──(timeout)──> FAULT
▲ │ │
└────(kick)──────────┘ │
└──────────(tRST)─────────────────────────┘

| State | WDO | ENOUT | LED D3 | LED D4 |
|-------|-----|-------|--------|--------|
| IDLE | 1 | 0 | OFF | OFF |
| ARMING | 1 | 0 | OFF | OFF |
| MONITOR | 1 | 1 | OFF | ON |
| FAULT | 0 | 1 | ON | ON |

---

## Build Instructions

### Prerequisites
- **Gowin EDA** (v1.9.12.02 SP2 or later)
- **Kiwi 1P5 board** (GW1N-1P5)

### Steps

1. **Launch Gowin EDA** → Create new project
2. **Select device**: GW1N-1P5 → GW1N-1P5C → QN48C7/I6
3. **Add source files**: All `.v` files from the project
4. **Synthesize**: `Process → Synthesize` (Ctrl+F7)
5. **Place & Route**: `Process → Place & Route` (F7)
6. **Generate Bitstream**: `Process → Generate Bitstream`
7. **Program**: `Tools → Programmer` → Load `.fs` file → Program

---

## Demo Instructions

### Hardware Setup

1. Connect USB-UART module to FPGA:
   - TX → `uart_rx`
   - RX → `uart_tx`
   - GND → GND
2. Power the Kiwi 1P5 board
3. Open serial terminal (9600 baud, 8N1)

### Test Cases

| Test | Action | Expected LED Behavior |
|------|--------|----------------------|
| **1** | Press S2 (EN) | D4 ON after ~150µs |
| **2** | Send `55 01 00 04 01 00 00 00 04` | D4 ON |
| **3** | Press S1 (kick) before timeout | D3 stays OFF |
| **4** | Send `55 03 00 00 03` (kick) | D3 stays OFF |
| **5** | Enable, wait 1.6s (no kick) | D3 ON (fault), then OFF after 200ms |
| **6** | During fault, send clear command | D3 OFF immediately |

### LED Quick Reference

| LED D4 (ENOUT) | LED D3 (WDO) | Meaning |
|----------------|--------------|---------|
| OFF | OFF | IDLE or ARMING |
| ON | OFF | MONITOR (normal) |
| ON | ON | FAULT (timeout) |

---

## File List

| File | Description |
|------|-------------|
| `watchdog_top.v` | Top module |
| `sys_timebase.v` | Timer generators (1us, 1ms) |
| `io_debounce.v` | Button debouncer |
| `watchdog_fsm_core.v` | Main FSM |
| `config_subsystem.v` | UART + register wrapper |
| `uart_transceiver.v` | UART RX/TX |
| `regfile_and_parser.v` | Command parser |
| `io_buffers.v` | LED drivers (Method B) |
| `gowin_osc.v` | Internal oscillator |

---

## Notes

- Internal oscillator runs at 25MHz (`FREQ_DIV = 10`)
- Default timings: tWD = 1600ms, tRST = 200ms, arm_delay = 150µs
- Method B (push-pull) is used for open-drain simulation – sufficient for LED demo
- For true open-drain, modify `io_buffers.v` to use `inout` ports with tri-state control