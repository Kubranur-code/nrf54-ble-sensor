# nRF54L10 BLE Sensor Board

A small Bluetooth Low Energy sensor board built around Nordic's nRF54L10. The chip is placed directly on the board, not used through a radio module. It runs from a single CR2032 coin cell, measures temperature, humidity and motion, and transmits through a PCB antenna I laid out myself. The board is 35 × 45 mm, has four layers and is designed in KiCad 9 for assembly at JLCPCB.

![Top view of the board](docs/img/render-top.png)

*Top side. The antenna is in the top-left corner, the nRF54L10 is in the middle and the coin-cell holder takes up the lower half. All parts are on this side.*

## Why I built this

Most hobby BLE boards use a pre-certified module. The module hides the hardest part of the design: the RF matching, the antenna and the ground around them. I wanted to do that part myself, so this board uses the bare QFN48 chip with Nordic's matching network and a printed inverted-F antenna. I added a small tuning network between them so the antenna can later be measured and adjusted with a VNA without a new board.

The second goal was low power. The board has no regulator and no power switch, and the accelerometer wakes the chip only when the board moves. A coin cell should therefore last a long time.

## Hardware overview

| | |
|---|---|
| SoC | nRF54L10-QFAA (Cortex-M33, 1 MB RRAM, 192 KB RAM, Bluetooth LE) |
| Sensors | Sensirion SHT40 (temperature/humidity), ST LIS2DH12 (accelerometer), shared I²C bus |
| Power | CR2032 straight to VDD, internal DC/DC converter, 47 µF buffer capacitor |
| Clocks | 32 MHz crystal, 32.768 kHz crystal |
| Antenna | Inverted-F PCB antenna (TI SWRA117D) after a 0 Ω + 2 × DNP π network |
| Debug | 10-pin 1.27 mm Cortex Debug connector (SWD + SWO), test pad for timing current measurements |
| User I/O | One button, one LED |
| PCB | 35 × 45 mm, 4 layers, JLC04161H-1080 stackup, ENIG |

## Design notes

### Choosing the nRF54L10

I started with the nRF54L15, because there are already many open nRF52 designs and the nRF54L series is newer and uses less power. When I checked stock, JLCPCB had no L15, so I switched to the nRF54L10. It is pin compatible and has less memory, which this application does not need. I checked the schematic symbol pin by pin against both datasheets before changing the part.

### Running from a coin cell

The nRF54L works from 1.7 to 3.6 V, so a regulator between the cell and the chip would only add its own quiescent current. Instead, the chip's internal DC/DC converter is enabled with the 4.7 µH inductor from Nordic's reference design. A CR2032 has a high internal resistance and cannot deliver the radio's current peaks cleanly, so a 47 µF ceramic capacitor next to the holder covers them.

The LIS2DH12 stays in its low-power mode and its INT1 pin can wake the nRF54L10 from System OFF. The radio therefore only runs when something happens. Its address pin SA0 is tied to VDD, because the pin has an internal pull-up and tying it to ground would draw a small but constant current.

### Clocks

The chip can run its low-frequency clock from an internal RC oscillator, but that oscillator drifts with temperature. It has to be recalibrated regularly, which means starting the 32 MHz crystal, and its larger error forces wider BLE receive windows. Both cost more energy over time than a small 32.768 kHz crystal, so the board has one. Both crystals use the chip's internal load capacitors.

### RF path and antenna

The matching network between the ANT pin and the 50 Ω point is copied part for part from Nordic's QFAA reference layout, using the same Murata 0201 inductors and capacitors. I also kept the reference's ground return for the VSS_PA shunt capacitor: it goes back to the chip only on the top layer, not through a via. After the 50 Ω point comes a 0402 π network with a 0 Ω resistor and two unpopulated capacitor pads (C13, C14). These are the pads I will use to tune the antenna once I can measure it.

The SoC, the matching network and the antenna feed are placed on one straight line, so the RF trace from the ANT pin to the antenna has no bends. The antenna area is kept free of copper on all four layers, and a row of ground vias runs along the RF path.

