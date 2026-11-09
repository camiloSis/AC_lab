; bits.asm - manipulacion de bits del registro CX
; Ensamblar: nasm -f bin bits.asm -o bits.com
org 100h

    mov cx, 00B1h       ; dato de ejemplo: D7..D0 = 1011 0001
    xor cx, 002Ah       ; invierte D5, D3 y D1      (0010 1010)
    and cx, 0FFABh      ; borra D6, D4 y D2         (1010 1011)
    or  cx, 0081h       ; pone en 1 D7 y D0         (1000 0001)

    ; --- mostrar el byte bajo de CX en binario (opcional) ---
    mov bx, 8           ; 8 bits por imprimir
imprimir:
    rol cl, 1           ; el bit D7 pasa al acarreo (CF)
    mov dl, '0'
    adc dl, 0           ; DL = '0' + CF  ->  '0' o '1'
    mov ah, 02h         ; imprimir el caracter que esta en DL
    int 21h
    dec bx
    jnz imprimir

    mov ax, 4C00h       ; terminar el programa
    int 21h