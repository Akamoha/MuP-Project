#make_bin#

#load_segment=FFFFH#
#load_offset=0000H#

#cs=0000H#
#ip=0000H#
#ds=0000H#
#es=0000H#
#ss=0000H#
#sp=FFFEH#
#ax=0000H#
#bx=0000H#
#cx=0000H#
#dx=0000H#
#si=0000H#
#di=0000H#
#bp=0000H#

 ; starting of the program

    jmp st:        
    db 1021 dup(0)
    st:  cli

    one_k db 0
    ten_k dw 0
    sine_w db 0
    triangular_w db 0
    square_w db 0
    one_hundred db 0
    ten db 0
    count dw 0
    list db 13 dup(0)
	
 ; Giving names for the internal addresses of 8255
 
	portA equ 00H
	portB equ 02H
	portC equ 04H
	cregPPI equ 06H
	
 ; Giving names for the internal addresses of 8253
 
	timer0 equ 08H
	timer1 equ 0AH
	timer2 equ 0CH
	cregPIT equ 0EH
	
 ; Giving names to the different button hexcodes on keypad
 
    SINbutton equ 66H
	TRIbutton equ 56H
	SQUbutton equ 36H
	TKbutton equ 65H
	OKbutton equ 55H
	HUNbutton equ 35H
	TENbutton equ 33H
	GENbutton equ 63H

 ; Initializing the segments to start of ram

    mov     ax, 0200H
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0FFFEH    
    mov     ax, 00H
    mov     ten_k, ax
    mov     one_k, al
    mov     ten_k, ax
    mov     one_hundred, al
    mov     ten, al
    mov     sine_w, al
    mov     triangular_w, al
    mov     square_w, al
    
 ; Table to generate sine wave (table for one fourth of the cycle)

    lea     di,  list
    mov     [di], 128
    mov     [di + 1], 144
    mov     [di + 2], 160    
    mov     [di + 3], 176    
    mov     [di + 4], 191
    mov     [di + 5], 205
    mov     [di + 6], 218
    mov     [di + 7], 228
    mov     [di + 8], 238
    mov     [di + 9], 245
    mov     [di + 10], 251
    mov     [di + 11], 254
    mov     [di + 12], 255

 ; Initializing 8255 (setting it to i/o mode)

    mov     al, 10001010b
    out     cregPPI, al    

 ; Keypad interfacing    

key1: 
	mov		al, 00H
    out     portC, al

 ; Checking for key release

key2: 
	in  	al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key2	

	mov 	 al, 00H
	out		 portC, al

 ; Checking for key press

key3: 
	in		al, portC
    and     al, 70H
    cmp     al, 70H
    je      key3
	
 ; Once key press is detected, then find which row is the pressed key in
 
    mov     al, 06H
    mov     bl, al
    out     portC, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key4
	
    mov     al, 05H
    mov     bl, al
    out     portC, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key4
	
    mov     al, 03H
    mov     bl, al
    out     portC, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    je      key3
	
 ; Code reaches here once a key has been pressed and its hex code is stored in the al and bl registers
 ; Now we check which button that hexcode corresponds to:
 
key4:or     al, bl
    cmp     al, SINbutton 
 ; If SIN button is pressed, then:
    jz      sine_k
	
    cmp     al, TRIbutton
 ; Else if TRI button is pressed, then:
    jz      tria_k
	
    cmp     al, SQUbutton
 ; Else if SQU button is pressed, then:
    jz      squ_k
	
    cmp     al, TKbutton
 ; Else, if 10K button is pressed, then:
    jz      tk_k
	
    cmp     al, OKbutton
 ; Else, if 1K button is pressed, then:
    jz      ok_k
	
    cmp     al, HUNbutton
 ; Else, if 100 button is pressed, then:
    jz      hun_k
	
    cmp     al, TENbutton
 ; Else, if 10 button is pressed, then:
    jz      te_k
	
    cmp     al, GENbutton
 ; Else, if GEN button was pressed:
    jz      end_k

 ; Incrementing corresponding counts
 
tk_k: jmp     key1      
ok_k: inc     one_k 
      jmp     key1  
hun_k:inc     one_hundred
      jmp     key1
te_k: inc     ten
      jmp     key1
squ_k:inc     square_w
      jmp     key1
tria_k:inc  triangular_w 
      jmp     key1
sine_k:inc     sine_w
      jmp     key1
end_k: 
    
 ; Code reaches this point if GEN button is pressed.
 ; In that case, compute the count required to load in 8253 (PIT)

	call computeCount
	
 ; BX register now stores the frequency in decaHertz

    mov     dx, 00H
    mov     ax, 10000
    div     bx ; dividing 10000 by bx. Quotient stored in ax

i:  mov count, ax

 ; Calculated count present in count
 ; Storing count

	mov     al, 00H
    out     portC, al
    
 ; Wait for GEN key release
 
    call waitForGEN

 ; BX now stores the value of (actual count * sampling rate)
 ; Here we have used the sampling rate of ((13*2)-1)*2 = 50
 
 ; Selecting the wave form:

    mov     al, sine_w
    cmp     al, triangular_w
    jl      slt
	cmp		al, square_w
	jg		sine_gen
	jmp 	sq_gen
