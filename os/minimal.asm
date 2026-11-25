********************************************************************
* Minimal 6809 diagnostic payload, exactly one 256-byte disk sector.
********************************************************************
                    org       $2000
UART_DATA           equ       $FD06
UART_STAT           equ       $FD07
start               ldx       #msg
next                lda       ,x+
                    beq       idle
                    pshs      x
wait_tx             ldb       >UART_STAT
                    bitb      #1
                    beq       wait_tx
                    sta       >UART_DATA
                    puls      x
                    bra       next
idle                bra       idle
msg                 fcc       "FM-11 DIAG OS: READY"
                    fcb       13,10,0
                    end       start
