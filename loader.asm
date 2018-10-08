; (c)2018 Miguel Angel Rodriguez Jodar (mcleod_idefix). ZX Projects.
; License for this specific file is the same as turboloader project.

TST_BUCLE                equ 54   ;numero de T-estados que tarda una vuelta de bucle
TOLERANCIA               equ 25

TST_TONOGUIA             equ 1500  ;numero de T-estados que tarda el pulso del tono guia
BUC_TONOGUIA             equ (TST_TONOGUIA / TST_BUCLE)
CTE_CMP_TONOGUIA         equ (BUC_TONOGUIA-BUC_TONOGUIA*TOLERANCIA/100)

TST_SYNC1                equ 400
TST_SYNC2                equ 800
BUC_SYNC1                equ (TST_SYNC1 / TST_BUCLE)
BUC_SYNC2                equ (TST_SYNC2 / TST_BUCLE)
CTE_CMP_SYNC             equ (BUC_SYNC1+BUC_SYNC2)/2-((BUC_SYNC1+BUC_SYNC2)/2)*TOLERANCIA/100

TST_BITZERO              equ 500
TST_BITUNO               equ 1000
BUC_BITZERO              equ (TST_BITZERO / TST_BUCLE)
BUC_BITUNO               equ (TST_BITUNO / TST_BUCLE)
CTE_CMP_BIT              equ (BUC_BITZERO+BUC_BITUNO)



px_addr         equ 22b0h  ;linea en A, res en HL

                org 0c000h
Main            ld a,2
                out (255),a
                ld hl,16384
                ld de,16385
                ld bc,6143
                ld (hl),l
                ldir
                ld hl,24576
                ld de,24577
                ld bc,6143
                ld (hl),l
                ldir

                ld ix,IXTable
                ld b,0
AnotherScan
                ld c,0
                ld a,b
                call px_addr   ;HL = direccion de pantalla para scan B
                ld (ix+0),l
                ld (ix+1),h
                inc ix
                inc ix
                inc b
                ld a,b
                cp 192
                jr nz,AnotherScan

                ;carga una pantalla hicolour, espera 3 segundos, y vuelta a empezar
LoadScreen      ld hl,IXTable+2
                ld (IXTableIndex),hl
                ld ix,4000h
                ld de,12288
                call LoadBytes
                xor a
                out (254),a

                ld b,50*3  ;3 secs. pause
DoPause         halt
                djnz DoPause

                jp LoadScreen



LoadBytes                ;Entrada: IX=direccion inicio, DE=longitud carga
                         ;B = constantes de tiempo.
                         ;C = polaridad señal y color borde
                         ;L = byte recibido. Cuenta pulsos tono guia
                         ;A y H = registros generales para calculos
                         di

                         ; PASO 1 : encontrar el tono guia y contar al menos 256 ciclos completos

ResetMascara             ld c,00000010b  ;Polaridad normal, borde rojo/cyan, MIC off (esperamos nivel bajo)
BuscaEngancheTonoguia    ld l,0

EsperaPulsoTonoGuia      call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_TONOGUIA
                         jr c,BuscaEngancheTonoguia ;pulso demasiado corto

                         ;Llegados aqui, tenemos un candidato para pulso bajo del tono guia.
                         ;Vamos a ver si le sigue un pulso alto de la duracion adecuada
                         call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_TONOGUIA
                         jr c,BuscaEngancheTonoguia  ;pulso demasiado corto

                         ;Tenemos lo que parece que es un ciclo completo de
                         ;tono guia. Incrementamos el contador en L.
                         ;Si se han recibido al menos 240 ciclos completos,
                         ;esperar a recibir el pulso de sincronismo. Si no,
                         ;seguir recibiendo ciclos de tono guia
                         inc l
                         jp nz,EsperaPulsoTonoGuia

                         ;PASO 2: sigo recibiendo ciclos de tonos guia pero espero pulso de sincronismo

EsperaPulsoSync          call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_SYNC
                         jr nc,EsperaPulsoSync       ;pulso demasiado largo? seguimos buscando

                         call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_SYNC
                         jr c,EsperaPulsoSync       ;pulso demasiado corto? seguimos buscando

                         ; PASO 3: sincronismo encontrado. Comienzo a cargar bytes

                         ld a,c
                         xor 00000100b              ;cambio a combinacion azul/amarillo
                         ld c,a

