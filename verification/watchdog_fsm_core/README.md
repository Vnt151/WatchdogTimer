# Verification Report: Watchdog FSM Core Module

## 1. Overview
This document outlines the test scenarios and verification results for the `watchdog_fsm_core` module. The primary objective of this testbench (`tb_watchdog_fsm_core.v`) is to mathematically and visually prove that the 4-state Finite State Machine (FSM) correctly manages system monitoring. This includes validating the $150 \mu s$ arming window safety, the dual-source kick mechanism (Hardware/Software), and the precision of the Watchdog Timer (tWD) and Reset Timer (tRST) during fault events.

## 2. Test Environment
* **Device Under Test (DUT)**: `watchdog_fsm_core.v`
* **Testbench**: `tb_watchdog_fsm_core.v` (Accelerated Tick Architecture)
* **Simulation Tool**: ModelSim (Intel FPGA Edition)
* **System Clock**: 100 MHz (10ns period)
* **Time Scaling**: 1ms simulated as 10us for rapid verification

## 3. Test Scenarios & Execution

### Test Case 1: FSM Initiation & Arming Window
* **Configuration**: System reset released; `en_clean` asserted HIGH.
* **Stimulus**: Inject dummy hardware kicks during the first $150 \mu s$ of operation.
* **Expected Result**: The FSM must remain in ST_ARMING (1) and `enout_logic` must stay LOW. Kicks must be ignored until the `arm_delay_us` threshold is reached.
* **Status**: PASSED

### Test Case 2: Multi-Source Kick & Timer Reset
* **Configuration**: FSM in ST_MONITOR (2) state.
* **Stimulus**: Apply falling edges to `wdi_clean` (Hardware) followed by `sw_kick` pulses (Software).
* **Expected Result**: The internal `timer_ms` must reset to 0 immediately upon each kick detection. The `status_out[4]` bit must correctly reflect the last kick source (0 for HW, 1 for SW).
* **Status**: PASSED

### Test Case 3: Watchdog Timeout (Fault Assertion)
* **Configuration**: Active monitoring; kicks are intentionally stopped.
* **Stimulus**: Allow `timer_ms` to reach the configured `tWD_ms` (50ms).
* **Expected Result**: The `wdo_logic` signal must assert LOW (active-low fault) and `current_state` must transition to ST_FAULT (3).
* **Status**: PASSED

### Test Case 4: Fault Recovery & UART Overrides
* **Configuration**: System in ST_FAULT (3) state.
* **Stimulus**: Assert `ctrl_reg[2]` (CLR_FAULT) via UART before tRST expires.
* **Expected Result**: The system must immediately clear the fault, pulling `wdo_logic` HIGH and returning the FSM to ST_MONITOR (2).
* **Status**: PASSED

### Test Case 5: Dynamic Parameter Reconfiguration
* **Configuration**: System running in ST_MONITOR (2).
* **Stimulus**: Update `tWD_ms` from 50ms to 100ms via the 32-bit input bus.
* **Expected Result**: The system must operate under the new timeout threshold without requiring a reset or returning to IDLE.
* **Status**: PASSED

## 4. Verification Artifacts
The concrete evidence of this verification phase is stored alongside this document:
* **Transcript Log**: `watchdog_sim_log.txt` – Contains the automated simulation output, showing 8 successful test case assertions and status register validations.
* **Waveform Evidence (Arming Delay)**: `wf_arming_window.png` – Visual confirmation of the $150 \mu s$ lockout period and `enout_logic` latency.
* **Waveform Evidence (Timeout/Recovery)**: `wf_timeout_recovery.png` – Visual proof of `wdo_logic` assertion at exactly 1.25ms (simulated) and successful UART override.

---
*Note: A consistent 2-cycle clock latency is observed across all output transitions, confirming the stability of the synchronous registered output design.*