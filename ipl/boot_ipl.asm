********************************************************************
* Diagnostic IPL ($0400), 512-byte slot.
* HD=0: 2D C0/H0/S3 (256 bytes) -> $2000.
* HD=1: 2HD C0/H1/S1 (256-byte MFM) -> $2000.
********************************************************************
                    org       $0400
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
DMA_ADDR            equ       $FD40
DMA_COUNT           equ       $FD42
DMA_MODE            equ       $FD50
DMA_BANK            equ       $FD94
                    else
FDC_CMD             equ       $FD30
FDC_TRACK           equ       $FD31
FDC_SECTOR          equ       $FD32
FDC_SIDE            equ       $FD34
DMA_ADDR            equ       $FD44
DMA_COUNT           equ       $FD46
DMA_MODE            equ       $FD51
DMA_BANK            equ       $FD95
                    endc
entry               ldx       #hello
                    lbsr      puts
                    clr       >DMA_MODE
                    clr       >DMA_BANK
                    clr       >FDC_TRACK
                    ifeq      HD
                    clr       >FDC_SIDE
                    lda       #3
                    else
                    lda       #1
                    sta       >FDC_SIDE
                    endc
                    sta       >FDC_SECTOR
                    ldd       #$2000
                    std       >DMA_ADDR
                    ldd       #256
                    std       >DMA_COUNT
                    lda       #4
                    sta       >DMA_MODE
                    lda       #$80
                    sta       >FDC_CMD
* Allow multiple disk revolutions independently of CPU speed.
                    ldy       #32
dma_retry           ldu       #$FFFF
wait_dma            lda       >DMA_MODE
                    bita      #$40
                    bne       failed
                    bita      #$80
                    bne       complete
                    lda       >FDC_CMD
                    bita      #$9C
                    bne       failed
                    leau      -1,u
                    bne       wait_dma
                    leay      -1,y
                    bne       dma_retry
                    bra       failed
complete            clr       >DMA_MODE
                    lda       >FDC_CMD
                    bita      #$9C
                    bne       failed
                    ldx       #loaded
                    lbsr      puts
                    jmp       $2000
failed              clr       >DMA_MODE
                    ldx       #error
                    lbsr      puts
stop                bra       stop
puts                lda       ,x+
                    beq       done
                    pshs      x
txwait              ldb       >UART_STAT
                    bitb      #1
                    beq       txwait
                    sta       >UART_DATA
                    puls      x
                    bra       puts
done                rts
hello               fcc       "DIAG IPL: ENTER"
                    fcb       13,10,0
loaded              fcc       "DIAG IPL: OS DMA PASS"
                    fcb       13,10,0
error               fcc       "DIAG IPL: DMA FAIL"
                    fcb       13,10,0
                    end       entry
