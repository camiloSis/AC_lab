org 100h
jmp inicio

; PROCEDIMIENTOS
; ------------------------------------------------------------
; INIT_GAME: Inicializa video, board, serpiente, puntaje y comida
; Entrada: ninguna
; Salida: ninguna
; Registros modificados: todos (se preservan con PUSH/POP)
; ------------------------------------------------------------
INIT_GAME PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; Modo texto 80x25 (PRACTICA 3: MOV inmediato)
    mov ax, 0003h
    int 10h
    ; Ocultar cursor
    mov ah, 01h
    mov cx, 2000h
    int 10h
    ; Limpiar board (400 bytes a 0)
    mov di, offset board
    mov cx, BOARD_SIZE
    sub al, al                  ; PRACTICA 5: SUB, AL=0
clear_b:
    mov [di], al
    inc di
    loop clear_b
    ; Inicializar cola: 3 segmentos en fila 5, cols 19,20,21
    ; Indices: 5*40+19=219, 220, 221
    mov word ptr [queue], 219
    mov word ptr [queue+2], 220
    mov word ptr [queue+4], 221
    mov head, 3                 ; proximo indice libre
    mov tail, 0
    mov byte ptr dir, 1         ; derecha
    mov byte ptr headRow, 5
    mov byte ptr headCol, 21
    mov score, 0
    ; Marcar en board (PRACTICA 3: MOV directo con [BX/indice])
    mov byte ptr board[219], 1
    mov byte ptr board[220], 1
    mov byte ptr board[221], 1
    ; Semilla desde reloj BIOS
    mov ah, 00h
    int 1Ah
    mov seed, dx
    xor seed, cx                ; PRACTICA 2: XOR para mezclar
    ; Dibujar borde
    call DRAW_BORDER
    ; Dibujar serpiente inicial
    mov bx, 219
    mov al, 'O'
    mov ah, 0Ah
    call DRAW_CELL
    mov bx, 220
    call DRAW_CELL
    mov bx, 221
    call DRAW_CELL
    ; Imprimir el mensaje del puntaje
    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 19
    int 10h
    mov dx, offset msgScore
    mov ah, 09h
    int 21h
    ; Imprimir puntaje inicial
    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 28
    int 10h
    mov ax, 0
    call PRINT_NUM
    ; Generar primera comida
    call SPAWN_FOOD
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
INIT_GAME ENDP

; ------------------------------------------------------------
; DRAW_BORDER: Dibuja el borde gris del tablero
; Entrada: ninguna
; Salida: ninguna
; Registros modificados: AX, BX, CX, DX (se preservan)
; ------------------------------------------------------------
DRAW_BORDER PROC
    push ax
    push bx
    push cx
    push dx
    ; Borde superior: fila 1, col 19, 42 '-'
    mov ah, 02h
    mov bh, 0
    mov dh, 1
    mov dl, 19
    int 10h
    mov ah, 09h
    mov al, '-'
    mov bh, 0
    mov bl, 07h
    mov cx, 42
    int 10h
    ; Borde inferior: fila 12, col 19, 42 '-'
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 19
    int 10h
    mov ah, 09h
    mov al, '-'
    mov bh, 0
    mov bl, 07h
    mov cx, 42
    int 10h
    ; Bordes laterales: filas 2..11, cols 19 y 60
    mov cx, 10
    mov dh, 2
db_side:
    ; Izquierdo
    mov ah, 02h
    mov bh, 0
    mov dl, 19
    push cx
    int 10h
    mov ah, 09h
    mov al, '|'
    mov bh, 0
    mov bl, 07h
    mov cx, 1
    int 10h
    ; Derecho
    mov ah, 02h
    mov bh, 0
    mov dl, 60
    int 10h
    mov ah, 09h
    mov al, '|'
    mov bh, 0
    mov bl, 07h
    mov cx, 1
    int 10h
    pop cx
    inc dh
    loop db_side
    ; Esquinas: 4 '+'
    ; Sup izq (1,19)
    mov ah, 02h
    mov bh, 0
    mov dh, 1
    mov dl, 19
    int 10h
    mov ah, 09h
    mov al, '+'
    mov bh, 0
    mov bl, 07h
    mov cx, 1
    int 10h
    ; Sup der (1,60)
    mov ah, 02h
    mov bh, 0
    mov dh, 1
    mov dl, 60
    int 10h
    mov ah, 09h
    mov al, '+'
    mov bh, 0
    mov bl, 07h
    mov cx, 1
    int 10h
    ; Inf izq (12,19)
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 19
    int 10h
    mov ah, 09h
    mov al, '+'
    mov bh, 0
    mov bl, 07h
    mov cx, 1
    int 10h
    ; Inf der (12,60)
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 60
    int 10h
    mov ah, 09h
    mov al, '+'
    mov bh, 0
    mov bl, 07h
    mov cx, 1
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DRAW_BORDER ENDP

