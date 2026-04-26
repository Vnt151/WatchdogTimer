# Verification Report: Watchdog Timer Module

## 1. Overview
This document outlines the test scenarios and verification results for the `watchdog_top` module. The primary objective of this testbench (`tb_watchdog_top.v`) is to experimentally prove that the hardware logic correctly performs watchdog supervision (similar to TPS3431), reliably handles the UART configuration protocol, and strictly manages physical peripherals (buttons, LEDs) on the Kiwi 1P5 board without logic contention.

## 2. Test Environment
* **Device Under Test (DUT)**: `watchdog_top.v`
* **Testbench**: `tb_watchdog_top.v` (Self-checking architecture)
* **Simulation Tool**: ModelSim (Intel FPGA Edition)
* **System Clock**: 25 MHz (40ns period)

## 3. Test Scenarios & Execution

### Test Case 1: Power-On Reset (POR) & Initialization
* **Configuration**: System power-up; buttons in idle state (Active-High).
* **Stimulus**: Wait for the 8-bit `por_cnt` counter to reach its maximum value.
* **Expected Result**: The `rst_n_por` signal must remain LOW for exactly 256 clock cycles (~10.22us) before transitioning to HIGH to activate the system.
* **Status**: PASSED

### Test Case 2: Hardware Enable & Arming Delay
* **Configuration**: System reset is released; FSM is in IDLE state.
* **Stimulus**: Press the S2 button (`s2_en = 0`) for 22ms.
* **Expected Result**: The `en_clean` signal must transition to LOW after the 20ms debounce period; the FSM must then wait for an additional 150us (Arming Delay) before asserting `led4_enout` to 1.
* **Status**: PASSED

### Test Case 3: UART Dynamic Configuration
* **Configuration**: System is in MONITOR state (LED4 is ON).
* **Stimulus**: Inject a UART frame to write 50ms into the `tWD_ms` register (Addr 0x04).
* **Expected Result**: The Parser module must correctly decode the XOR checksum and update the `reg_twd` register immediately.
* **Status**: PASSED

### Test Case 4: Hardware Kick (Input Debounce)
* **Configuration**: Watchdog is actively monitoring the timeout period.
* **Stimulus**: Press the S1 button (`s1_wdi = 0`) for 22ms.
* **Expected Result**: The falling edge of the debounced signal (`wdi_clean`) must be detected to reset the `timer_ms` counter to 0, preventing an early timeout.
* **Status**: PASSED

### Test Case 5: Watchdog Timeout & Fault Detection
* **Configuration**: Watchdog is running with `tWD = 50ms`.
* **Stimulus**: Suspend all hardware and software kick stimuli.
* **Expected Result**: When `timer_ms` reaches the 50ms threshold, the FSM must transition to `ST_FAULT` and assert `led3_wdo` to 1 to signal an error.
* **Status**: PASSED

### Test Case 6: Software Clear (Fault Recovery)
* **Configuration**: System is in FAULT state (LED3 is ON).
* **Stimulus**: Send a UART command to write bit 2 of the CTRL register (Addr 0x00).
* **Expected Result**: The FSM must recognize the `CLR_FAULT` command, return to the `ST_MONITOR` state, and immediately de-assert LED3.
* **Status**: PASSED

## 4. Verification Artifacts
Concrete evidence of this verification phase is stored alongside this report:
* **Transcript Log**: `watchdog_sim_log.txt` - Contains the simulation output log, confirming the successful execution of all 6 test cases.
* **Waveform Evidence**: `POR.png`, `debounce.png` - Visual confirmation of Power-On Reset, 20ms debounce timing, and FSM state transitions triggered by UART/Button stimuli.