slt:mov 	al, triangular_w
	cmp 	al, square_w
	jg 		tri_gen
	jmp 	sq_gen

 ; Code to generate sine wave
              
sine_gen: 
    mov     dx, 00H
    mov     ax, count
    mov     bx, 50
    div     bx
q1: 
	mov     bx, ax
 ; Initialize timer
    call initTimer

l5: in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key
    lea     si, list
    mov     cl, 13
l1:
    mov     al, [si]
    out     00H, al               
p1: in      al, portB
    cmp     al, 00H
    jne     p1
p2: in      al, portB
    cmp     al, 80H
    jne     p2 
J1: add     si, 01H
    loop    l1
    dec     si     
    mov     cl, 12
l2: sub     si, 01H
    mov     al, [si]
    out     00H, al              
p3: in      al, portB
    cmp     al, 00H
    jne     p3
p4: in      al, portB
    cmp     al, 80H
    jne     p4
J2: loop    l2
    lea     si, list
    mov     cl, 12
    inc     si
l3: mov     al, [si]
    not     al
    out     00H, al   
p5: in      al, portB
    cmp     al, 00H
    jne     p5
p6: in      al, portB
    cmp     al, 80H
    jne     p6
J3: add     si, 01H
    loop    l3
    mov     cl, 13
l4:
    sub     si, 01H
    mov     al, [si]
    not     al
    out     00H, al 
p7: in      al, portB
    cmp     al, 00H
    jne     p7
p8: in      al, portB
    cmp     al, 80H
    jne     p8
    loop    l4
    jmp     l5

 ; Code to generate triangular wave
 
tri_gen:
    mov 	dx, 00H
    mov     ax, count
    mov     bx, 30
    div     bx
qr1:
	mov     bx, ax
 ; Initialize timer
	call initTimer

    mov al, 00H
g1:
    out     00H, al
    mov     bl, al
e1: in al, portB
    cmp     al, 00H
    jne     e1
e2: in al, portB
    cmp     al, 80H
    jne     e2  
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key
    mov     al, bl
    add     al, 17
    cmp     al, 0FFH
    jnz     g1       
g2:
    out     00H, al
    mov     bl, al
e3: in      al, portB
    cmp     al, 00H
    jne     e3
e4: in      al, portB
    cmp     al, 80H
    jne     e4                 
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key
    mov     al, bl 
    sub     al, 17
    cmp     al, 00H
    jnz     g2
    jmp     g1
    
 ; Code to generate square wave:
 
sq_gen: 
	mov dx, 00H
    mov ax, count
	mov bx, 02H
	div bx
	mov bx, ax
	
 ; Initialize timer
	call initTimer
    mov     al, 80H
    out     00H, al
s:  mov     al, 00H
    out     00H, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key
    call    wait
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key 
    mov     al, 0FFH
    out     00H, al
    mov     al, 0FFH
    out     00H, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key 
    call    wait
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jne     key
    mov     al, 0FFH
    out     00H, al           
    jmp     s
	
 ; Checking for which waveform key is pressed

key:
	mov     al, 06H
    mov     bl, al
    out     portC, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jnz     k3
	
    mov     al, 05H
    mov     bl, al
    out     portC, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    jnz     k3
	
    mov     al, 03H
    mov     bl, al
    out     portC, al
    in      al, portC
    and     al, 70H
    cmp     al, 70H
    je      key
	
k3: or      al, bl
    cmp     al, SINbutton
 ; If SIN button is pressed, then:
    jz      sine_gen
    cmp     al, TRIbutton
 ; If TRI button is pressed, then:
    jz      tri_gen
    cmp     al, SQUbutton
 ; If SQU button is pressed, then:
    jz      sq_gen
    jmp     key
	

 ; Procedure to compute the value of count
 
computeCount proc
	mov     bx, 00H
    mov     al, 100
    mul     one_k
    add     bx, ax
    mov     al, 0AH
    mul     one_hundred
    add     bx, ax
    mov     al, ten
    mov     ah, 00H
    add     bx, ax
	ret
endp

 ; Wait procedure

wait proc
	v1: in      al, portB
		cmp     al, 00H
		jne     v1
	v2: in      al, portB
		cmp     al, 80H
		jne     v2
	ret
endp

 ; Procedure to initialize the 8253 (PIT)
 
initTimer proc
 ; Initializing the timer with control word
    mov     al, 00110110b
	out     cregPIT, al
 ; Loading LSB of count value
	mov     al, bl
	out     timer0, al
 ; Loading MSB of count value
	mov     al, bh
    out     timer0, al
	ret
endp

  ; Procedure to wait for GEN key release
 
waitForGEN proc
	k1: in      al, portC
		and     al, 70H
		cmp     al, 70H
		jnz     k1
	ret
endp