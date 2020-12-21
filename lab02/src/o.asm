.386p

msg_output	macro	msg,msg_size,row,col
	local	show

	push	EBP
	push	EAX
	push	ECX
	push	ESI
	push 	ES
	
	xor		EAX, EAX
	mov 	AX, sel_screen
	mov 	ES, AX
	mov		EBP, row * 160 + col * 2
	mov		ECX, msg_size
	xor		ESI, ESI
show:
	mov		AL, byte ptr msg[ESI]
	mov		ES:[EBP], AL
	add		EBP, 2
	inc		ESI
	loop	show

	pop 	ES
	pop		ESI
	pop		ECX
	pop		EAX
	pop		EBP
endm

num_output	macro	var,row,col
	local	cycle,number,print

	push	EAX
	push	EBX
	push	ECX
	push	EDX
	push	EBP
	push 	ES
	
	xor 	EBX, EBX
	mov 	BX, sel_screen
	mov 	ES, BX
	mov		AX, var
	mov		EBP, row * 160 + col * 2
	mov		ECX, 4
cycle:
	mov		DL, AL
	and		DL, 0Fh
	cmp		DL, 10
	jl		number
	add		DL, 'a' - 10
	jmp		print
number:
	add		DL, '0'
print:
	mov		ES:[EBP], DL
	ror		EAX, 4
	sub		EBP, 2
	loop	cycle

	pop 	ES
	pop		EBP
	pop		EDX
	pop		ECX
	pop 	EBX
	pop		EAX
endm



segdesc	struc
	limit	dw 0
	base_l	dw 0
	base_m	db 0
	attr_1	db 0
	arrt_2	db 0
	base_h	db 0
segdesc	ends

intdesc	struc
	offs_l	dw 0
	sel	dw 0
	rsrv	db 0
	attr	db 0
	offs_h	dw 0
intdesc	ends



data16	segment	'data' use16

;Глобальная таблица дескрипторов сегментов
	gdt	label	byte
		gdt_null   			segdesc<>
		gdt_4gb    			segdesc<0ffffh,,,92h,0cfh>		;92 СЕГМЕНТ ДАННЫХ С РАЗРЕШЕНИЕМ ЗАПИСИ И ЧТЕНИЯ
		gdt_code16		 	segdesc<code16_size-1,,,98h>	;98  СЕГМЕНТ ИСПОЛНЯЕМЫЙ. ЗАПРЕТ НА ОБРАЩЕНИЕ К НЕМУ
		gdt_code32 			segdesc<code32_size-1,,,98h,0cfh>
		gdt_data16   		segdesc<data16_size-1,,,92h,>
		gdt_stack32			segdesc<stack32_size-1,,,92h,0cfh>
		gdt_screen 			segdesc<4095, 8000h, 0Bh, 92h>
	gdt_size = $-gdt

;Псевдодескриптор GDTR
	gdtr	dw gdt_size-1	;Limit GDT
			dd ?			;Линейный 32-битный адрес GDT

;Селекторы сегментны дескрипторов
	sel_4gb    				equ 8
	sel_code16 				equ 16
	sel_code32 				equ 24
	sel_data16  			equ 32
	sel_stack32				equ 40
	sel_screen 				equ 48

;Таблица дескрипторов прерываний
	idt	label	byte
	; ПРОПУСКАЕМ 32 ИСКЛЮЧЕНИЯ И ПЕРЕХОДИМ ИМЕННО К ПРОЦЕССОРНЫМ
	; 8fh - шлюз ловушки мп 486
		trap1				intdesc	13 dup (<,sel_code32,,8fh>)	
		trap13				intdesc	<0, sel_code32,,8fh>			;Исключение общей защиты
		trap2				intdesc	18 dup (<,sel_code32,,8fh>)	
		timer				intdesc	<,sel_code32,,8eh>		    	;Дескриптор прерывания от таймера
		keyboard				intdesc	<,sel_code32,,8eh>				;Дескриптор прерывания от клавиатуры
	idt_size = $-idt

;Псевдодескриптор IDTR
	idtr	dw idt_size-1	;Limit IDT
			dd ?			;Линейный адрес IDT

	idtr_r	dw 3ffh,0,0		;Содержимое регистра IDTR в реальном режиме (0000h до 256х4 = 03ffh)

	msg_proctected_mode	db 'Welcome to protected mode!'
	msg_proctected_mode_size = $-msg_proctected_mode
	
	msg_real_mode	db 'Welcome to real mode!', 10, 13, '$'
	msg_real_mode_size = $-msg_real_mode-1
	
	msg_time	db 'TIME: '
	msg_time_size = $-msg_time
	
	msg_memory	db 'MEMORY: '
	msg_memory_size = $-msg_memory
	
	msg_trap13	db 'Trap 13 :  EIP ='
	msg_trap13_size = $-msg_trap13


	elem_position	dd 20*160		; Позиция печати вводимого текста
	cnt_timer	dw 0

