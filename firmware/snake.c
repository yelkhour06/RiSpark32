/* ============================================================
   Moving Snake – bare-metal console
   UART TX register : 0x10000000  (write one byte at a time)
   No standard library.

   Hardware flush note:
     The hardware renderer triggers on 0x0A (LF / '\n').
     Every logical output line therefore ends with '\n' so the
     HW flushes its internal buffer and actually draws the cell.
   ============================================================ */

/* ---------- UART primitive ---------- */
#define UART_BASE 0x10000000UL
//#define DELAY_IRQ 1

static volatile unsigned int *const uart = (volatile unsigned int *)UART_BASE;

/*
 * Write one character.
 * '\n' (0x0A) is expanded to '\r\n' so the cursor also returns to
 * column 1 on real UART terminals, and so the HW flush is triggered.
 */
static void uart_putc(char c)
{
    if (c == '\n') {
        *uart = '\r';   /* 0x0D – carriage return */
    }
    *uart = (unsigned int)(unsigned char)c;   /* 0x0A triggers HW flush */
}

/* Write a null-terminated string */
static void uart_puts(const char *s)
{
    while (*s) uart_putc(*s++);
}

/* Write a decimal integer (unsigned) */
static void uart_putu(unsigned int n)
{
    char buf[12];
    int  i = 0;
    if (n == 0) { uart_putc('0'); return; }
    while (n) { buf[i++] = '0' + (n % 10); n /= 10; }
    while (i--) uart_putc(buf[i]);
}

/* ============================================================
   ANSI / VT100 helpers
   Every helper ends with '\n' (0x0A) so the hardware flushes
   its render buffer after each control + content sequence.
   ============================================================ */

/* Clear screen + cursor home, then flush */
static void screen_clear(void)
{
    uart_puts("\033[2J\033[H\n");
}

/*
 * Move cursor to (r, c) – 1-based – then flush.
 * Callers write their cell content AFTER this call and append '\n'
 * themselves so the content + position land in the same flush.
 */
static void cursor_goto(int r, int c)
{
    uart_puts("\033[");
    uart_putu((unsigned int)r);
    uart_putc(';');
    uart_putu((unsigned int)c);
    uart_putc('H');
    /* NOTE: caller must write content then '\n' to flush */
}

/* Hide cursor */
static void cursor_hide(void) { uart_puts("\033[?25l\n"); }
/* Show cursor */
static void cursor_show(void) { uart_puts("\033[?25h\n"); }

/* ============================================================
   Convenience: goto + single character + flush
   This is the most common drawing primitive in the game.
   ============================================================ */
static void draw_char(int r, int c, char ch)
{
    cursor_goto(r, c);
    uart_putc(ch);
    uart_putc('\n');   /* 0x0A  → HW flush */
}

/* ============================================================
   Game parameters
   ============================================================ */
#define ROWS    20
#define COLS    40
#define MAX_LEN (ROWS * COLS)

/* Directions */
#define DIR_UP    0
#define DIR_DOWN  1
#define DIR_LEFT  2
#define DIR_RIGHT 3

/* ============================================================
   Snake state
   ============================================================ */
typedef struct { int r; int c; } Point;

static Point  body[MAX_LEN];   /* body[0] = head */
static int    length;
static int    dir;
static Point  food;
static int    score;

/* ============================================================
   Tiny pseudo-random (LCG)
   ============================================================ */
static unsigned int rng_state = 12345;

static unsigned int rand_next(void)
{
    rng_state = rng_state * 1664525u + 1013904223u;
    return rng_state;
}

/* ============================================================
   Food placement
   ============================================================ */
static void place_food(void)
{
    int i, ok;
    do {
        food.r = (int)((rand_next() % (ROWS - 2)) + 1);
        food.c = (int)((rand_next() % (COLS - 2)) + 1);
        ok = 1;
        for (i = 0; i < length; i++)
            if (body[i].r == food.r && body[i].c == food.c) { ok = 0; break; }
    } while (!ok);
}

/* ============================================================
   Snake initialisation
   ============================================================ */
static void snake_init(void)
{
    int i;
    length = 4;
    dir    = DIR_RIGHT;
    score  = 0;

    int r = ROWS / 2;
    int c = COLS / 2;
    for (i = 0; i < length; i++) {
        body[i].r = r;
        body[i].c = c - i;
    }
    place_food();
}

/* ============================================================
   Drawing helpers
   All use draw_char() which appends '\n' → HW flush per cell.
   ============================================================ */

/* Border is drawn once at game start (or restart). */
static void draw_border(void)
{
    int i;

    /* Top row */
    for (i = 1; i <= COLS; i++)
        draw_char(1, i, '#');

    /* Bottom row */
    for (i = 1; i <= COLS; i++)
        draw_char(ROWS, i, '#');

    /* Side walls */
    for (i = 2; i < ROWS; i++) {
        draw_char(i, 1,    '#');
        draw_char(i, COLS, '#');
    }
}