; ------------------------------------------------------------
; READ_KEY: Lee teclado (no bloqueante). Actualiza dir o indica ESC
; Entrada: ninguna
; Salida: AL = 1 si ESC, 0 si no
; Registros modificados: AX (salida), BX (se preserva)
; ------------------------------------------------------------
READ_KEY PROC
    push bx
    ; Hay tecla? INT 16h AH=01h: ZF=1 -> no hay
    mov ah, 01h
    int 16h
    jz rk_nokey
    ; Consumir tecla
    mov ah, 00h
    int 16h
    ; AL = ASCII, AH = scancode
    cmp al, 27                  ; ESC?
    jne rk_arrow
    mov al, 1
    jmp rk_done
rk_arrow:
    cmp al, 0                   ; tecla extendida?
    jne rk_wasd
    ; Flechas: AH = scancode
    cmp ah, 48h
    jne rk_ad
    mov bl, 0                   ; arriba
    jmp rk_set
rk_ad:
    cmp ah, 50h
    jne rk_al
    mov bl, 2                   ; abajo
    jmp rk_set
rk_al:
    cmp ah, 4Bh
    jne rk_ar
    mov bl, 3                   ; izquierda
    jmp rk_set
rk_ar:
    cmp ah, 4Dh
    jne rk_nokey
    mov bl, 1                   ; derecha
    jmp rk_set
rk_wasd:
    ; WASD (mayusculas y minusculas)
    cmp al, 'w'
    je rk_w
    cmp al, 'W'
    je rk_w
    cmp al, 's'
    je rk_s
    cmp al, 'S'
    je rk_s
    cmp al, 'a'
    je rk_a
    cmp al, 'A'
    je rk_a
    cmp al, 'd'
    je rk_d
    cmp al, 'D'
    je rk_d
    jmp rk_nokey
rk_w:
    mov bl, 0
    jmp rk_set
rk_s:
    mov bl, 2
    jmp rk_set
rk_a:
    mov bl, 3
    jmp rk_set
rk_d:
    mov bl, 1
rk_set:
    ; Rechazar giro de 180 grados: nueva == (dir+2) AND 3
    mov al, dir
    add al, 2
    and al, 3                   ; PRACTICA 2: AND 3 acota a 0..3
    cmp bl, al
    je rk_nokey                 ; rechazar
    mov dir, bl
rk_nokey:
    xor al, al
rk_done:
    pop bx
    ret
READ_KEY ENDP

; ------------------------------------------------------------
; CHECK_COLLISION: Verifica pared o cuerpo en (DH,DL)
; Entrada: DH = fila, DL = columna
; Salida: AL = 0 libre, 1 pared, 2 cuerpo; BX = indice si no es pared
; Registros modificados: AX, BX (salidas)
; ------------------------------------------------------------
CHECK_COLLISION PROC
    ; Paredes (comparacion sin signo: 0-1 da 255/65535)
    cmp dh, BOARD_H
    jae cc_wall                 ; Salta si DH >= BOARD_H, comparacion sin signo
    cmp dl, BOARD_W
    jae cc_wall
    ; Indice = fila*40 + col
    mov al, dh
    xor ah, ah
    mov bl, 40
    mul bl                      ; PRACTICA 5: MUL 8 bits -> AX
    mov bl, dl
    xor bh, bh
    add ax, bx                  ; PRACTICA 5: ADD
    mov bx, ax                  ; BX = indice
    cmp byte ptr board[bx], 1
    je cc_body
    xor al, al
    ret
cc_wall:
    mov al, 1
    ret
cc_body:
    mov al, 2
    ret
CHECK_COLLISION ENDP

