.syntax unified
.cpu arm946e-s

.equ SAVE_SLOT_SIZE, 0x5540
.equ ARM7_COPY_DEST, 0x02380000
.equ ARM7_COPY_LEN, 9380
.equ ARM9_CARDi_RequestStreamCommand, 0x0200dfb0
.equ ARM9_COPY_DEST, 0x020DBE10 // 試合コンテキスト構造体の領域を使う
.equ ARM9_COPY_LEN, 11576
.equ ARM7_ENTRY_POINT, 0x02380000
.equ ADDR_DEST, 0x02289F84
.equ ARM9_START, 0x02000000
.equ WRAMCNT, 0x04000247
.equ BASE_ADDR, 0x0228ec8c

.section .text.main, "ax", %progbits
.align 2
.arm
.global main
.type main, %function
main:
    // Disable IRQ and FIQ.
    mrs     r0, cpsr
    orr     r0, r0, #0xc0
    msr     cpsr_c, r0

    mov     r0, #0x04000000      // ARM9 I/O base
    mov     r1, #0

    // Stop all ARM9 DMA channels.
    str     r1, [r0, #0x0b8]     // DMA0CNTs
    str     r1, [r0, #0x0c4]     // DMA1CNT
    str     r1, [r0, #0x0d0]     // DMA2CNT
    str     r1, [r0, #0x0dc]     // DMA3CNT

    // Power on both LCDs and both 2D engines. Preserve LCD swap.
    add     r2, r0, #0x300
    ldrh    r3, [r2, #4]         // POWCNT1 = 0x04000304
    orr     r3, r3, #3           // LCD | Engine A
    orr     r3, r3, #0x200       // Engine B
    strh    r3, [r2, #4]

    // Disable blending and master-brightness effects.
    strh    r1, [r0, #0x050]     // BLDCNT main
    strh    r1, [r0, #0x06c]     // MASTER_BRIGHT main
    add     r2, r0, #0x1000
    strh    r1, [r2, #0x050]     // BLDCNT sub
    strh    r1, [r2, #0x06c]     // MASTER_BRIGHT sub

    // Set both backdrop colors to RGB555(31, 0, 0).
    mov     r2, #0x05000000
    mov     r3, #0x1f
    strh    r3, [r2]             // Main BG palette[0]
    add     r2, r2, #0x400
    strh    r3, [r2]             // Sub BG palette[0]

    // Normal graphics display with every BG and OBJ layer disabled.
    mov     r3, #0x10000
    str     r3, [r0]             // DISPCNT main
    add     r2, r0, #0x1000
    str     r3, [r2]             // DISPCNT sub

    // Drain the ARM9 write buffer before stopping.
    mcr     p15, 0, r1, c7, c10, 4
    

    // ARM7の機械語をセーブデータから読み込み
    sub sp, 0x14
    ldr r0, =(0x40 + 1 * SAVE_SLOT_SIZE + 0x80 + ARM9_COPY_LEN) // src
    ldr r1, =ARM7_COPY_DEST // dest
    ldr r2, =ARM7_COPY_LEN // len
    mov r3, #0 // callback
    str r3, [sp, #0] // callback_arg
    mov r5, #0
    str r5, [sp, #4] // is_async
    mov r5, #6
    str r5, [sp, #0x08] // req_type
    mov r5, #1
    str r5, [sp, #0x0c] // req_retry
    mov r5, #0
    str r5, [sp, #0x10] // req_mode
    ldr r5, =ARM9_CARDi_RequestStreamCommand
    blx r5
    add sp, 0x14

    mov r0, #0x0060000
busywait0:
    subs r0, 1
    bcs busywait0

    // ARM9の機械語をセーブデータから読み込み
    sub sp, 0x14
    ldr r0, =(0x40 + 1 * SAVE_SLOT_SIZE + 0x80) // src
    ldr r1, =ARM9_COPY_DEST // dest
    ldr r2, =ARM9_COPY_LEN // len
    mov r3, #0 // callback
    str r3, [sp, #0] // callback_arg
    mov r5, #0
    str r5, [sp, #4] // is_async
    mov r5, #6
    str r5, [sp, #0x08] // req_type
    mov r5, #1
    str r5, [sp, #0x0c] // req_retry
    mov r5, #0
    str r5, [sp, #0x10] // req_mode
    ldr r5, =ARM9_CARDi_RequestStreamCommand
    blx r5
    add sp, 0x14

    mov r0, #0x0060000
busywait1:
    subs r0, 1
    bcs busywait1

    // 青背景へ
    mov     r2, #0x05000000
    mov     r3, #0x1f
    lsl r3, r3, #10
    strh    r3, [r2]
    add     r2, r2, #0x400
    strh    r3, [r2]
    mcr     p15, 0, r1, c7, c10, 4

    // ARM7をShared WRAM以外の領域での実行で忙しくするため、セーブデータの読み込みリクエストを発行する
    sub sp, 0x14
    mov r0, #0x40 // src
    ldr r1, =ADDR_DEST // dest
    ldr r2, =SAVE_SLOT_SIZE // len
    mov r3, #0 // callback
    str r3, [sp, #0] // callback_arg
    mov r5, #1
    str r5, [sp, #4] // is_async
    mov r5, #6
    str r5, [sp, #0x08] // req_type
    mov r5, #1
    str r5, [sp, #0x0c] // req_retry
    mov r5, #0
    str r5, [sp, #0x10] // req_mode
    ldr r5, =ARM9_CARDi_RequestStreamCommand
    blx r5
    add sp, 0x14

    //緑背景へ
    mov     r2, #0x05000000
    mov     r3, #0x1f
    lsl r3, r3, #5
    strh    r3, [r2]
    add     r2, r2, #0x400
    strh    r3, [r2]
    mcr     p15, 0, r1, c7, c10, 4

    mov r0, #0x0008000
busywait2:
    subs r0, 1
    bcs busywait2

    ldr r1, =WRAMCNT // WRAMCNT
    mov r0, 0
    strb r0, [r1]
    // region 0 を一時的に Shared WRAM に変更
    ldr     r0, =0x037F801D
    mcr     p15, 0, r0, c6, c0, 0

    ldr r0, =0x037F8000
    ldr r1, foolish_addr
    ldr r2, =(32 * 1024) / (4 * 8)
    bl repeat_block8x4


    // region 0 を元に戻す
    ldr     r0, =0x04000033
    mcr     p15, 0, r0, c6, c0, 0

    ldr r1, =WRAMCNT
    mov r0, 3
    strb r0, [r1]
    mcr     p15, 0, r1, c7, c10, 4


    // 黄色
    mov     r3, #0x1f
    mov     r4, #0x1f
    lsl r3, r3, 5
    orr r3, r4
    mov     r2, #0x05000000
    strh    r3, [r2]             /* Main BG palette[0] */
    add     r2, r2, #0x400
    strh    r3, [r2]             /* Sub BG palette[0] */
    mcr     p15, 0, r1, c7, c10, 4

    ldr r0, =ARM9_START
    ldr r1, =ARM9_COPY_DEST
    ldr r2, =ARM9_COPY_LEN
arm9_copy:
    ldr     r3, [r1], #4
    str     r3, [r0], #4
    subs    r2, r2, #4
    bne     arm9_copy
    ldr r0, =ARM9_START
    bx r0

repeat_block8x4:
    ldmia   r1, {r4-r11}
1:
    stmia   r0!, {r4-r11}
    stmia   r0!, {r4-r11}
    stmia   r0!, {r4-r11}
    stmia   r0!, {r4-r11}
    subs    r2, r2, #4
    bne     1b
    bx      lr

foolish_addr: .word (BASE_ADDR + 3 * 0x20 + 32 + 36 + 4 + (foolish - main))
foolish:
    ldr r0, addr0
    ldr r0, addr0
    ldr r0, addr0
    ldr r0, addr0
    ldr r0, addr0
    ldr r0, addr0
    bx r0
addr0: .word ARM7_ENTRY_POINT