;Маски прерываний ведущего и ведомого контроллера
	master	db 0
	slave	db 0
	
	ascii_table db 0,1bh,'1','2','3','4','5','6','7','8','9','0','-','=',8
				db ' ','q','w','e','r','t','y','u','i','o','p','[',']','$'
				db ' ','a','s','d','f','g','h','j','k','l',';','""',0
				db '\','z','x','c','v','b','n','m',',','.','/',0,0,0,' ',0,0
				db 0,0,0,0,0,0,0,0,0,0,0,0
	
data16_size = $-gdt
data16	ends




code32	segment	'code' use32
	assume	cs:code32, ds:data16, ss:stack32

main32:
;Устанавливаем селекторы в сегментные регистры
	mov		AX, sel_4gb
	mov		ES, AX
	
	mov 	AX, sel_data16
	mov		DS, AX
	
	mov		AX, sel_stack32
	mov		SS, AX
	
	mov		EBX, stack32_size
	mov		ESP, EBX
	
;Разрешаем маскируемые и немаскируемые прерывания
	in		AL, 70h
	and		AL, 7Fh
	out		70h, AL
	sti
	
	msg_output msg_proctected_mode, msg_proctected_mode_size, 1, 0
	msg_output msg_time, msg_time_size, 6, 0
	msg_output msg_memory, msg_memory_size, 5, 0
	
	call	find_free_memory
	
	jmp $
	
;Запрещаем маскируемые и немаскируемые прерывания
	cli
	in		AL, 70h
	or		AL, 80h
	out		70h, AL
	
	
	
find_free_memory proc
	push	EAX
	push	EBX
	push	EDX
	
	mov		EBX, 100001h	; Пропускаем первый мегабайт сегмента (потому, что в противном случае может произойти попытка редактирования процедуры собственного кода)
							;  если не пропустить, то gate selector points to illegal descriptor with type 0
	mov		DL, 11111111b	; Сигнатура
	mov		ECX, 0FFEFFFFFh	; В ECX кладём количество оставшейся памяти - чтобы не было переполнения
							; лимит в 4 Гб = 4096 Мб, без одного Мб = 4293918719 байт
check:
	mov		DH, ES:[EBX]	; 
	mov		ES:[EBX], DL	; Пишем сигнатуру
	cmp		ES:[EBX], DL	; Читаем
	jnz		end_of_memory	; если не совпали - то мы достигли конца памяти, выходим из цикла
	mov		ES:[EBX], DH	; если не достигли - кладём обратно сохранённое значение
	inc		EBX				; Проверяем следующий байт и тд (размер памяти можно задать в настройках DOSBOX по умолчанию 16 Мб)
	loop	check

end_of_memory:
	
	xor		EDX, EDX
	mov		EAX, EBX
	mov		EBX, 100000h	; делим, чтобы получить результат в Мб
	div		EBX
	pop		EDX
	pop		EBX

	num_output AX, 5, 10
	
	pop		EAX
	ret
find_free_memory endp

;Заглушка для исключений 1-12 и 14-32
dummy_exc proc
	iretd
dummy_exc endp

;Заглушка для 13 исключения
exc13	proc
	pop		EAX
	pop		EAX
	msg_output msg_trap13, msg_trap13_size, 5, 0
	num_output AX, 5, 30
	shr 	EAX, 16
	num_output AX, 5, 28
	iretd
exc13	endp

;Обработчик прерывания INT 8H
timer_handler:
	push	EAX
	
	mov		AX, cnt_timer
	inc		AX
	mov		cnt_timer, AX
	
	num_output cnt_timer, 6, 10

;Посылаем сигнал EOI контроллеру прерываний
	mov		AL, 20h
	out		20h, AL

	pop		EAX
	iretd


;Обработчик прерывания INT 9H
keyboard_handler:
	push	EAX
	push	EBX
	push 	ECX
	push	ES

;Чтение скан-код нажатой клавиши из порта клавиатуры
	in		AL, 60h				

;Сравнение с кодом ESC. Если ESC, выходим в реальный режим
	cmp		AL, 01h				
	je		esc_pressed
	
;Определение скан-кода (обслуживаемой клавиши или нет)
	cmp		AL, 39h	
	ja		skip_translate			
	
	mov		EBX, offset ascii_table	;Таблица для перевода скан-кода в ASCII
	xlatb							;Преобразовать
	
	mov		EBX, elem_position				;Позиции на экране