; ------------------------------------------------------------
; MOVE_SNAKE: Mueve la serpiente un paso
; Entrada: ninguna (usa dir, headRow, headCol)
; Salida: AL = 0 OK, 1 game over
; Registros modificados: AX (salida), BX, DX, SI, DI (se preservan)
; ------------------------------------------------------------
MOVE_SNAKE PROC
    push bx
    push dx
    push si
    push di
    ; Nueva posicion segun dir
    mov dh, headRow
    mov dl, headCol
    mov al, dir
    cmp al, 0
    jne ms_nu
    dec dh                      ; arriba
    jmp ms_chk
ms_nu:
    cmp al, 1
    jne ms_nr
    inc dl                      ; derecha
    jmp ms_chk
ms_nr:
    cmp al, 2
    jne ms_nl
    inc dh                      ; abajo
    jmp ms_chk
ms_nl:
    dec dl                      ; izquierda
ms_chk:
    call CHECK_COLLISION
    cmp al, 0
    je ms_ok
    mov al, 1                   ; colision -> game over
    jmp ms_done
ms_ok:
    ; BX = indice nueva cabeza
    cmp byte ptr board[bx], 2
    je ms_eat
    ; --- Movimiento normal: borrar cola ---
    mov si, tail
    shl si, 1                   ; PRACTICA 2: SHL para indice de palabra
    mov di, queue[si]           ; DI = indice de la cola
    mov byte ptr board[di], 0
    ; Dibujar espacio (PRACTICA 3: XCHG natural)
    xchg bx, di                 ; BX=cola, DI=nueva cabeza
    mov al, ' '
    mov ah, 07h
    call DRAW_CELL
    xchg bx, di                 ; BX=nueva cabeza, DI=cola
    ; Avanzar tail
    inc tail
    cmp tail, BOARD_SIZE
    jb ms_t_ok
    mov tail, 0
ms_t_ok:
    jmp ms_enq
ms_eat:
    ; --- Comer: crecer ---
    inc score
    push bx                     ; guardar indice de la nueva cabeza
    push dx                     ; guardar fila/columna de la nueva cabeza
    ; Mostrar puntaje
    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 28
    int 10h
    mov ax, score
    call PRINT_NUM
    pop dx
    pop bx
    ; Nueva comida
    call SPAWN_FOOD
ms_enq:
    ; Encolar nueva cabeza
    mov si, head
    shl si, 1
    mov queue[si], bx
    mov byte ptr board[bx], 1
    ; Avanzar head
    inc head
    cmp head, BOARD_SIZE
    jb ms_h_ok
    mov head, 0
ms_h_ok:
    ; Actualizar posicion de la cabeza
    mov headRow, dh
    mov headCol, dl
    ; Dibujar nueva cabeza
    mov al, 'O'
    mov ah, 0Ah
    call DRAW_CELL
    xor al, al
ms_done:
    pop di
    pop si
    pop dx
    pop bx
    ret
MOVE_SNAKE ENDP

; ------------------------------------------------------------
; SPAWN_FOOD: Genera comida en celda libre aleatoria
; Entrada: ninguna (usa seed)
; Salida: coloca comida en board y la dibuja
; Registros modificados: AX, BX, CX, DX, SI (se preservan)
; ------------------------------------------------------------
SPAWN_FOOD PROC
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, 1000                ; maximo de intentos
sf_try:
    ; seed = seed * 25173 + 13849
    mov ax, seed
    mov bx, 25173
    mul bx                      ; PRACTICA 5: MUL 16 bits -> DX:AX
    add ax, 13849               ; PRACTICA 2: ADD/ADC = sumador total
    adc dx, 0                   ; conservar el acarreo alto; seed usa solo AX
    mov seed, ax
    ; pos = seed % 400
    xor dx, dx
    mov bx, 400
    div bx                      ; PRACTICA 5: DIV 16 bits -> DX=resto
    mov si, dx
    cmp byte ptr board[si], 0
    jne sf_next
    ; Colocar y dibujar
    mov byte ptr board[si], 2
    mov bx, si
    mov al, '*'
    mov ah, 0Ch
    call DRAW_CELL
    jmp sf_done
sf_next:
    loop sf_try
sf_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SPAWN_FOOD ENDP

