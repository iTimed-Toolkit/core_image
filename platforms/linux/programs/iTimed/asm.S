// prime, probe, and measurement functions without any
// extra loads. Should provide pretty clean timing
// measurements
.global prime, prime2, prime3, measure
.extern __next_uint8, __next_uint16,    \
        __get_at_index, __set_at_index, \
        __clear_is, __clear_aesk

#define     MASK        0xFF
#define     SHIFT       0

// void prime3(struct cache_block *base)
//  x1: temp
//  x2: temp
//  x3: cache set tracker
//  x4: current cache block
//  x5: current cache set base
//  x6: cache block count
//  x7: cache block base
//  x8: return address backup
prime3:
    mov     x1,     0x0
    mov     x2,     0x0
    mov     x3,     0x0
    mov     x4,     0x0
    mov     x5,     0x0
    mov     x6,     0x0
    mov     x7,     x0
    mov     x0,     0x0
    mov     x8,     x30
    bl      __clear_is
    b       .L_prime3_link_set

.L_prime3_link_randset:
    bl      __next_uint8
    and     x0,     x0,     MASK
    b       .L_prime3_link_randset_postrand

.L_prime3_link_randset_inc:
    mov     x0,     x2
    add     x0,     x0,     0x1
    and     x0,     x0,     MASK

.L_prime3_link_randset_postrand:
    mov     x2,     x0
    add     x0,     x0,     SHIFT
    bl      __get_at_index
    cmp     x0,     0x0
    b.ne    .L_prime3_link_randset_inc

    add     x2,     x2,     SHIFT
    add     x5,     x7,     x2,     LSL 0x6
    sub     x2,     x2,     SHIFT

    mov     x4,     x5
    eor     x3,     x0,     0x3
    b       .L_prime3_link_idx

.L_prime3_link_randidx:
    bl      __next_uint8
    b       .L_prime3_link_randidx_postrand

.L_prime3_link_randidx_inc:
    lsr     x0,     x0,     0x1
    add     x0,     x0,     0x1

.L_prime3_link_randidx_postrand:
    and     x0,     x0,     0x3
    lsl     x0,     x0,     0x1
    mov     x1,     0x3
    lsl     x1,     x1,     x0
    and     x1,     x3,     x1
    cmp     x1,     0x0
    b.ne    .L_prime3_link_randidx_inc

    add     x1,     x5,     x0,     LSL 0xD
    str     x1,     [x4]
    str     xzr,    [x4,    0x8]
    mov     x4,     x1

    mov     x1,     0x3
    lsl     x1,     x1,     x0
    eor     x3,     x3,     x1
.L_prime3_link_idx:
    cmp     x3,     0xFF
    b.ne    .L_prime3_link_randidx

    str     xzr,    [x4]
    str     xzr,    [x4, 0x8]

    sub     x0,     x5,     x7
    lsr     x0,     x0,     0x6
    mov     x1,     x3
    bl      __set_at_index

    add     x6,     x6,     0x1
.L_prime3_link_set:
    cmp     x6,     (MASK + 1)
    b.ne    .L_prime3_link_randset

    mov     x0,     0x0
    mov     x1,     0x0
    mov     x2,     0x0
    mov     x3,     0x0
    mov     x4,     0x0
    mov     x5,     0x0
    mov     x6,     0x0
    b       .L_prime3_prime_loop

.L_prime3_prime_iter:
    bl      __clear_is
    mov     x3,     0x0
    b       .L_prime3_prime_loop_inner

.L_prime3_prime_iter_inner:
    bl      __next_uint8    // set
    and     x0,     x0,     MASK
    mov     x5,     x0
    bl      __next_uint8    // line
    and     x0,     x0,     0x3
    eor     x5,     x5,     x0,     LSL 0x20
    b       .L_prime3_prime_iter_inner_set_postrand

.L_prime3_prime_iter_inner_set_inc:
    movk    x5,     0x0,    LSL 0x20
    add     x5,     x5,     0x1
    and     x5,     x5,     MASK

.L_prime3_prime_iter_inner_set_postrand:
    mov     x0,     x5
    and     x0,     x0,     MASK
    add     x0,     x0,     SHIFT
    bl      __get_at_index
    mov     x2,     x0
    cmp     x2,     0xFF
    b.eq    .L_prime3_prime_iter_inner_set_inc
    b       .L_prime3_prime_iter_inner_line_postrand

.L_prime3_prime_iter_inner_line_inc:
    mov     x0,     0x1
    lsl     x0,     x0,     0x20
    add     x5,     x5,     x0
    mov     x0,     0x0
    eor     x0,     x0,     x5,     LSR 0x20
    cmp     x0,     0x4
    b.eq    .L_prime3_prime_iter_inner_set_inc

.L_prime3_prime_iter_inner_line_postrand:
    mov     x0,     0x0
    eor     x0,     x0,     x5,     LSR 0x20
    and     x0,     x0,     0x3
    lsl     x0,     x0,     0x1
    lsr     x4,     x2,     x0
    and     x4,     x4,     0x3
    cmp     x4,     0x3
    b.eq    .L_prime3_prime_iter_inner_line_inc

