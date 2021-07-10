CC = aarch64-corellium-linux-gnu-gcc
CC_FLAGS = -march=armv8-a+crypto -O3
LD_FLAGS = -lcrypto -lm -lpthread

aes_prime_probe: main.c asm.S random.S
	$(CC) $(CC_FLAGS) -o $@ $^ $(LD_FLAGS)

clean:
	rm aes_prime_probe