;Проверка на нажатие Backspace
	cmp		AL, 8					
	je		bs_pressed
	
	mov 		CX, sel_screen
	mov 		ES, CX
	mov		ES:[EBX], AL	;Вывести символ на экран
	add		dword ptr elem_position, 2		;Увеличить адрес позиции на 2
	jmp		short skip_translate
	
bs_pressed:
	mov		al, ' '					;Вывести пробел в позиции предыдущего символа
	sub		ebx, 2
	
	mov 		CX, sel_screen
	mov 		ES, ECX
	mov		ES:[EBX], AL	;Вывести символ на экран
	mov		elem_position, EBX				;и сохранить адрес предыдущего символа как текущий
skip_translate:
;Разрешить работу клавиатуры
	in		AL, 61h
	or		AL, 80h
	out		61h, AL
	
;Посылаем сигнал EOI контроллеру прерываний
	mov		AL, 20h
	out		20h, AL
	
	
	pop		ES
	pop 		ECX
	pop		EBX
	pop		EAX
	iretd
	
esc_pressed:
;Разрешить работу клавиатуры, послать EOI и восстановить регистры.
	in		AL, 61h
	or		AL, 80h
	out		61h, AL
	mov		AL, 20h
	out		20h, AL
	pop		ES
	pop		EBX
	pop		EAX

;Запрещаем маскируемые и немаскируемые прерывания
	cli
	in		AL, 70h
	or		AL, 80h
	out		70h, AL

;Возврат в реальный режим
	db		0EAh
	dd		return16
	dw		sel_code16

	code32_size = $-main32
code32	ends




code16	segment para public 'CODE' use16
	assume cs:code16, ds:data16

main16:
;Очистка консоли
	mov		AX, 3
	int		10h

;Подготовка сегментных регистров
	mov		AX, data16
	mov		DS, AX
	
;Вывод сообщения msg_real_mode
	mov 	AH, 09h
	mov 	EDX, offset msg_real_mode
	int 	21h

;Вычисление базы для всех используемых дескрипторов сегментов
	xor		EAX, EAX
	mov		AX, code16
	shl		EAX, 4
	mov		gdt_code16.base_l, AX	
	shr		EAX, 16
	mov		gdt_code16.base_m, AL	
	
	mov		AX, code32
	shl		EAX, 4
	mov		gdt_code32.base_l, AX	
	shr		EAX, 16
	mov		gdt_code32.base_m, AL	
	
	mov		AX, stack32
	shl		EAX, 4	
	mov		gdt_stack32.base_l, AX
	shr		EAX, 16	
	mov		gdt_stack32.base_m, AL
	
	mov		AX, data16
	shl		EAX, 4
	mov 		EBP, EAX
	mov		gdt_data16.base_l, AX
	shr		EAX, 16
	mov		gdt_data16.base_m, AL


;Вычислим линейный адрес GDT
	mov		EAX, EBP
	add		EAX, offset gdt				;В EAX будет линейный адрес GDT (адрес сегмента + смещение GDT относительно него)
	mov		dword ptr gdtr+2, EAX		;Кладём полный линейный адрес в младшие 4 байта переменной gdtr
	mov		word ptr gdtr, gdt_size-1	;В старшие 2 байта заносим размер gdt

;Загрузим в GDTR псевдодескриптор gdtr
	lgdt	fword ptr gdtr

;Аналогично вычислим линейный адрес IDT
	mov		EAX, EBP
	add		EAX, offset idt
	mov		dword ptr idtr+2, EAX
	mov		word ptr idtr, idt_size-1


;Заполним смещение в дескрипторах прерываний
	mov		EAX, offset dummy_exc
	mov		trap1.offs_l, AX
	mov		trap2.offs_l, AX
	shr		EAX, 16
	mov		trap1.offs_h, AX
	mov		trap2.offs_h, AX
	
	mov		EAX, offset exc13
	mov		trap13.offs_l, AX
	shr		EAX, 16
	mov		trap13.offs_h, AX
	
	mov		EAX, offset timer_handler
	mov		timer.offs_l, AX
	shr		EAX, 16
	mov		timer.offs_h, AX
	
	mov		EAX, offset keyboard_handler
	mov		keyboard.offs_l, AX
	shr		EAX, 16
	mov		keyboard.offs_h, AX


;Cохраним маски ведомого и ведущего контроллеров прерываний
	in		AL, 21h
	mov		master, AL	
	
	in		AL, 0A1h
	mov		slave, AL

