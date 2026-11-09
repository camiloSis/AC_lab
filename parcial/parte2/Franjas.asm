; franjas.asm - 16 franjas horizontales de colores (texto 80x25)
; Ensamblar: nasm -f bin franjas.asm -o franjas.com
org 100h

    mov ax, 0003h       ; modo texto 80x25 (limpia la pantalla)
    int 10h

    mov dh, 0           ; DH = fila actual = numero de color (0..15)
siguiente:
    mov ah, 02h         ; funcion 02h: posicionar el cursor
    mov bh, 0           ; pagina de video 0
    mov dl, 0           ; columna 0 (la fila ya esta en DH)
    int 10h

    mov ah, 09h         ; funcion 09h: escribir caracter con atributo
    mov al, 0DBh        ; caracter de bloque lleno
    mov bl, dh          ; atributo = color de la franja
    mov cx, 16          ; 16 repeticiones = ancho de la franja
    int 10h

    inc dh              ; siguiente fila y siguiente color
    cmp dh, 16          ; ya se dibujaron las 16 franjas?
    jne siguiente

    mov ah, 00h         ; esperar una tecla para ver el resultado
    int 16h

    mov ax, 4C00h       ; terminar el programa
    int 21h