label:
    and     x5,     x5,     MASK
    add     x5,     x5,     SHIFT
    add     x5,     x7,     x5,     LSL 0x6
    add     x5,     x5,     x0,     LSL 0xD
    ldr     x4,     [x5]
    str     xzr,    [x5,    0x8]

    mov     x4,     0x1
    lsl     x4,     x4,     x0
    add     x2,     x2,     x4

    sub     x0,     x5,     x0,     LSL 0xD
    sub     x0,     x0,     x7
    lsr     x0,     x0,     0x6
    mov     x1,     x2
    bl      __set_at_index

    add     x3,     x3,     0x1
.L_prime3_prime_loop_inner:
    cmp     x3,     0x300
    b.ne    .L_prime3_prime_iter_inner

    add     x6,     x6,     0x1
.L_prime3_prime_loop:
    cmp     x6,     0x4
    b.ne    .L_prime3_prime_iter

    mov     x30,    x8
    ret

// void prime2(struct cache_block *base, uint16 *entropy)
//  x0: cache block base
//  x1: entropy array base
//  x2: set index
//  x3: next index
//  x4: current set
//  x5: current set base
prime2:
    b       .L_prime2_link_loop_first

.L_prime2_link_iter:
    add     x3,     x5,     x3,     LSL 0xE
    str     x3,     [x4]
    str     xzr,    [x4, 0x8]
    mov     x4,     x3

.L_prime2_link_set:
    ldrh    w3,     [x1],   0x2
    cmp     w3,     0x1000
    b.ne    .L_prime2_link_iter

.L_prime2_link_loop:
    str     xzr,    [x4]
    str     xzr,    [x4, 0x8]

.L_prime2_link_loop_first:
    ldrh    w2,     [x1],   0x2
    add     x5,     x0,     x2,     LSL 0x6
    mov     x4,     x5
    cmp     w2,     0x1000
    b.ne    .L_prime2_link_set
    b       .L_prime2_prime_loop

.L_prime2_prime_iter:
    ldr     x4,     [x5]
    str     xzr,    [x5, 0x8]

.L_prime2_prime_loop:
    ldrh    w2,     [x1],   0x2
    add     x5,     x0,     x2,     LSL 0x6
    cmp     w2,     0x1000
    b.ne    .L_prime2_prime_iter
    ret

// void prime(struct cache_block *curr)
//  x0: cache block base
//  x1: current cache block
//  x2: next cache block
//  x3: counter
//  x4: repeat counter
prime:
    mov     x3,     0x0
    b       .L_prime_loop

.L_prime_iter_start:
    mov     x4,     0x0

.L_prime_iter_inner:
    add     x1,     x0,     x3,  LSL 0x6

.L_prime_iter:
    ldr     x2,     [x1]
    str     xzr,    [x1,    0x8]
    mov     x1,     x2
    cmp     x1,     0x0
    b.ne    .L_prime_iter

    add     x4,     x4,     0x1
    cmp     x4,     0x10         // NUM_LOOP
    b.ne    .L_prime_iter_inner

    add     x3,     x3,     0x1

.L_prime_loop:
    cmp     x3,     0xFF
    b.le    .L_prime_iter_start
    ret

// void probe(struct cache_block *curr);
//  x0: current cache block
//  x2: next cache block
//  x3: start time stamp
//  x4: end time stamp, difference
probe:
    b       .L_probe_loop
.L_probe_iter:
//    dsb     sy
    isb     sy
    mrs     x3,     cntpct_el0
//    dsb     sy
    isb     sy

    ldr     x2,     [x0]

//    dsb     sy
    isb     sy
    mrs     x4,     cntpct_el0
//    dsb     sy
    isb     sy

    sub     x4,     x4,     x3
    str     x4,     [x0,    0x8]
    mov     x0,     x2

.L_probe_loop:
    cmp     x0,     0x0
    b.ne    .L_probe_iter
    ret

// void measure(struct cache_block *base);
// x0: current block to probe
// x5: probe counter
// x6: base cache block backup
// x7: return address backup
measure:
    mov     x7,     x30
    mov     x6,     x0
    mov     x5,     0x0
    bl      __clear_is
    b       .L_measure_loop

.L_measure_iter:
    bl      __next_uint8
    and     x0,     x0,     MASK
    mov     x2,     x0
    b       .L_measure_iter_postrand

.L_measure_iter_inc:
    add     x2,     x2,     0x1
    and     x2,     x2,     MASK
    mov     x0,     x2

.L_measure_iter_postrand:
    add     x0,     x0,     SHIFT
    bl      __get_at_index
    cmp     x0,     0x0
    b.ne    .L_measure_iter_inc

    add     x2,     x2,     SHIFT
    add     x0,     x6,     x2,     LSL 0x6
    mov     x1,     x2
    bl      probe

    mov     x0,     x1
    mov     x1,     0xFF
    bl      __set_at_index

    add     x5,     x5,     0x1
.L_measure_loop:
    cmp     x5,     (MASK + 1)
    b.ne    .L_measure_iter

    mov     x30,    x7
    ret