;Перепрограммируем ведущий контроллер прерываний
	mov		AL, 11h	; ски1: будет ски3
	out		20h, AL
	
	mov		AL, 20h	; ски2: Базовый вектор (начальное смещение для обработчика) теперь 32 (20h) (вслед за векторами исключений)
	out		21h, AL	; Указываем, что аппаратные прерывания будут обрабатываться начиная с 32го (20h)
	
	mov		Al, 4  ; ски3: ведомый подключен к уровню два
	out		21h, AL
	
	mov		AL, 1	; ски4: 80х86, требуется EOI 
	out		21h, AL

;Запретим все маскируемые прерывания в ведущем контроллере, кроме IRQ0 (таймер) и IRQ1(клавиатура)
	mov		AL, 0FCh	;Маска прерываний 11111100
	out		DX, AL

; Запретим все маскируемые прерывания в ведомом контроллере
	mov		DX, 0A1h
	mov		AL, 0FFh
	out		DX, AL

;Загрузим в IDTR псевдодескриптор idtr
	lidt	fword ptr idtr

;Открытие линии А20
;Линия А20 - какая-то надстройка на более поздние процессоры, необходимая для совместимости со старыми вресиями пк
;При проектировании микропроцессора 80286 инженеры Intel допустили ошибку, позволившую из
;реального режима обращаться к части памяти за пределами младшего мегабайта — так называемой
;области верхней памяти (HMA). Чтобы компенсировать эту ошибку и гарантировать совместимость со
;старыми программами, в состав компьютера пришлось включить специальную схему, блокирующую 20-й
;разряд шины адреса (или все старшие разряды, начиная с 20-го — это зависит от особенностей чипсета)
;— Gate A20 (вентиль или шлюз линии A20). При использовании старых программ реального режима этот
;вентиль может быть закрыт, что обеспечит присутствие на линии A20 логического нуля, а при работе
;новых программ, поддерживающих защищённый режим, этот вентиль должен быть обязательно открыт.

;Область верхней памяти (HMA, High Memory Area) — область оперативной памяти объёмом 65520 байтов 
;(64 Кбайта без 16 байт), расположенная по адресам 0010_0000 — 0010_FFEF, т.е. сразу свыше 1 Мбайта.
	mov		AL, 0D1h
	out		64h, AL
	mov		AL, 0dfh
	out		60h, AL
	
;Запрещаем маскируемые и немаскируемые прерывания
	cli
	in		AL, 70h
	or		AL, 80h
	out		70h, AL

;Перейти в непосредственно защищенный режим установкой соответствующего бита PE регистра CR0
	mov		EAX, CR0
	or		AL, 1
	mov		CR0, EAX

; Загрузить sel_code32 в регистр CS
; far jump в p_entry
	db	66h
	db	0eah
	dd	offset main32
	dw	sel_code32


;>>>> Начиная с этой строчки, будет выполняться код защищенного режима


return16:
; Переход в реальный режим
	
;Закрываем линию А20
	mov		AL, 0D1h
	out		64h, AL
	mov		Al, 0DDh
	out		60h,al

;Сбрасываем флаг PE системного регистра CR0
	mov		EAX, CR0
	and		AL, 0FEh		
	mov		CR0, EAX

;Сбросить очередь и загрузить CS реальным числом
	db		0EAh
	dw		$+4
	dw		code16

;Восстановить регистры для работы в реальном режиме
	mov		AX, code32		;Загружаем в сегментные регистры реальные смещения
	mov		ES, AX
	
	mov 	AX, data16
	mov		DS, AX
	
	mov		AX, stack32
	mov		SS, AX
	
	mov		BX, stack32_size-1
	mov		SP, BX

;Реинициализация контроллера прерываний
	mov		AL, 11h
	out		20h, AL
	
	mov		AL, 8
	out		21h, AL
	
	mov		AL, 4
	out		21h, AL
	
	mov		AL, 1
	out		21h, AL

;Восстанавливаем маски контроллеров прерываний
	mov		AL, master
	out		21h, AL
	mov		AL, slave
	out		0A1h, AL

;Загружаем таблицу дескрипторов прерываний реального режима
	lidt	fword ptr idtr_r

;Разрешаем маскируемые и немаскируемые прерывания
	in		AL, 70h
	and		AL, 7Fh
	out		70h, AL
	sti

;Установка курсора
	mov		AH, 2
	xor		BX, BX
	mov		DX, 200h
	int		10h

;Вывод сообщения
	mov 	AH, 9
	mov 	EDX, offset msg_real_mode
	int 	21h
	xor 	EDX, EDX
	mov		AH, 4Ch
	int		21h
	
code16_size = $-main16
code16	ends

stack32	segment para stack 'stack'
	stack_start	db 100h dup(?)
stack32_size = $-stack_start
stack32	ends

end main16
