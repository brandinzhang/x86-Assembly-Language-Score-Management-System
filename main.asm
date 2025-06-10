DATA SEGMENT
PROMPT_ID DB 'ID : $'
PROMPT_SCORE DB 'score: $'
ID DB 9, ?, 9 DUP('$') ; 学号缓冲区
SCORE_INPUT DB 4, ?, 4 DUP('$') ; 分数输入缓冲区
SCORE DW ? ; 存储转换后的分数
COUNT_60 DB 0 ; [0,60]
COUNT_70 DB 0 ; (60,70]
COUNT_80 DB 0 ; (70,80]
COUNT_90 DB 0 ; (80,90]
COUNT_100 DB 0 ; (90,100]
FAIL_LIST DB 'Below 60 students:', 0DH, 0AH, '$'
FAIL_ENTRY DB 'ID: ', 8 DUP(' '), ' Score: ', 3 DUP(' '), 0DH, 0AH, '$'
NEWLINE DB 0DH, 0AH, '$'
FAIL_BUFFER DB 200 DUP('$') ; 存储不及格记录
FAIL_PTR DW OFFSET FAIL_BUFFER ; 动态指针
DATA ENDS


CODE SEGMENT
ASSUME CS:CODE, DS:DATA
START:
MOV AX, DATA
MOV DS, AX

INPUT_LOOP:
; 输入学号
LEA DX, PROMPT_ID
MOV AH, 09H
INT 21H

LEA DX, ID
MOV AH, 0AH
INT 21H

LEA DX, NEWLINE
MOV AH, 09H
INT 21H

; 检查是否输入'end'
CMP BYTE PTR ID+2, 'e'
JNE CONTINUE
CMP BYTE PTR ID+3, 'n'
JNE CONTINUE
CMP BYTE PTR ID+4, 'd'
JE EXIT_INPUT

CONTINUE:
; 输入成绩（支持3位数）
LEA DX, PROMPT_SCORE
MOV AH, 09H
INT 21H

LEA DX, SCORE_INPUT
MOV AH, 0AH
INT 21H

LEA DX, NEWLINE
MOV AH, 09H
INT 21H

; 将分数字符串转换为数字
CALL CONVERT_SCORE

; 分数段统计
CMP SCORE, 60
JLE ADD_60
CMP SCORE, 70
JLE ADD_70
CMP SCORE, 80
JLE ADD_80
CMP SCORE, 90
JLE ADD_90
JMP ADD_100

ADD_60:
INC COUNT_60
CALL RECORD_FAIL ; 记录不及格学生
JMP NEXT_STUDENT
ADD_70:
INC COUNT_70
JMP NEXT_STUDENT
ADD_80:
INC COUNT_80
JMP NEXT_STUDENT
ADD_90:
INC COUNT_90
JMP NEXT_STUDENT
ADD_100:
INC COUNT_100

NEXT_STUDENT:
JMP INPUT_LOOP

EXIT_INPUT:
CALL DISPLAY_RESULTS ; 输出统计结果
MOV AH, 4CH
INT 21H

; 子程序：将分数字符串转换为数字（支持3位数）
CONVERT_SCORE PROC
    PUSH AX  ; 保存寄存器
    PUSH BX
    PUSH CX
    XOR AX, AX  ; 清空AX寄存器
    MOV BX, 10
    LEA SI, SCORE_INPUT + 2 ; 指向输入的第一个字符
    MOV CL, SCORE_INPUT + 1 ; 输入的长度
    CMP CL, 0
    JE INVALID ; 输入为空则跳过

    CONVERT_LOOP:
    MUL BX ; AX = AX * 10
    MOV DL, [SI]
    SUB DL, '0'  ; ASCII转数字（'0'=48）
    ADD AX, DX   ; AX = AX + 当前数字
    INC SI     ; 指向下一个字符
    LOOP CONVERT_LOOP
    MOV SCORE, AX
    JMP END_CONVERT

    INVALID:
    MOV SCORE, 0 ; 默认0分

    END_CONVERT:
    POP CX
    POP BX
    POP AX
    RET
CONVERT_SCORE ENDP