/* +1 offsets: row 1 and col 1 are the border. */
static void erase_cell(int r, int c) { draw_char(r + 1, c + 1, ' '); }
static void draw_head (int r, int c) { draw_char(r + 1, c + 1, '@'); }
static void draw_body (int r, int c) { draw_char(r + 1, c + 1, 'o'); }
static void draw_food (void)         { draw_char(food.r + 1, food.c + 1, 'A'); }

/* Score line sits one row below the border. */
static void draw_score(void)
{
    cursor_goto(ROWS + 1, 1);
    uart_puts("Score: ");
    uart_putu((unsigned int)score);
    uart_puts("   ");   /* overwrite old digits */
    uart_putc('\n');    /* 0x0A → HW flush */
}

/* Full first-frame render */
static void draw_all(void)
{
    int i;
    screen_clear();
    draw_border();
    for (i = 0; i < length; i++) {
        draw_char(body[i].r + 1, body[i].c + 1, i == 0 ? '@' : 'o');
    }
    draw_food();
    draw_score();
}

/* ============================================================
   Auto-pilot: greedy steer toward food
   ============================================================ */
static void auto_steer(void)
{
    int dr = food.r - body[0].r;
    int dc = food.c - body[0].c;

    int pref[4], n = 0;

    if (dr < 0 && dir != DIR_DOWN)  pref[n++] = DIR_UP;
    if (dr > 0 && dir != DIR_UP)    pref[n++] = DIR_DOWN;
    if (dc < 0 && dir != DIR_RIGHT) pref[n++] = DIR_LEFT;
    if (dc > 0 && dir != DIR_LEFT)  pref[n++] = DIR_RIGHT;

    if (n == 0) pref[n++] = dir;   /* keep going */
    dir = pref[0];
}

/* ============================================================
   One game step.  Returns 0 on collision, 1 otherwise.
   Only redraws the two cells that changed (no full clear).
   ============================================================ */
static int game_step(void)
{
    auto_steer();

    /* New head position */
    Point nh = body[0];
    if      (dir == DIR_UP)    nh.r--;
    else if (dir == DIR_DOWN)  nh.r++;
    else if (dir == DIR_LEFT)  nh.c--;
    else                       nh.c++;

    /* Wall collision */
    if (nh.r <= 0 || nh.r >= ROWS - 1 ||
        nh.c <= 0 || nh.c >= COLS - 1)
        return 0;

    /* Self collision */
    int i;
    for (i = 0; i < length - 1; i++)
        if (body[i].r == nh.r && body[i].c == nh.c) return 0;

    int ate = (nh.r == food.r && nh.c == food.c);

    /* Erase old tail before shifting (only when not growing) */
    Point old_tail = body[length - 1];
    if (!ate) erase_cell(old_tail.r, old_tail.c);   /* ' ' + '\n' flush */

    /* Shift body */
    if (ate && length < MAX_LEN) length++;
    for (i = length - 1; i > 0; i--) body[i] = body[i - 1];
    body[0] = nh;

    /* Redraw only the two changed cells, each ending with '\n' */
    draw_body(body[1].r, body[1].c);   /* old head → body  + flush */
    draw_head(body[0].r, body[0].c);   /* new head         + flush */

    if (ate) {
        score++;
        place_food();
        draw_food();    /* food cell  + flush */
        draw_score();   /* score line + flush */
    }

    return 1;
}

/* ============================================================
   Delay  –  volatile counter + compiler barrier so the loop
   is never optimised away.
   Tune DELAY_TICKS to your clock speed:
     25 MHz →  250 000   ≈ 10 ms / step
     50 MHz →  500 000   ≈ 10 ms / step
    100 MHz → 1 000 000  ≈ 10 ms / step
   ============================================================ */
#define DELAY_TICKS 300UL

static void delay(void)
{	
    #ifdef DELAY_IRQ	
    unsigned int readGP0 = 1;
    __asm__ volatile ("csrrwi zero, 0xC, 0x1");
    while (readGP0 == 1) {       
    	__asm__ volatile ("csrrs %0, 0xC, zero" : "=r"(readGP0));
	//uart_puts("readGP0: ");        
	//uart_putu((unsigned int)readGP0);
	//uart_putc('\n');
    }
    #else
    volatile unsigned long t = DELAY_TICKS;
    while (t--)
        __asm__ volatile ("" ::: "memory");
    #endif
}

/* ============================================================
   Entry point
   ============================================================ */
int main(void)
{
    cursor_hide();      /* ends with '\n' → flushed */
    snake_init();
    draw_all();         /* each cell ends with '\n' → flushed */

    while (1)
    {
        delay();

        if (!game_step())
        {
            /* Game over message – each line ends with '\n' */
            cursor_goto(ROWS / 2 + 1, COLS / 4);
            uart_puts("*** GAME OVER ***  Score: ");
            uart_putu((unsigned int)score);
            uart_putc('\n');                        /* flush */

            cursor_goto(ROWS / 2 + 2, COLS / 4);
            uart_puts("Restarting...\n");           /* flush */

            delay();

            snake_init();
            draw_all();
        }
    }

    cursor_show();
    return 0;
}
