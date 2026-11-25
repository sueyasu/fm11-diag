# FM-11 Boot Diagnostics

6809 standalone diagnostic boot ROM, 2D/2HD IPL and minimal boot payload to isolate FDC/DMA timing regressions. Uses lwasm, Python 3, and a serial terminal on USART0 (FD06/FD07).

See Makefile for build commands. No NitrOS-9 kernel or filesystem is required.
