# SPI Slave Memory Protocol Documentation

## Overview

This SPI slave module implements a simple yet effective memory-addressed protocol for reading and writing to a 256-byte internal RAM. The slave is fully synthesizable and supports all 4 SPI clock modes.

---

## Hardware Interface

### SPI Signals

| Signal | Direction | Description |
|--------|-----------|-------------|
| `SCLK` | Input | Serial Clock (from controller/master) |
| `COPI` | Input | Controller Out, Peripheral In (MOSI) |
| `CIPO` | Output | Controller In, Peripheral Out (MISO) |
| `NCS`  | Input | Chip Select (active low) |

### Configuration

| Signal | Width | Description |
|--------|-------|-------------|
| `spi_mode` | 2 bits | {CPOL, CPHA} - SPI clock mode (0-3) |

### Status/Control

| Signal | Direction | Description |
|--------|-----------|-------------|
| `mem_wr_en` | Output | Memory write enable pulse |
| `mem_wr_data` | Output | Data written to memory |
| `mem_addr` | Output | Address being written |

---

## SPI Clock Modes

The slave supports all 4 standard SPI modes:

| Mode | CPOL | CPHA | Clock Idles | Sample Edge | Change Edge |
|------|------|------|-------------|-------------|-------------|
| 0    | 0    | 0    | Low         | Rising      | Falling     |
| 1    | 0    | 1    | Low         | Falling     | Rising      |
| 2    | 1    | 0    | High        | Falling     | Rising      |
| 3    | 1    | 1    | High        | Rising      | Falling     |

---

## Protocol Specification

### Transaction Structure

Each SPI transaction consists of:
1. **Address Byte** (8 bits) — specifies operation and starting address
2. **Data Bytes** (1 to N) — read or written data

### Address Byte Format

```
Bit 7:  R/W bit (1 = Read, 0 = Write)
Bit 6-0: Memory Address (0x00 - 0x7F)
```

**Example:**
- `0x00` → Write to address 0x00
- `0x7F` → Write to address 0x7F
- `0x80` → Read from address 0x00
- `0xFF` → Read from address 0x7F

---

## Integration Checklist

- [ ] Set `spi_mode` to match your SPI controller mode
- [ ] Connect NCS to controller's chip select output
- [ ] Ensure SCLK, COPI, CIPO are properly connected
- [ ] Apply active-low reset during power-up
- [ ] Verify CIPO tri-state or open-drain implementation in your design
- [ ] Run testbench with your SPI controller timing

---

## References

- [SPI Bus Protocol](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)
- [CPOL and CPHA Explanation](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface#Clock_polarity_and_phase)
- [Motorola SPI Standard](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)