### Stackup

I used JLCPCB's JLC04161H-1080 stackup. Its prepreg between the top layer and the first ground plane is only 0.076 mm thick. A thin dielectric keeps the ground close under the ANT pin, which Nordic recommends for suppressing harmonics. It also makes the 50 Ω line narrow enough for 0201 pads: as a grounded coplanar waveguide the line is 0.13 mm wide with 0.15 mm gaps.

| Layer | Use |
|---|---|
| L1 | Components, RF, most signals |
| L2 | Solid ground plane |
| L3 | VDD plane, one short signal |
| L4 | Ground pour, signals that change layer |

### Layout

The hardest part of the layout was the left side of the QFN. Its 0.4 mm pitch pins carry the button, the LED, both I²C lines, the accelerometer interrupt and the DC/DC loop. In the first placement the I²C pull-ups and the ferrite bead were directly in front of these pins, and there was no room to get the traces out. The autorouter failed here as well. Pull-ups work anywhere on the bus, so I moved them down next to the humidity sensor. The remaining traces that could not escape on the top layer change to the bottom layer through vias. The ground plane under all top-layer signals stays unbroken.

The DECRF pin needs a connection to DECA on the other side of the chip, and on the top layer that path is blocked by the crystal traces. I copied the solution from Nordic's layout: the DECRF capacitor sits right at the pin, and a via behind it carries the connection on the bottom layer to the DECA side.

The ground pours on L1 and L4 are stitched to the L2 plane with vias on a 2.5 mm grid, about λ/25 at 2.4 GHz. ERC and DRC, including schematic parity, finish with no violations. The reports are in `fab/`.

![Bottom view of the board](docs/img/render-bottom.png)

*Bottom side: ground pour, stitching vias and the few signals that use L4. The antenna keep-out appears top-right because the view is mirrored.*

## Project status

The design is finished, but the board has **not been manufactured yet**. Nothing in this repository has been tested on real hardware. Once the boards arrive, my next steps are:

1. Bring-up over SWD, then a BLE advertising test with sensor readings
2. Measuring the antenna with a NanoVNA and tuning it on the C13/C14 pads if needed
3. Measuring the sleep current and the current of one advertising event

I will add the measurements and any corrections here.

## Ordering from JLCPCB

1. Upload `fab/nrf54-ble-sensor-gerbers.zip`. Select 4 layers, 1.6 mm thickness, ENIG and impedance control with the JLC04161H-1080 stackup.
2. For assembly, upload `fab/nrf54-ble-sensor-bom.csv` and `fab/nrf54-ble-sensor-cpl.csv`. C13 and C14 are left out on purpose.
3. Check the part rotations in JLCPCB's placement preview before ordering. Their library sometimes uses a different orientation than KiCad, most often for QFN, LGA and crystal packages.

## Repository layout

```
nrf54-ble-sensor.kicad_*   KiCad 9 project
lib/                       symbols, footprints and 3D models not in the KiCad library
docs/                      schematic PDF and renders
fab/                       Gerbers, drill files, BOM, CPL, ERC/DRC reports
scripts/export.sh          regenerates everything in fab/ and docs/
```

All outputs are generated with `kicad-cli` by running `bash scripts/export.sh`. The 3D models of the two crystals and the SHT40 are from the LCSC/EasyEDA part library.

## References

- Nordic Semiconductor, nRF54L15/L10 product specification and QFAA reference layout v0.8
- Texas Instruments, SWRA117D, *2.4 GHz Inverted F Antenna*
- Nordic DevZone discussions on ANT pin ground distance and harmonics
- JLCPCB impedance-controlled stackups

## License

Copyright 2026 Kübranur Cici.

The hardware design files in this repository are licensed under the [CERN Open Hardware Licence Version 2 – Strongly Reciprocal](LICENSE) (CERN-OHL-S-2.0). The 3D models in `lib/parts.3dshapes` and the Nordic reference material referred to above belong to their respective owners and are not covered by this licence.
