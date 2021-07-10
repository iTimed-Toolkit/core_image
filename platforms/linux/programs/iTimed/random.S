.altmacro

#define IS(i)            v ## i

#define AESI            v16
#define AESC            v17

#define v2L             v30
#define AESK(i)         v2 ## i
#define AESR            v31

/* Getters and setters */

// w1: index to compare against
.macro  GET_AT_REG      reg
    mov     x1,         \reg
    b       .L__get_at_index_out
.endm

// x0: index to compare against
// x1: value to store (shifted)
// x2: flag
.macro  SET_AT_REG      reg
    mov     x0,         \reg
    and     x0,         x0,         x2
    eor     x0,         x0,         x1
    mov     \reg,       x0
    b       .L__set_at_done
.endm

/* AES helpers */

.macro  AES_ROUND       rk
    aese    AESR.16b,   \rk
    aesmc   AESR.16b,   AESR.16b
.endm

.macro  AES_LAST
    aese    AESR.16b,   AESK(9).16b
    eor     AESR.16b,   AESR.16b,    AESK(L).16b
.endm

.macro  RESEED_AES
    AES_ROUND           AESK(0).16b
    AES_ROUND           AESK(1).16b
    AES_ROUND           AESK(2).16b
    AES_ROUND           AESK(3).16b
    AES_ROUND           AESK(4).16b
    AES_ROUND           AESK(5).16b
    AES_ROUND           AESK(6).16b
    AES_ROUND           AESK(7).16b
    AES_ROUND           AESK(8).16b
    AES_LAST

    SET_AES_STATUS      wzr
    GET_AES_COUNT       x0
    add     x0,         x0,          0x1
    SET_AES_COUNT       x0
.endm

.macro SET_AES_STATUS  val
    mov     AESI.b[0],  \val
.endm

.macro GET_AES_STATUS   reg
    mov     \reg,       AESI.s[0]
    and     \reg,       \reg,         0xFF
.endm

.macro SET_AES_COUNT    val
    mov     AESC.d[0],  \val
.endm

.macro GET_AES_COUNT    val
    mov     \val,       AESC.d[0]
.endm

/* Rotation macros */

.macro  ROT8            r, load
    mov     \r&.b[0],   \r&.b[1]
    mov     \r&.b[1],   \r&.b[2]
    mov     \r&.b[2],   \r&.b[3]
    mov     \r&.b[3],   \r&.b[4]
    mov     \r&.b[4],   \r&.b[5]
    mov     \r&.b[5],   \r&.b[6]
    mov     \r&.b[6],   \r&.b[7]
    mov     \r&.b[7],   \r&.b[8]
    mov     \r&.b[8],   \r&.b[9]
    mov     \r&.b[9],   \r&.b[10]
    mov     \r&.b[10],  \r&.b[11]
    mov     \r&.b[11],  \r&.b[12]
    mov     \r&.b[12],  \r&.b[13]
    mov     \r&.b[13],  \r&.b[14]
    mov     \r&.b[14],  \r&.b[15]
    mov     \r&.b[15],  \load
.endm

.macro  ROT16           r, load
    mov     \r&.h[0],   \r&.h[1]
    mov     \r&.h[1],   \r&.h[2]
    mov     \r&.h[2],   \r&.h[3]
    mov     \r&.h[3],   \r&.h[4]
    mov     \r&.h[4],   \r&.h[5]
    mov     \r&.h[5],   \r&.h[6]
    mov     \r&.h[6],   \r&.h[7]
    mov     \r&.h[7],   \load
.endm

/* Clearers */
.macro  CLEAR_IS        from=0, to=15
    mov     IS(\from&).d[0], xzr
    mov     IS(\from&).d[1], xzr

    .if     \to-\from
        CLEAR_IS    %\from + 1,\to
    .endif
.endm

.macro  CLEAR_AESK      from=0, to=9
    mov     AESK(\from&).d[0],  xzr
    mov     AESK(\from&).d[1],  xzr

    .if     \to-\from
        CLEAR_AESK  %\from + 1,\to
    .else
        mov     AESK(L).d[0],   xzr
        mov     AESK(L).d[1],   xzr
    .endif