; 子程序：记录不及格学生（支持3位数分数）
RECORD_FAIL PROC
    PUSH SI
    PUSH DI
    ; 复制到FAIL_BUFFER
    MOV DI, FAIL_PTR

    ; 填充"ID: "
    MOV BYTE PTR [DI], 'I'
    INC DI
    MOV BYTE PTR [DI], 'D'
    INC DI
    MOV BYTE PTR [DI], ':'
    INC DI
    MOV BYTE PTR [DI], ' '
    INC DI

    ; 填充学号
    LEA SI, ID + 2
    MOV CX, 8
    COPY_ID:
    MOV AL, [SI]
    MOV [DI], AL
    INC SI
    INC DI
    LOOP COPY_ID

    ; 填充" Score: "
    MOV BYTE PTR [DI], ' '
    INC DI
    MOV BYTE PTR [DI], 'S'
    INC DI
    MOV BYTE PTR [DI], 'c'
    INC DI
    MOV BYTE PTR [DI], 'o'
    INC DI
    MOV BYTE PTR [DI], 'r'
    INC DI
    MOV BYTE PTR [DI], 'E'
    INC DI
    MOV BYTE PTR [DI], ':'
    INC DI
    MOV BYTE PTR [DI], ' '
    INC DI

    ; 填充成绩（固定3位数，如005或100）
    MOV AX, SCORE
    ; 百位数
    MOV BL, 100
    DIV BL ; AL=百位，AH=余数
    ADD AL, '0'
    MOV [DI], AL
    INC DI
    ; 十位和个位
    MOV AL, AH
    XOR AH, AH
    MOV BL, 10
    DIV BL ; AL=十位，AH=个位
    ADD AL, '0'
    MOV [DI], AL
    INC DI
    ADD AH, '0'
    MOV [DI], AH
    INC DI

    ; 添加换行
    MOV BYTE PTR [DI], 0DH
    INC DI
    MOV BYTE PTR [DI], 0AH
    INC DI
    MOV BYTE PTR [DI], '$'

    ; 更新指针
    MOV FAIL_PTR, DI
    POP DI
    POP SI
    RET
RECORD_FAIL ENDP

; 子程序：显示统计结果
DISPLAY_RESULTS PROC
    ; 显示分数段统计
    CALL SHOW_STATS

    ; 显示不及格名单
    LEA DX, FAIL_LIST
    MOV AH, 09H
    INT 21H
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    LEA DX, FAIL_BUFFER ; 输出所有记录
    MOV AH, 09H
    INT 21H
    RET

    SHOW_STATS:
    ; [0,60]
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    MOV DL, '['
    MOV AH, 02H
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ','
    INT 21H
    MOV DL, '6'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ']'
    INT 21H
    MOV DL, ':'
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, COUNT_60
    ADD DL, '0'
    INT 21H
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H

    ; (60,70]
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    MOV DL, '('
    MOV AH, 02H
    INT 21H
    MOV DL, '6'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ','
    INT 21H
    MOV DL, '7'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ']'
    INT 21H
    MOV DL, ':'
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, COUNT_70
    ADD DL, '0'
    INT 21H
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H

    ; (70,80]
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    MOV DL, '('
    MOV AH, 02H
    INT 21H
    MOV DL, '7'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ','
    INT 21H
    MOV DL, '8'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ']'
    INT 21H
    MOV DL, ':'
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, COUNT_80
    ADD DL, '0'
    INT 21H
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H

    ; (80,90]
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    MOV DL, '('
    MOV AH, 02H
    INT 21H
    MOV DL, '8'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ','
    INT 21H
    MOV DL, '9'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ']'
    INT 21H
    MOV DL, ':'
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, COUNT_90
    ADD DL, '0'
    INT 21H
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H

    ; (90,100]
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    MOV DL, '('
    MOV AH, 02H
    INT 21H
    MOV DL, '9'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ','
    INT 21H
    MOV DL, '1'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, '0'
    INT 21H
    MOV DL, ']'
    INT 21H
    MOV DL, ':'
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, COUNT_100
    ADD DL, '0'
    INT 21H
    LEA DX, NEWLINE
    MOV AH, 09H
    INT 21H
    RET
DISPLAY_RESULTS ENDP

CODE ENDS
END START