BucleLoadBytes           ld l,1                     ;L guarda el byte formandose (de bit más a menos significativo)
BucleLoadBits            call Mide1Ciclo
                         jr z,ResetMascara          ;no se detectó cambio
                         jr nc,SalidaLoad           ;se pulso BREAK
                         ld a,CTE_CMP_BIT
                         cp b                       ;Comparamos con tiempo medio de bit. El valor de CF nos indica si es 0 o 1
                         rl l                       ;Nuevo bit se introduce por la derecha
                         jp nc,BucleLoadBits

                         ld (ix),l

                         ;--------------------------------------
                         ld a,ixh                              ;
                         xor h     ; H = 00100000b             ;
                         ld ixh,a                              ;
                         and h                                 ;
                         jp nz,NoIncrIX                        ;
                         ;--------------------------------------

                         inc ix
NoIncrIX                 dec de

                         ;--------------------------------------
                         ld a,e                                ;
                         and 03fh                              ;
                         jp nz,NoUpdateIX                      ;
                         ld hl,(IXTableIndex)                  ;
                         ld a,(hl)                             ;
                         inc hl                                ;
                         ld b,(hl)                             ;
                         inc hl                                ;
                         ld (IXTableIndex),hl                  ;
                         ld ixh,b                              ;
                         ld ixl,a                              ;
                         ;--------------------------------------

NoUpdateIX               ld a,d
                         or e
                         jp nz,BucleLoadBytes

SalidaLoad               ld a,(23624)
                         and 7
                         out (254),a
                         ei
                         ret

Mide1Pulso               ;CF=0 para indicar que se pulso BREAK
                         ;ZF=1 para indicar overrun de la constante de tiempo
                         ;B = tiempo del pulso medido (en ciclos de este bucle)
                         ;Cada ciclo del bucle consume 54 ciclos de reloj
                         ld b,0         ;Contador inicialmente a 0
                         ld h,00100000b ;Mascara para aislar EAR (una vez desplazado A a la derecha)
BucleMidePulso           ld a,7Fh
                         in a,(254)
                         rra
                         ret nc         ;si se pulso BREAK, salir
                         inc b          ;actualizamos contador de tiempos
                         ret z
                         xor c          ;aplicamos polaridad actual
                         and h          ;aislamos pulso EAR
                         jp z,BucleMidePulso
                         ld a,c         ;recuperamos color borde de C
                         xor 00101111b  ;cambiamos polaridad actual, valor de MIC, y color del borde
                         out (254),a
                         ld c,a
                         scf
                         ret

Mide1Ciclo               ;CF=0 para indicar que se pulso BREAK
                         ;ZF=1 para indicar overrun de la constante de tiempo
                         ;B = tiempo del pulso medido (en ciclos de este bucle)
                         ;Cada ciclo del bucle consume 54 ciclos de reloj
                         ld b,0         ;Contador inicialmente a 0
                         ld h,00100000b ;Mascara para aislar EAR (una vez desplazado A a la derecha)
BucleMidePulso1          ld a,7Fh
                         in a,(254)
                         rra
                         ret nc         ;si se pulso BREAK, salir
                         inc b          ;actualizamos contador de tiempos
                         ret z
                         xor c          ;aplicamos polaridad actual
                         and h          ;aislamos pulso EAR
                         jp z,BucleMidePulso1
                         ld a,c         ;recuperamos color borde de C
                         xor 00101111b  ;cambiamos polaridad actual, valor de MIC, y color del borde
                         out (254),a
                         ld c,a
BucleMidePulso2          ld a,7Fh
                         in a,(254)
                         rra
                         ret nc         ;si se pulso BREAK, salir
                         inc b          ;actualizamos contador de tiempos
                         ret z
                         xor c          ;aplicamos polaridad actual
                         and h          ;aislamos pulso EAR
                         jp z,BucleMidePulso2
                         ld a,c         ;recuperamos color borde de C
                         xor 00101111b  ;cambiamos polaridad actual, valor de MIC, y color del borde
                         out (254),a
                         ld c,a
                         scf
                         ret


IXTableIndex             dw IXTable

IXTable                  equ $

                         end Main