.endm

.text
.global random_init, random_seed,       \
        aes_save, aes_load,             \
        __next_uint8, __next_uint16,    \
        __get_at_index, __set_at_index, \
        __clear_is, __clear_aesk

/* ASM API */
__clear_is:
    CLEAR_IS
    ret

__clear_aesk:
    CLEAR_AESK
    SET_AES_STATUS      wzr
    SET_AES_COUNT       xzr
    ret

__next_uint8:
    GET_AES_STATUS      w0
    cmp     w0,         0xF
    b.ne    .L__read_next_uint8

    RESEED_AES
    mov     w0,         0x0

.L__read_next_uint8:
    add     w0,         w0,         0x1
    SET_AES_STATUS      w0

    // read next byte
    mov     w0,         AESR.s[0]
    and     w0,         w0,         0xFF

    // rotate buffer and replace byte
    ROT8    AESR,       w0
    ret

__next_uint16:
    GET_AES_STATUS      w0
    and     w1,         w0,         0xFE
    cmp     w0,         w1
    b.eq    .L__uint16_check_entropy

    add     w0,         w0,         0x1
.L__uint16_check_entropy:
    cmp     w0,         0x10
    b.ne    .L__read_next_uint16

    RESEED_AES
    mov     w0,         0x0

.L__read_next_uint16:
    SET_AES_STATUS      w0

    // read next short
    mov     w0,         AESR.s[0]
    and     w0,         w0,         0xFFFF

    // rotate buffer and replace short
    ROT16   AESR,       w0
    ret

__get_at_index:
    and     x0,         x0,         0xFF
    eor     x0,         x0,         x0,     LSL 0x20
    lsr     x0,         x0,         0x3
    lsl     x0,         x0,         0x3

    adr     x1,         .L__get_at_index_start
    add     w1,         w1,         w0
    lsr     x0,         x0,         0x20
    br      x1

.L__get_at_index_start:
    GET_AT_REG          IS(0).d[0]
    GET_AT_REG          IS(0).d[1]
    GET_AT_REG          IS(1).d[0]
    GET_AT_REG          IS(1).d[1]
    GET_AT_REG          IS(2).d[0]
    GET_AT_REG          IS(2).d[1]
    GET_AT_REG          IS(3).d[0]
    GET_AT_REG          IS(3).d[1]
    GET_AT_REG          IS(4).d[0]
    GET_AT_REG          IS(4).d[1]
    GET_AT_REG          IS(5).d[0]
    GET_AT_REG          IS(5).d[1]
    GET_AT_REG          IS(6).d[0]
    GET_AT_REG          IS(6).d[1]
    GET_AT_REG          IS(7).d[0]
    GET_AT_REG          IS(7).d[1]
    GET_AT_REG          IS(8).d[0]
    GET_AT_REG          IS(8).d[1]
    GET_AT_REG          IS(9).d[0]
    GET_AT_REG          IS(9).d[1]
    GET_AT_REG          IS(10).d[0]
    GET_AT_REG          IS(10).d[1]
    GET_AT_REG          IS(11).d[0]
    GET_AT_REG          IS(11).d[1]
    GET_AT_REG          IS(12).d[0]
    GET_AT_REG          IS(12).d[1]
    GET_AT_REG          IS(13).d[0]
    GET_AT_REG          IS(13).d[1]
    GET_AT_REG          IS(14).d[0]
    GET_AT_REG          IS(14).d[1]
    GET_AT_REG          IS(15).d[0]
    GET_AT_REG          IS(15).d[1]

.L__get_at_index_out:
    and     w0,         w0,         0x7 // 0b111
    lsl     w0,         w0,         0x3
    lsr     x0,         x1,         x0
    and     x0,         x0,         0xFF
    ret

