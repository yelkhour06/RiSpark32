/*
 * coremark_short.c
 *
 * Compact CoreMark-like benchmark for bare metal targets.
 * - No C standard library usage
 * - UART output by writing characters to 0x10000000
 * - Uses simple linked-list, matrix, and state-machine style kernels
 *
 * NOTE: This is NOT official CoreMark and results must not be reported as
 * CoreMark scores. It is only a lightweight proxy workload.
 */

#define UART_TX_ADDR 0x10000000u
#define SEED         0x3415u
#define LIST_NODES   64u
#define MAT_N        12u
#define ITERATIONS   10u
#define GLOB_ITER    10u

typedef unsigned int  u32;
typedef signed int    s32;
typedef unsigned char u8;

volatile u32 g_sink = 0u;

static inline void uart_putc(char c)
{
    *(volatile u32 *)UART_TX_ADDR = (u32)(u8)c;
}

static void uart_puts(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}

static void uart_nl(void)
{
    uart_putc('\r');
    uart_putc('\n');
}

static void uart_put_u32(u32 v)
{
    char buf[10];
    u32 i = 0u;

    if (v == 0u) {
        uart_putc('0');
        return;
    }

    while (v > 0u) {
        buf[i++] = (char)('0' + (v % 10u));
        v /= 10u;
    }

    while (i > 0u) {
        uart_putc(buf[--i]);
    }
}

static inline u32 read_cycle(void)
{
    u32 c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}

static u32 crc32_step(u32 crc, u32 data)
{
    u32 i;
    crc ^= data;
    for (i = 0u; i < 8u; i++) {
        if (crc & 1u) {
            crc = (crc >> 1) ^ 0xEDB88320u;
        } else {
            crc >>= 1;
        }
    }
    return crc;
}

/* ---------- Kernel 1: linked-list style processing ---------- */

typedef struct Node {
    s32 value;
    u32 next;
} Node;

static Node g_nodes[LIST_NODES];

static u32 kernel_list(u32 seed)
{
    u32 i;
    u32 head = 0u;
    u32 acc = seed;

    for (i = 0u; i < LIST_NODES; i++) {
        g_nodes[i].value = (s32)((seed * (i + 3u)) ^ (i * 17u));
        g_nodes[i].next = (i + 1u) % LIST_NODES;
    }

    for (i = 0u; i < LIST_NODES; i++) {
        u32 j = (seed + i * 11u) % LIST_NODES;
        u32 k = (seed + i * 7u + 3u) % LIST_NODES;
        u32 t = g_nodes[j].next;
        g_nodes[j].next = g_nodes[k].next;
        g_nodes[k].next = t;
    }

    for (i = 0u; i < LIST_NODES * 4u; i++) {
        s32 v = g_nodes[head].value;
        if ((v & 1) != 0) {
            acc ^= (u32)(v << 1);
        } else {
            acc += (u32)(v >> 1);
        }
        head = g_nodes[head].next;
    }

    return acc;
}

/* ---------- Kernel 2: small matrix style processing ---------- */

static s32 A[MAT_N][MAT_N];
static s32 B[MAT_N][MAT_N];
static s32 C[MAT_N][MAT_N];

static u32 kernel_matrix(u32 seed)
{
    u32 i, j, k;
    u32 crc = seed;

    for (i = 0u; i < MAT_N; i++) {
        for (j = 0u; j < MAT_N; j++) {
            A[i][j] = (s32)((i * 13u + j * 7u + seed) & 0x7F);
            B[i][j] = (s32)((i * 5u + j * 11u + 3u) & 0x3F);
            C[i][j] = 0;
        }
    }

    for (i = 0u; i < MAT_N; i++) {
        for (j = 0u; j < MAT_N; j++) {
            s32 sum = 0;
            for (k = 0u; k < MAT_N; k++) {
                sum += A[i][k] * B[k][j];
            }
            C[i][j] = sum;
            crc = crc32_step(crc, (u32)sum);
        }
    }

    return crc;
}

/* ---------- Kernel 3: simple state-machine style parser ---------- */

static const char g_stream[] =
    "12,-7,300;xx;45,+9,-10;0;abc;512,-1;";

static u32 kernel_state(u32 seed)
{
    u32 i = 0u;
    u32 crc = seed;
    u32 state = 0u; /* 0=idle,1=sign,2=number */
    s32 sign = 1;
    s32 value = 0;

    while (g_stream[i] != '\0') {
        char c = g_stream[i++];

        if (state == 0u) {
            if (c == '+') {
                sign = 1;
                value = 0;
                state = 2u;
            } else if (c == '-') {
                sign = -1;
                value = 0;
                state = 2u;
            } else if (c >= '0' && c <= '9') {
                sign = 1;
                value = (s32)(c - '0');
                state = 2u;
            }
        } else {
            if (c >= '0' && c <= '9') {
                value = value * 10 + (s32)(c - '0');
            } else {
                s32 out = sign * value;
                crc = crc32_step(crc, (u32)out);
                state = 0u;
            }
        }
    }

    if (state == 2u) {
        s32 out = sign * value;
        crc = crc32_step(crc, (u32)out);
    }

    return crc;
}

static u32 run_short_bench(u32 iters, u32 iters_start, u32 seed)
{
    u32 i;
    u32 crc = 0u;

    for (i = 0u; i < iters; i++) {
        uart_puts("Iteration=");
	uart_put_u32(i+iters_start*iters);
	uart_nl();
        crc ^= kernel_list(seed + i);
        crc ^= kernel_matrix(seed ^ (i * 3u));
        crc ^= kernel_state(seed + i * 5u);
        crc = crc32_step(crc, i + 1u);
    }

    g_sink ^= crc;
    return crc;
}

int main(void)
{
    u32 t0, t1, dt;
    u32 crc;

    uart_nl();
    uart_puts("coremark-short (non-official)");
    uart_nl();

    uart_puts("iterations=");
    uart_put_u32(ITERATIONS);
    uart_nl();

    for (int i = 0u; i < GLOB_ITER; i++) {
    	
        t0 = read_cycle();
        crc = run_short_bench(ITERATIONS, i, SEED + i);
        t1 = read_cycle();
        dt = t1 - t0;

        uart_puts("cycles=");
        uart_put_u32(dt);
        uart_nl();

        uart_puts("crc=");
        uart_put_u32(crc);
        uart_nl();

    }

    return 0;
}
