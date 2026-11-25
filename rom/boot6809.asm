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
                    ldu       #$FFFF
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
dma_bad             clr       >DMA_MODE
                    orcc      #1
                    rts
dma_ok              clr       >DMA_MODE
                    lda       >FDC_CMD
                    bita      #$9C
                    bne       dma_bad
                    leax      ROM_SECTOR_BYTES,x
                    andcc     #$FE
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
                    end       start
