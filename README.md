# 💡 Blinky Driver — HW-SW Co-Design on AMD Kria KR260

> **An introductory hardware-software co-design project** demonstrating a complete SoC design flow — from custom RTL in the FPGA fabric to Python-based software control on the ARM processor.

[![Platform](https://img.shields.io/badge/Platform-AMD%20Kria%20KR260-ED1C24?style=for-the-badge&logo=amd&logoColor=white)](https://www.xilinx.com/products/som/kria/kr260-robotics-starter-kit.html)
[![Tool](https://img.shields.io/badge/Tool-Vivado%202023.1-FF6600?style=for-the-badge)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Language](https://img.shields.io/badge/HDL-Verilog-blue?style=for-the-badge)]()
[![Language](https://img.shields.io/badge/SW-Python%203-3776AB?style=for-the-badge&logo=python&logoColor=white)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)]()

---

## 🧭 What is HW-SW Co-Design?

**Hardware-Software Co-Design** is the practice of developing the hardware (FPGA/RTL) and software (processor code) components of an embedded system **together**, as a unified design flow. Instead of treating hardware and software as separate silos, co-design enables:

- **Tight integration** — Software directly controls custom hardware IP via memory-mapped registers.
- **Performance optimization** — Offload time-critical tasks (like PWM generation) to hardware, while keeping flexibility in software.
- **Rapid prototyping** — Iterate on both sides using modern SoC platforms like AMD Zynq UltraScale+.

This project serves as a **beginner-friendly, end-to-end example** of HW-SW co-design on the AMD Kria KR260 SoC platform.

---

## 📋 Project Overview

**Blinky Driver** implements a **PWM-based LED brightness controller** where:

| Layer | What | How |
|-------|-------|-----|
| **Hardware (PL)** | PWM signal generation | Custom Verilog RTL in FPGA Programmable Logic |
| **Interface** | Register-based control | AXI4-Lite slave IP (memory-mapped at `0xA000_0000`) |
| **Software (PS)** | Brightness control | Python script on ARM Cortex-A53 via `/dev/mem` |

The ARM processor writes brightness values (0–255) to AXI registers, and the FPGA fabric generates a corresponding PWM waveform to drive an LED on the PMOD connector.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Kria KR260 SoC                    │
│                                                     │
│  ┌──────────────┐    AXI4-Lite    ┌──────────────┐  │
│  │  PS (ARM A53) │◄──────────────►│  PL (FPGA)   │  │
│  │               │                │              │  │
│  │  Python App   │   0xA0000000   │  AXI-Lite IP │  │
│  │  ┌─────────┐  │   ┌────────┐   │  ┌────────┐  │  │
│  │  │ /dev/mem │──┼──►│ REG[0] │───┼─►│ Enable │  │  │
│  │  │  mmap   │  │   │ REG[1] │───┼─►│Bright. │  │  │
│  │  └─────────┘  │   └────────┘   │  └───┬────┘  │  │
│  └──────────────┘                │      │       │  │
│                                  │  ┌───▼────┐  │  │
│                                  │  │  PWM   │  │  │
│                                  │  │ Module │  │  │
│                                  │  └───┬────┘  │  │
│                                  └──────┼──────┘  │
│                                         │         │
└─────────────────────────────────────────┼─────────┘
                                          │ PWM Out
                                     ┌────▼────┐
                                     │   LED   │
                                     │ (PMOD)  │
                                     └─────────┘
```

---

## 🔧 Design Flow (Step-by-Step)

### Phase 1: Hardware Design (Vivado)

| Step | Description |
|------|-------------|
| **1. Create PWM RTL** | Write `blinky_driver.v` — a Verilog PWM module with `clk`, `reset`, `enable`, `brightness[7:0]`, and `pwm_out` signals |
| **2. Create AXI-Lite IP** | Use Vivado's *Create and Package New IP* wizard to generate an AXI4-Lite peripheral with 4 registers |
| **3. Integrate PWM into IP** | Edit `myip_v1_0_S00_AXI.v` to expose `enable` and `brightness` outputs; instantiate PWM module in `myip_v1_0.v` |
| **4. Package IP** | Add the PWM `.v` file to IP Packager → File Groups (both Synthesis & Simulation), then re-package |
| **5. Block Design** | Create a block design with Zynq UltraScale+ MPSoC, custom AXI IP, AXI Interconnect, and Processor System Reset |
| **6. Constraints (XDC)** | Map `pwm_out` to a PMOD pin using the KR260 schematic → K26 SOM datasheet → XDC pin mapping |
| **7. Generate Bitstream** | Validate design, enable `.bin` file generation, and run bitstream synthesis |
| **8. Export Hardware** | Export `.xsa` with bitstream included; rename `.bin` to `.bit.bin` |

### Phase 2: Device Tree & Firmware

| Step | Description |
|------|-------------|
| **9. Generate DTBO** | Use XSCT + `device-tree-xlnx` repo to generate a device tree overlay (`.dtbo`) from the `.xsa` |
| **10. Create shell.json** | Define the accelerator shell metadata (`XRT_FLAT`, 1 slot) |
| **11. Deploy to KR260** | Copy `.bit.bin`, `.dtbo`, and `shell.json` to `/lib/firmware/xilinx/Blinky_driver/` on the board |
| **12. Load Firmware** | Use `xmutil loadapp Blinky_driver` to load the FPGA overlay at runtime |

### Phase 3: Software Control

| Step | Description |
|------|-------------|
| **13. Run Python Script** | Execute `blinky_test.py` with `sudo` to control LED brightness via memory-mapped AXI registers |

---

## 📁 Register Map

| Register | Address | Function |
|----------|---------|----------|
| `slv_reg0` | `0xA000_0000` | **Enable** — Write `1` to enable PWM, `0` to disable |
| `slv_reg1` | `0xA000_0004` | **Brightness** — Write `0–255` to set PWM duty cycle |

---

## 🐍 Software: Python Control Script

```python
#!/usr/bin/env python3
import mmap, os, struct, time

AXI_BASE_ADDR = 0xA0000000
MAP_SIZE = 0x1000

REG_ENABLE     = 0x00   # slv_reg0
REG_BRIGHTNESS = 0x04   # slv_reg1

fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
mem = mmap.mmap(fd, MAP_SIZE, mmap.MAP_SHARED,
                mmap.PROT_READ | mmap.PROT_WRITE,
                offset=AXI_BASE_ADDR)

def write_reg(offset, value):
    mem.seek(offset)
    mem.write(struct.pack("<I", value))

try:
    write_reg(REG_ENABLE, 1)
    print("PWM Enabled")

    for b in [0, 32, 64, 128, 192, 255]:
        write_reg(REG_BRIGHTNESS, b)
        print(f"Brightness = {b}")
        time.sleep(2)

    write_reg(REG_ENABLE, 0)
    print("PWM Disabled")
finally:
    mem.close()
    os.close(fd)
```

```bash
chmod +x blinky_test.py
sudo python3 blinky_test.py
```

---

## 🧪 Testing & Verification

### Option A: Digital Storage Oscilloscope (DSO)
- Connect DSO ground to PMOD GND, probe to PWM signal pin
- Observe PWM waveform — duty cycle changes with brightness value

### Option B: Onboard User LED
- The LED brightness varies proportionally with the register value
- `255` = full brightness, `0` = off

---

## 📌 Pin Mapping Methodology

To find the correct FPGA pin for the PMOD connector:

1. **KR260 Schematic** → Find PMOD signal → Note the SOM ball name (e.g., `SOM240_1`)
2. **K26 SOM Datasheet** (`ds987-k26-som.pdf`) → Map SOM ball → FPGA package pin (e.g., `D14`)
3. **XDC File** (`Kria_K26_SOM_Rev1.xdc`) → Confirm pin constraint

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| `.v` file not found during synthesis | Add RTL file in IP Packager → File Groups → Verilog Synthesis & Simulation |
| PWM pin not visible in block design | Re-package IP and upgrade the IP in the block design |
| LED not glowing | Double-check XDC pin mapping against schematic/datasheet |
| Python permission error | Always run with `sudo` (required for `/dev/mem` access) |
| AXI not responding | Verify base address in the Address Editor matches your script |

---

## 🛠️ Tools & Requirements

| Component | Details |
|-----------|---------|
| **Board** | AMD Kria KR260 Robotics Starter Kit |
| **SoC** | Zynq UltraScale+ (K26 SOM) — ARM Cortex-A53 + FPGA |
| **Design Tool** | AMD Vivado 2023.1 |
| **SDK** | AMD Vitis / XSCT 2023.1 |
| **Board OS** | Ubuntu 22.04 (Kria certified) |
| **HDL** | Verilog |
| **Software** | Python 3 |
| **Device Tree** | Xilinx device-tree-xlnx repository |

---



---

## 🎯 Key Takeaways

This project demonstrates the **complete HW-SW co-design lifecycle**:

- **Custom RTL Design** — Writing synthesizable Verilog for FPGA
- **AXI4-Lite Integration** — Industry-standard bus protocol for PS-PL communication
- **IP Packaging** — Creating reusable, parameterized IP blocks in Vivado
- **Device Tree Overlays** — Dynamic FPGA reconfiguration on Linux
- **Memory-Mapped I/O** — Direct hardware register access from userspace Python
- **SoC Platform Deployment** — End-to-end flow on production-grade AMD Kria hardware

> *"The best way to learn SoC design is to build one end-to-end. This project takes you from Verilog to a blinking LED — touching every layer of the stack."*

---

## 📚 References

- [Kria KR260 Documentation](https://www.xilinx.com/products/som/kria/kr260-robotics-starter-kit.html)
- [Kria Application Development Guide](https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/index.html)
- [Xilinx Device Tree Repository](https://github.com/Xilinx/device-tree-xlnx)
- [Vivado Design Suite User Guide](https://docs.xilinx.com/r/en-US/ug910-vivado-getting-started)

---

## 📝 License

This project is open-source and available under the [MIT License](LICENSE).

---

<p align="center">
  <b>Built with ❤️ on AMD Kria KR260 | HW-SW Co-Design Made Simple</b>
</p>
