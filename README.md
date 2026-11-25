# FM-11 Boot Diagnostics

Standalone **6809** boot-ROM, IPL and tiny boot payload for investigating
FDC timing, DRQ and HD6844 DMA regressions. This intentionally avoids
NitrOS-9, disk drivers and the filesystem.

## Build

Requires `lwasm`, Python 3 and `make` on Linux.

```sh
make
make check
```

Outputs:

| Image | Purpose |
| --- | --- |
| `build/diag_boot_2d.bin` | 4096-byte ROM mapped at $5000–$5FFF; reset vector $5000 |
| `build/diag_boot_2hd.bin` | Same ROM for the 2HD controller |
| `build/diag_2d.d88` | 2D: 40 cylinders, 2 heads, 16×256 B/track |
| `build/diag_2hd.d88` | 2HD: 77 cylinders, 2 heads, 26 sectors/track; C0/H0 is 128 B FM |

The two diagnostic ROMs are deliberately distinct; select the ROM matching
the boot disk's controller.

## Run in fm11-emulator

Configure `fm11-sdl` (or `fm11-headless`) with the appropriate
`--main-rom build/diag_boot_2d.bin` or
`--main-rom build/diag_boot_2hd.bin`, and the corresponding
`--floppy-d88 build/diag_2d.d88` or `--floppy-d88 build/diag_2hd.d88`.
Use the emulator's configured **main 6809 CPU** and USART0 PTY/serial output;
adjust the image paths to be relative to your emulator working directory.
The exact floppy-drive attachment flags/configuration depend on the current
emulator configuration.

Run the same combination first with `[floppy] timing = fast`, then
`[floppy] timing = timed`.

After launching the emulator, connect picocom to its USART0 PTY and **press one key** (for example Enter). The diagnostic ROM waits for RXRDY before sending its first message. No prompt is printed before the keypress, by design.

Expected serial milestones:

```text
DIAG ROM: START
DIAG ROM: IPL DMA PASS
DIAG IPL: ENTER
DIAG IPL: OS DMA PASS
FM-11 DIAG OS: READY
```

If one line is absent, investigate the transfer immediately preceding it.
ROM reads the IPL using HD6844, IPL reads the OS using HD6844, each
checks the channel DEND bit and FDC error flags; the final payload only
prints READY and loops. No timer-based benchmark is claimed in this first
version.

## Stock-ROM initialization alignment

The diagnostic ROM now performs the initial controller setup observed in the
original 4 KiB FM-11 6809 boot ROM: Force Interrupt (`$D0`) before
RESTORE (`$08`), and the HD6844 shared registers
`FD57=$00`, `FD54=$03`, `FD55=$00`, `FD56=$08`.
The boot drive register selects unit zero without an undocumented
motor bit. Channel-specific DMA registers remain FD40/42/50/94
for 2D or FD44/46/51/95 for 2HD.

The stock ROM uses a broader DMA transfer count (initially `$0400`)
with a different sector loop; the diagnostic ROM deliberately
uses individual 128/256-byte transfers to make a failing sector
identifiable. Therefore success/failure of this diagnostic remains
a separate observation from the stock-ROM IPL loader.

## Disk layout

- 2D: C0/H0/S1-S2 = 512-byte IPL; C0/H0/S3 = 256-byte OS.
- 2HD: C0/H0/S1-S4 = four 128-byte FM IPL records; C0/H1/S1 =
  256-byte MFM OS.
- The generator constructs complete D88 media so the same images can
  exercise the emulator's strict track CHRN parser.
- ROM and IPL use DMA bank 0 and a single-sector DMA count. The boot
  payload resides at physical $2000 and does not enable the MMU.

## Limitations

This is the initial smoke-test stage, **not** a replacement for the genuine
Fujitsu boot ROM. It has its own 8251A init and simplified ROM loader.
The ROM/IPL contain bounded DMA polling, but do not yet record per-byte DRQ,
sector timing or FDC registers in hexadecimal. The tests check disk layout
and reset vectors; the code has not yet been assembled or booted in this
environment. Real-machine operation requires separate validation of ROM
programming, 2D motor handling, 2HD FM track selection and FDC status.

Keep the stock boot ROM as an independent regression test: passing this
diagnostic ROM does not prove that the stock ROM's multi-sector DMA
sequence works.