//  x0: index
//  x1: value
__set_at_index:
    and     x0,         x0,         0xFF
    eor     x0,         x0,         x0,     LSL 0x38

    and     x1,         x1,         0xFF
    adr     x2,         .L__set_at_index_start
    eor     x1,         x1,         x2,     LSL 0x20

    // create correct offset
    lsr     x0,         x0,         0x3
    lsl     x0,         x0,         0x2

    // add 5-instruction sequence
    add     x1,         x1,         x0,     LSL 0x22
    add     x1,         x1,         x0,     LSL 0x20

    // shift value to correct spot
    lsr     x0,         x0,         0x2F
    eor     x0,         x0,         x1
    lsr     x0,         x0,         0x8
    lsl     x0,         x0,         0x3
    and     x1,         x1,         0xFF
    lsl     x1,         x1,         x0
    mov     x2,         0xFF
    lsl     x2,         x2,         x0
    mvn     x2,         x2

    lsr     x0,         x0,         0x1b
    br      x0

.L__set_at_index_start:
    SET_AT_REG          IS(0).d[0]
    SET_AT_REG          IS(0).d[1]
    SET_AT_REG          IS(1).d[0]
    SET_AT_REG          IS(1).d[1]
    SET_AT_REG          IS(2).d[0]
    SET_AT_REG          IS(2).d[1]
    SET_AT_REG          IS(3).d[0]
    SET_AT_REG          IS(3).d[1]
    SET_AT_REG          IS(4).d[0]
    SET_AT_REG          IS(4).d[1]
    SET_AT_REG          IS(5).d[0]
    SET_AT_REG          IS(5).d[1]
    SET_AT_REG          IS(6).d[0]
    SET_AT_REG          IS(6).d[1]
    SET_AT_REG          IS(7).d[0]
    SET_AT_REG          IS(7).d[1]
    SET_AT_REG          IS(8).d[0]
    SET_AT_REG          IS(8).d[1]
    SET_AT_REG          IS(9).d[0]
    SET_AT_REG          IS(9).d[1]
    SET_AT_REG          IS(10).d[0]
    SET_AT_REG          IS(10).d[1]
    SET_AT_REG          IS(11).d[0]
    SET_AT_REG          IS(11).d[1]
    SET_AT_REG          IS(12).d[0]
    SET_AT_REG          IS(12).d[1]
    SET_AT_REG          IS(13).d[0]
    SET_AT_REG          IS(13).d[1]
    SET_AT_REG          IS(14).d[0]
    SET_AT_REG          IS(14).d[1]
    SET_AT_REG          IS(15).d[0]
    SET_AT_REG          IS(15).d[1]

.L__set_at_done:
    ret

/* C API */

// void aes_save(uint8_t *state)
aes_save:
    st1     {AESR.4s},      [x0]
    ret

// void aes_load(uint8_t *state)
aes_load:
    ld1     {AESR.4s},      [x0]
    ret

// void random_seed(uint8_t *expanded)
random_seed:
    ld1     {AESK(0).4s},   [x0],       0x10
    ld1     {AESK(1).4s},   [x0],       0x10
    ld1     {AESK(2).4s},   [x0],       0x10
    ld1     {AESK(3).4s},   [x0],       0x10
    ld1     {AESK(4).4s},   [x0],       0x10
    ld1     {AESK(5).4s},   [x0],       0x10
    ld1     {AESK(6).4s},   [x0],       0x10
    ld1     {AESK(7).4s},   [x0],       0x10
    ld1     {AESK(8).4s},   [x0],       0x10
    ld1     {AESK(9).4s},   [x0],       0x10
    ld1     {AESK(L).4s},   [x0],       0x10

    // force reseed
    mov     x0,         0xF
    SET_AES_STATUS      w0
    ret

// void random_init()
random_init:
    // index state
    CLEAR_IS

    // miscellaneous indices
    SET_AES_STATUS          wzr
    SET_AES_COUNT           xzr

    // AES key schedule
    CLEAR_AESK

    // AES data / random numbers
    mov     AESR.D[0],   xzr
    mov     AESR.D[1],   xzr
    ret
