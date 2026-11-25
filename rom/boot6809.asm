********************************************************************
* FM-11 diagnostic ROM, 4 KiB, mapped at $5000-$5FFF.
* HD=0: 2D, 2x256-byte boot sectors via HD6844 channel 0.
* HD=1: 2HD, 4x128-byte FM boot sectors via channel 1.
* Serial messages mark entry, successful DMA and IPL dispatch.
********************************************************************
                    org       $5000
                    ifndef    HD
HD                  equ       0
                    endc
UART_DATA           equ       $FD06
UART_STAT           equ       $FD07
                    ifeq      HD
FDC_CMD             equ       $FD18
FDC_TRACK           equ       $FD19
FDC_SECTOR          equ       $FD1A
FDC_SIDE            equ       $FD1C
FDC_DRIVE           equ       $FD1D
DMA_ADDR            equ       $FD40
DMA_COUNT           equ       $FD42
DMA_MODE            equ       $FD50
DMA_BANK            equ       $FD94
ROM_SECTORS         equ       2
ROM_SECTOR_BYTES    equ       256
                    else
FDC_CMD             equ       $FD30
FDC_TRACK           equ       $FD31
FDC_SECTOR          equ       $FD32
FDC_SIDE            equ       $FD34
FDC_DRIVE           equ       $FD35
DMA_ADDR            equ       $FD44
DMA_COUNT           equ       $FD46
DMA_MODE            equ       $FD51
DMA_BANK            equ       $FD95
ROM_SECTORS         equ       4
ROM_SECTOR_BYTES    equ       128
                    endc
                    org       $5000
start               orcc      #$50
                    lds       #$3F00
* Initialize USART0 8251A: reset, mode 8N1 x16, Tx/Rx enabled.
                    clr       >UART_STAT
                    clr       >UART_STAT
                    clr       >UART_STAT
                    lda       #$40
                    sta       >UART_STAT
                    lda       #$4E
                    sta       >UART_STAT
                    lda       #$37
                    sta       >UART_STAT
* Wait for the terminal to connect and send one character before
* emitting anything. RXRDY is bit 1 of the 8251A status register.
* Read FD06 to consume the key (it is not forwarded to the IPL).
wait_key            lda       >UART_STAT
                    bita      #$02
                    beq       wait_key
                    lda       >UART_DATA
                    ldx       #msg_rom
                    lbsr      puts
                    clr       >DMA_MODE
                    clr       >DMA_BANK
                    ifeq      HD
                    lda       #$80             * mini-FDC motor on, unit 0
                    sta       >FDC_DRIVE
                    else
                    clr       >FDC_DRIVE
                    endc
* Restore the physical head before requesting the first boot sector.
                    lda       #$0B
                    sta       >FDC_CMD
                    ldu       #$FFFF
restore_wait        lda       >FDC_CMD
                    bita      #1
                    beq       restore_done
                    leau      -1,u
                    bne       restore_wait
                    bra       failed
restore_done        bita      #$90
                    bne       failed
                    clr       >FDC_TRACK
                    clr       >FDC_SIDE
                    lda       #1
                    sta       >FDC_SECTOR
                    ldx       #$0400
                    ldy       #ROM_SECTORS
read_loop           lbsr      read_dma
                    bcs       failed
                    inc       >FDC_SECTOR
                    leay      -1,y
                    bne       read_loop
                    ldx       #msg_ok
                    lbsr      puts
                    jmp       $0400
failed              ldx       #msg_fail
                    lbsr      puts
                    ldx       #msg_sector
                    lbsr      puts
                    lda       >FDC_SECTOR
                    lbsr      hex_byte
                    ldx       #msg_fdc
                    lbsr      puts
                    lda       >FDC_CMD
                    lbsr      hex_byte
                    ldx       #msg_dma
                    lbsr      puts
                    lda       >DMA_MODE
                    lbsr      hex_byte
                    ldx       #msg_count
                    lbsr      puts
                    ldd       >DMA_COUNT
                    lbsr      hex_word
                    ldx       #msg_newline
                    lbsr      puts
failed_loop         bra       failed_loop

* Program a single physical sector; no PIO byte transfers.
read_dma            clr       >DMA_MODE
                    stx       >DMA_ADDR
                    ldd       #ROM_SECTOR_BYTES
                    std       >DMA_COUNT
                    lda       #$04
                    sta       >DMA_MODE
                    lda       #$80
                    sta       >FDC_CMD
* Keep the timeout longer than several disk revolutions even
* when the emulated 6809 runs much faster than its nominal clock.
* Y is the sector loop counter, so save it while polling.
                    pshs      y
                    ldy       #32
dma_retry           ldu       #$FFFF
dma_poll            lda       >DMA_MODE
                    bita      #$40
                    bne       dma_bad
                    bita      #$80
                    bne       dma_ok
                    lda       >FDC_CMD
                    bita      #$9C
                    bne       dma_bad
                    leau      -1,u
                    bne       dma_poll
                    leay      -1,y
                    bne       dma_retry
dma_bad             puls      y
                    orcc      #1
                    rts
dma_ok              puls      y
                    clr       >DMA_MODE
                    lda       >FDC_CMD
                    bita      #$9C
                    bne       dma_bad
                    leax      ROM_SECTOR_BYTES,x
                    andcc     #$FE
                    rts

* Raw register hex output makes the first failing sector observable.
* These helpers use the same USART0 TXRDY polling as puts.
hex_word            pshs      b
                    lbsr      hex_byte
                    puls      a
                    bra       hex_byte
hex_byte            pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    lbsr      hex_nibble
                    puls      a
                    anda      #$0F
hex_nibble          anda      #$0F
                    adda      #'0
                    cmpa      #'9
                    bls       hex_emit
                    adda      #7
hex_emit            pshs      a
hex_wait            lda       >UART_STAT
                    bita      #1
                    beq       hex_wait
                    puls      a
                    sta       >UART_DATA
                    rts

puts                lda       ,x+
                    beq       puts_done
                    pshs      x
uart_wait           ldb       >UART_STAT
                    bitb      #1
                    beq       uart_wait
                    sta       >UART_DATA
                    puls      x
                    bra       puts
puts_done           rts
msg_rom             fcc       "DIAG ROM: START"
                    fcb       13,10,0
msg_ok              fcc       "DIAG ROM: IPL DMA PASS"
                    fcb       13,10,0
msg_fail            fcc       "DIAG ROM: DMA FAIL"
                    fcb       13,10,0
msg_sector          fcc       "  SECTOR="
                    fcb       0
msg_fdc             fcc       " FDC="
                    fcb       0
msg_dma             fcc       " DMA="
                    fcb       0
msg_count           fcc       " REM="
                    fcb       0
msg_newline         fcb       13,10,0
                    end       start