; ------------------------------------------------------------
; DRAW_CELL: Dibuja un caracter en la celda BX del tablero
; Entrada: BX = indice (0..399), AL = caracter, AH = color
; Salida: ninguna
; Registros modificados: AX, BX, CX, DX (se preservan)
; ------------------------------------------------------------
DRAW_CELL PROC
    push ax
    push bx
    push cx
    push dx
    push ax                     ; guardar caracter/color
    ; fila = indice / 40, col = indice % 40 (DIV 8 bits)
    mov ax, bx
    mov cl, 40
    div cl                      ; PRACTICA 5: DIV 8 bits -> AL=fila, AH=col
    add al, 2                   ; fila pantalla = fila + 2
    mov dh, al
    add ah, 20                  ; col pantalla = col + 20
    mov dl, ah
    ; Posicionar cursor
    mov ah, 02h
    mov bh, 0
    int 10h
    ; Escribir caracter (AH=09h, BH=0, CX=1)
    pop ax                      ; AL=car, AH=color
    mov bl, ah
    mov bh, 0
    mov cx, 1
    mov ah, 09h
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DRAW_CELL ENDP

; ------------------------------------------------------------
; PRINT_NUM: Imprime AX en decimal en la posicion actual del cursor
; Entrada: AX = numero (0..65535), cursor ya posicionado
; Salida: imprime digitos + 3 espacios
; Registros modificados: AX, BX, CX, DX (se preservan)
; ------------------------------------------------------------
PRINT_NUM PROC
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    xor cx, cx                  ; contador de digitos
    cmp ax, 0
    jne pn_loop
    xor dx, dx
    push dx                     ; caso especial: numero 0
    inc cx
    jmp pn_print
pn_loop:
    xor dx, dx
    div bx                      ; PRACTICA 5: DIV 16 bits -> DX=resto
    push dx                     ; apilar digito (PRACTICA 5: PUSH)
    inc cx
    cmp ax, 0
    jne pn_loop
pn_print:
    pop dx                      ; PRACTICA 5: POP
    add dl, '0'
    mov ah, 02h
    int 21h                     ; imprimir digito
    loop pn_print
    ; Limpiar con 3 espacios
    mov cx, 3
pn_sp:
    mov dl, ' '
    mov ah, 02h
    int 21h
    loop pn_sp
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PRINT_NUM ENDP

DELAY PROC
    push ax
    push cx
    push dx
    mov ah, 86h
    mov cx, 0001h        ; CX:DX = microsegundos
    mov dx, 86A0h        ; 0001_86A0h = 100000 us = 100 ms
    int 15h
    pop dx
    pop cx
    pop ax
    ret
DELAY ENDP
; ------------------------------------------------------------
; GAME_OVER: Muestra el mensaje GAME OVER y el puntaje, espera tecla
; Entrada: ninguna
; Salida: ninguna (el main loop termina)
; Registros modificados: AX, BX, CX, DX (se preservan)
; ------------------------------------------------------------
GAME_OVER PROC
    push ax
    push bx
    push cx
    push dx
    ; Posicionar en (14, 19)
    mov ah, 02h
    mov bh, 0
    mov dh, 14
    mov dl, 19
    int 10h
    ; Imprimir el mensaje GAME OVER y el puntaje
    mov dx, offset msgGameOver
    mov ah, 09h
    int 21h
    ; Imprimir puntaje (cursor ya avanzado)
    mov ax, score
    call PRINT_NUM
    ; Esperar tecla
    mov ah, 00h
    int 16h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
GAME_OVER ENDP

; PROGRAMA PRINCIPAL 

inicio:
    call INIT_GAME
main_loop:
    call READ_KEY                    
    cmp al, 1
    je exit_game
    call MOVE_SNAKE
    cmp al, 1
    je game_over_h
    call DELAY
    jmp main_loop
game_over_h:
    call GAME_OVER
exit_game:
    ; Restaurar modo de video y cursor
    mov ax, 0003h
    int 10h
    mov ah, 01h
    mov cx, 0607h
    int 10h
    ; Salir
    mov ax, 4C00h
    int 21h

; ============================================================
; DATOS
; ============================================================
BOARD_W     EQU 40
BOARD_H     EQU 10
BOARD_SIZE  EQU 400

board       DB 400 dup(0)       ; 0=libre, 1=serpiente, 2=comida
queue       DW 400 dup(0)       ; indices de las celdas de la serpiente
head        DW 0                ; proximo indice libre en queue
tail        DW 0                ; indice de la cola en queue
dir         DB 1                ; 0=arriba, 1=derecha, 2=abajo, 3=izquierda
headRow     DB 5
headCol     DB 21
score       DW 0
seed        DW 0

msgScore    DB 'Puntaje: $'
msgGameOver DB 'GAME OVER! Puntaje: $'