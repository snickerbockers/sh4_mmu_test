/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <snickerbockers@washemu.org> wrote this file.  As long as you retain this
 * notice you can do whatever you want with this stuff. If we meet some day,
 * and you think this stuff is worth it, you can buy me a beer in return.
 *
 * snickerbockers
 * ----------------------------------------------------------------------------
 */

#include "sh4_mmu_test.h"

unsigned* testcase_tlb_miss_delay_slot(void);

#define SPG_HBLANK_INT (*(unsigned volatile*)0xa05f80c8)
#define SPG_VBLANK_INT (*(unsigned volatile*)0xa05f80cc)
#define SPG_CONTROL    (*(unsigned volatile*)0xa05f80d0)
#define SPG_HBLANK     (*(unsigned volatile*)0xa05f80d4)
#define SPG_LOAD       (*(unsigned volatile*)0xa05f80d8)
#define SPG_VBLANK     (*(unsigned volatile*)0xa05f80dc)
#define SPG_WIDTH      (*(unsigned volatile*)0xa05f80e0)

#define VO_CONTROL     (*(unsigned volatile*)0xa05f80e8)
#define VO_STARTX      (*(unsigned volatile*)0xa05f80ec)
#define VO_STARTY      (*(unsigned volatile*)0xa05f80f0)

#define FB_R_CTRL      (*(unsigned volatile*)0xa05f8044)
#define FB_R_SOF1      (*(unsigned volatile*)0xa05f8050)
#define FB_R_SOF2      (*(unsigned volatile*)0xa05f8054)
#define FB_R_SIZE      (*(unsigned volatile*)0xa05f805c)

// basic framebuffer parameters
#define LINESTRIDE_PIXELS  640
#define BYTES_PER_PIXEL      2
#define FRAMEBUFFER_WIDTH  640
#define FRAMEBUFFER_HEIGHT 476

// TODO: I want to implement double-buffering and VBLANK interrupts, but I don't have that yet.
#define FRAMEBUFFER_1 ((void volatile*)0xa5200000)
#define FRAMEBUFFER_2 ((void volatile*)0xa5600000)

#define FB_R_SOF1_FRAME1 0x00200000
#define FB_R_SOF2_FRAME1 0x00200500
#define FB_R_SOF1_FRAME2 0x00600000
#define FB_R_SOF2_FRAME2 0x00600500

typedef void*(*state_fn)(void);
static state_fn state;

static void* run_tlb_read_miss_delay_test(void);

void *get_romfont_pointer(void);

int test_single_addr_double(unsigned offs);

/*
 * Performs a write using the store-queues.
 * src must be 8-byte aligned.
 * dst must be 32-byte aligned.
 */
void write_sq(void const *src, void volatile *dst);

static unsigned get_controller_buttons(void);
static int check_controller(void);

static void volatile *cur_framebuffer;

static void configure_video(void) {
    // Hardcoded for 640x476i NTSC video
    SPG_HBLANK_INT = 0x03450000;
    SPG_VBLANK_INT = 0x00150104;
    SPG_CONTROL = 0x00000150;
    SPG_HBLANK = 0x007E0345;
    SPG_LOAD = 0x020C0359;
    SPG_VBLANK = 0x00240204;
    SPG_WIDTH = 0x07d6c63f;
    VO_CONTROL = 0x00160000;
    VO_STARTX = 0x000000a4;
    VO_STARTY = 0x00120012;
    FB_R_CTRL = 0x00000004;
    FB_R_SOF1 = FB_R_SOF1_FRAME1;
    FB_R_SOF2 = FB_R_SOF2_FRAME1;
    FB_R_SIZE = 0x1413b53f;

    cur_framebuffer = FRAMEBUFFER_1;
}

void disable_video(void) {
    FB_R_CTRL &= ~1;
}

void enable_video(void) {
    FB_R_CTRL |= 1;
}

void clear_screen(void volatile* fb, unsigned short color) {
    unsigned color_2pix = ((unsigned)color) | (((unsigned)color) << 16);

    unsigned volatile *row_ptr = (unsigned volatile*)fb;

    unsigned row, col;
    for (row = 0; row < FRAMEBUFFER_HEIGHT; row++)
        for (col = 0; col < (FRAMEBUFFER_WIDTH / 2); col++)
            *row_ptr++ = color_2pix;
}

unsigned short make_color(unsigned red, unsigned green, unsigned blue) {
    if (red > 255)
        red = 255;
    if (green > 255)
        green = 255;
    if (blue > 255)
        blue = 255;

    red >>= 3;
    green >>= 2;
    blue >>= 3;

    return blue | (green << 5) | (red << 11);
}

static void
create_font(unsigned short *font,
            unsigned short foreground, unsigned short background) {
    get_romfont_pointer();
    char const *romfont = get_romfont_pointer();

    unsigned glyph;
    for (glyph = 0; glyph < 288; glyph++) {
        unsigned short *glyph_out = font + glyph * 24 * 12;
        char const *glyph_in = romfont + (12 * 24 / 8) * glyph;

        unsigned row, col;
        for (row = 0; row < 24; row++) {
            for (col = 0; col < 12; col++) {
                unsigned idx = row * 12 + col;
                char const *inp = glyph_in + idx / 8;
                char mask = 0x80 >> (idx % 8);
                unsigned short *outp = glyph_out + idx;
                if (*inp & mask)
                    *outp = foreground;
                else
                    *outp = background;
            }
        }
    }
}

#define MAX_CHARS_X (FRAMEBUFFER_WIDTH / 12)
#define MAX_CHARS_Y (FRAMEBUFFER_HEIGHT / 24)

static void draw_glyph(void volatile *fb, unsigned short const *font,
                       unsigned glyph_no, unsigned x, unsigned y) {
    if (glyph_no > 287)
        glyph_no = 0;
    unsigned short volatile *outp = ((unsigned short volatile*)fb) +
        y * LINESTRIDE_PIXELS + x;
    unsigned short const *glyph = font + glyph_no * 24 * 12;

    unsigned row;
    for (row = 0; row < 24; row++) {
        unsigned col;
        for (col = 0; col < 12; col++) {
            outp[col] = glyph[row * 12 + col];
        }
        outp += LINESTRIDE_PIXELS;
    }
}

static void draw_char(void volatile *fb, unsigned short const *font,
                      char ch, unsigned row, unsigned col) {
    if (row >= MAX_CHARS_Y || col >= MAX_CHARS_X)
        return;

    unsigned x = col * 12;
    unsigned y = row * 24;

    unsigned glyph;
    if (ch >= 33 && ch <= 126)
        glyph = ch - 33 + 1;
    else
        return;

    draw_glyph(fb, font, glyph, x, y);
}

void drawstring(void volatile *fb, unsigned short const *font,
                char const *msg, unsigned row, unsigned col) {
    while (*msg) {
        if (col >= MAX_CHARS_X) {
            col = 0;
            row++;
        }
        if (*msg == '\n') {
            col = 0;
            row++;
            msg++;
            continue;
        }
        draw_char(fb, font, *msg++, row, col++);
    }
}

#define REG_ISTNRM (*(unsigned volatile*)0xA05F6900)

void swap_buffers(void) {
    if (cur_framebuffer == FRAMEBUFFER_1) {
        FB_R_SOF1 = FB_R_SOF1_FRAME2;
        FB_R_SOF2 = FB_R_SOF2_FRAME2;
        cur_framebuffer = FRAMEBUFFER_2;
    } else {
        FB_R_SOF1 = FB_R_SOF1_FRAME1;
        FB_R_SOF2 = FB_R_SOF2_FRAME1;
        cur_framebuffer = FRAMEBUFFER_1;
    }
}

void volatile *get_backbuffer(void) {
    if (cur_framebuffer == FRAMEBUFFER_1)
        return FRAMEBUFFER_2;
    else
        return FRAMEBUFFER_1;
}

static void volatile *get_frontbuffer(void) {
    return cur_framebuffer;
}

int check_vblank(void) {
    int ret = (REG_ISTNRM & (1 << 3)) ? 1 : 0;
    if (ret)
        REG_ISTNRM = (1 << 3);
    return ret;
}

#define REG_MDSTAR (*(unsigned volatile*)0xa05f6c04)
#define REG_MDTSEL (*(unsigned volatile*)0xa05f6c10)
#define REG_MDEN   (*(unsigned volatile*)0xa05f6c14)
#define REG_MDST   (*(unsigned volatile*)0xa05f6c18)
#define REG_MSYS   (*(unsigned volatile*)0xa05f6c80)
#define REG_MDAPRO (*(unsigned volatile*)0xa05f6c8c)
#define REG_MMSEL  (*(unsigned volatile*)0xa05f6ce8)

static void volatile *align32(void volatile *inp) {
    char volatile *as_ch = (char volatile*)inp;
    while (((unsigned)as_ch) & 31)
        as_ch++;
    return (void volatile*)as_ch;
}
#define MAKE_PHYS(addr) ((void*)((((unsigned)addr) & 0x1fffffff) | 0xa0000000))

static void wait_maple(void) {
    while (!(REG_ISTNRM & (1 << 12)))
           ;

    // clear the interrupt
    REG_ISTNRM |= (1 << 12);
}

static int check_controller(void) {
    // clear any pending interrupts (there shouldn't be any but do it anyways)
    REG_ISTNRM |= (1 << 12);

    // disable maple DMA
    REG_MDEN = 0;

    // make sure nothing else is going on
    while (REG_MDST)
        ;

    // 2mpbs transfer, timeout after 1ms
    REG_MSYS = 0xc3500000;

    // trigger via CPU (as opposed to vblank)
    REG_MDTSEL = 0;

    // let it write wherever it wants, i'm not too worried about rogue DMA xfers
    REG_MDAPRO = 0x6155407f;

    // construct packet
    static char volatile devinfo0[1024];
    static unsigned volatile frame[36 + 31];

    unsigned volatile *framep = (unsigned*)MAKE_PHYS(align32(frame));
    char volatile *devinfo0p = (char*)MAKE_PHYS(align32(devinfo0));

    framep[0] = 0x80000000;
    framep[1] = ((unsigned)devinfo0p) & 0x1fffffff;
    framep[2] = 0x2001;

    // set SB_MDSTAR to the address of the packet
    REG_MDSTAR = ((unsigned)framep) & 0x1fffffff;

    // enable maple DMA
    REG_MDEN = 1;

    // begin the transfer
    REG_MDST = 1;

    wait_maple();

    // transfer is now complete, receive data
    if (devinfo0p[0] == 0xff || devinfo0p[4] != 0 || devinfo0p[5] != 0 ||
        devinfo0p[6] != 0 || devinfo0p[7] != 1)
        return 0;

    char const *expect = "Dreamcast Controller         ";
    char const volatile *devname = devinfo0p + 22;

    while (*expect)
        if (*devname++ != *expect++)
            return 0;
    return 1;
}

static unsigned controller_btns_prev, controller_btns;

static unsigned get_controller_buttons(void) {
    if (!check_controller())
        return ~0;

    // clear any pending interrupts (there shouldn't be any but do it anyways)
    REG_ISTNRM |= (1 << 12);

    // disable maple DMA
    REG_MDEN = 0;

    // make sure nothing else is going on
    while (REG_MDST)
        ;

    // 2mpbs transfer, timeout after 1ms
    REG_MSYS = 0xc3500000;

    // trigger via CPU (as opposed to vblank)
    REG_MDTSEL = 0;

    // let it write wherever it wants, i'm not too worried about rogue DMA xfers
    REG_MDAPRO = 0x6155407f;

    // construct packet
    static char unsigned volatile cond[1024];
    static unsigned volatile frame[36 + 31];

    unsigned volatile *framep = (unsigned*)MAKE_PHYS(align32(frame));
    char unsigned volatile *condp = (char unsigned*)MAKE_PHYS(align32(cond));

    framep[0] = 0x80000001;
    framep[1] = ((unsigned)condp) & 0x1fffffff;
    framep[2] = 0x01002009;
    framep[3] = 0x01000000;

    // set SB_MDSTAR to the address of the packet
    REG_MDSTAR = ((unsigned)framep) & 0x1fffffff;

    // enable maple DMA
    REG_MDEN = 1;

    // begin the transfer
    REG_MDST = 1;

    wait_maple();

    // transfer is now complete, receive data
    return ((unsigned)condp[8]) | (((unsigned)condp[9]) << 8);
}

void update_controller(void) {
    controller_btns_prev = controller_btns;
    controller_btns = ~get_controller_buttons();
}

int check_btn(int btn_no) {
    int changed_btns = controller_btns_prev ^ controller_btns;

    if ((btn_no & changed_btns) && (btn_no & controller_btns))
        return 1;
    else
        return 0;
}

#define N_CHAR_ROWS MAX_CHARS_Y
#define N_CHAR_COLS MAX_CHARS_X

char const *hexstr(unsigned val) {
    static char txt[8];
    unsigned nib_no;
    for (nib_no = 0; nib_no < 8; nib_no++) {
        unsigned shift_amt = (7 - nib_no) * 4;
        unsigned nibble = (val >> shift_amt) & 0xf;
        switch (nibble) {
        case 0:
            txt[nib_no] = '0';
            break;
        case 1:
            txt[nib_no] = '1';
            break;
        case 2:
            txt[nib_no] = '2';
            break;
        case 3:
            txt[nib_no] = '3';
            break;
        case 4:
            txt[nib_no] = '4';
            break;
        case 5:
            txt[nib_no] = '5';
            break;
        case 6:
            txt[nib_no] = '6';
            break;
        case 7:
            txt[nib_no] = '7';
            break;
        case 8:
            txt[nib_no] = '8';
            break;
        case 9:
            txt[nib_no] = '9';
            break;
        case 10:
            txt[nib_no] = 'A';
            break;
        case 11:
            txt[nib_no] = 'B';
            break;
        case 12:
            txt[nib_no] = 'C';
            break;
        case 13:
            txt[nib_no] = 'D';
            break;
        case 14:
            txt[nib_no] = 'E';
            break;
        default:
            txt[nib_no] = 'F';
            break;
        }
    }
    txt[8] = '\0';
    return txt;
}

static char const *hexstr_no_leading_0(unsigned val) {
    char const *retstr = hexstr(val);
    while (*retstr == '0')
        retstr++;
    if (!*retstr)
        retstr--;
    return retstr;
}

unsigned short fonts[N_FONTS][288 * 24 * 12];

/*
TRANSLATE 32 BIT AREA to 64 BIT
if (addr32 > HALFWAY_POINT)
    return (addr32 - HALFWAY_POINT) * 2 + 4
else
    return addr32 * 2

TRANSLATE 64 BIT AREA to 32 BIT
if (addr32 % 8)
    return ((addr - 4) / 2) + HALFWAY_POINT
else
    return addr / 2
*/

#define PVR2_TEX_MEM_BANK_SIZE (4 << 20)
#define PVR2_TOTAL_VRAM_SIZE (8 << 20)

static int disp_results(void) {
    for (;;) {
        void volatile *fb = get_backbuffer();
        clear_screen(fb, make_color(0, 0, 0));
        drawstring(fb, fonts[4], "*****************************************************", 0, 0);
        drawstring(fb, fonts[4], "*                                                   *", 1, 0);
        drawstring(fb, fonts[4], "*                   SH4 MMU TEST                    *", 2, 0);
        drawstring(fb, fonts[4], "*                   RESULT SCREEN                   *", 3, 0);
        drawstring(fb, fonts[4], "*                                                   *", 4, 0);
        drawstring(fb, fonts[4], "*****************************************************", 5, 0);

        /* drawstring(fb, fonts[4], "     SH4 VRAM 32-BIT", 7, 0); */
        /* if (sh4_vram_test_results.test_results_32 == 0) { */
        /*     drawstring(fb, fonts[1], "SUCCESS", 7, 21); */
        /* } else { */
        /*     drawstring(fb, fonts[2], "FAILURE - ", 7, 21); */
        /*     drawstring(fb, fonts[2], */
        /*                hexstr(sh4_vram_test_results.test_results_32), 7, 31); */
        /* } */

        /* drawstring(fb, fonts[4], "     SH4 VRAM 16-BIT", 8, 0); */
        /* if (sh4_vram_test_results.test_results_16 == 0) { */
        /*     drawstring(fb, fonts[1], "SUCCESS", 8, 21); */
        /* } else { */
        /*     drawstring(fb, fonts[2], "FAILURE - ", 8, 21); */
        /*     drawstring(fb, fonts[2], */
        /*                hexstr(sh4_vram_test_results.test_results_32), 7, 31); */
        /* } */

        /* drawstring(fb, fonts[4], "     SH4 VRAM 8-BIT", 9, 0); */
        /* if (sh4_vram_test_results.test_results_8 == 0) { */
        /*     drawstring(fb, fonts[1], "SUCCESS", 9, 21); */
        /* } else { */
        /*     drawstring(fb, fonts[2], "FAILURE - ", 9, 21); */
        /*     drawstring(fb, fonts[2], */
        /*                hexstr(sh4_vram_test_results.test_results_32), 7, 31); */
        /* } */

        /* drawstring(fb, fonts[4], "     SH4 VRAM FLOAT", 10, 0); */
        /* if (sh4_vram_test_results.test_results_float == 0) { */
        /*     drawstring(fb, fonts[1], "SUCCESS", 10, 21); */
        /* } else { */
        /*     drawstring(fb, fonts[2], "FAILURE - ", 10, 21); */
        /*     drawstring(fb, fonts[2], */
        /*                hexstr(sh4_vram_test_results.test_results_32), 7, 31); */
        /* } */

        /* drawstring(fb, fonts[4], "     SH4 VRAM DOUBLE", 11, 0); */
        /* if (sh4_vram_test_results.test_results_double == 0) { */
        /*     drawstring(fb, fonts[1], "SUCCESS", 11, 21); */
        /* } else { */
        /*     drawstring(fb, fonts[2], "FAILURE - ", 11, 21); */
        /*     drawstring(fb, fonts[2], */
        /*                hexstr(sh4_vram_test_results.test_results_32), 7, 31); */
        /* } */

        /* drawstring(fb, fonts[4], "     SH4 VRAM SQ", 12, 0); */
        /* if (sh4_vram_test_results.test_results_sq == 0) { */
        /*     drawstring(fb, fonts[1], "SUCCESS", 12, 21); */
        /* } else { */
        /*     drawstring(fb, fonts[2], "FAILURE - ", 12, 21); */
        /*     drawstring(fb, fonts[2], */
        /*                hexstr(sh4_vram_test_results.test_results_32), 7, 31); */
        /* } */

        while (!check_vblank())
            ;
        swap_buffers();
        update_controller();

        if (check_btn(1 << 2)) // a button
            return STATE_MENU;
    }
}

#ifndef NULL
#define NULL ((void*)0x0)
#endif

static struct menu_entry {
    char const *txt;
    state_fn fn;
} const menu_entries[] = {
    { "READ MISS IN DELAY SLOT", run_tlb_read_miss_delay_test },
    /* { "SH4 VRAM TEST (FAST)", STATE_SH4_VRAM_TEST_FAST }, */
    /* { "SH4 VRAM TEST (SLOW)", STATE_SH4_VRAM_TEST_SLOW }, */
    /* { "DMA TEST (64-BIT)", STATE_DMA_TEST_64BIT }, */
    /* { "DMA TEST (32-BIT)", STATE_DMA_TEST_32BIT }, */
    /* { "DMA TEST (YUV 420 SINGLE TEX)", STATE_DMA_TEST_YUV }, */

    { NULL }
};

static void* main_menu(void) {
    int menupos = 0;

    enable_video();
    clear_screen(get_backbuffer(), make_color(0, 0, 0));

    int curs = 0;

    while (!check_vblank())
        ;
    controller_btns_prev = ~get_controller_buttons();

    for (;;) {
        void volatile *fb = get_backbuffer();
        clear_screen(fb, make_color(0, 0, 0));
        drawstring(fb, fonts[4], "*****************************************************", 0, 0);
        drawstring(fb, fonts[4], "*                                                   *", 1, 0);
        drawstring(fb, fonts[4], "*               Dreamcast SH4 MMU Test              *", 2, 0);
        drawstring(fb, fonts[4], "*                snickerbockers 2020                *", 3, 0);
        drawstring(fb, fonts[4], "*                                                   *", 4, 0);
        drawstring(fb, fonts[4], "*****************************************************", 5, 0);

        unsigned row = 7;
        unsigned n_ents = 0;
        struct menu_entry const *cur_ent = menu_entries;
        while (cur_ent->txt) {
            drawstring(fb, fonts[4], cur_ent->txt, row++, 9);
            cur_ent++;
            n_ents++;
        }

        drawstring(fb, fonts[4], " ======>", curs + 7, 0);

        while (!check_vblank())
            ;
        swap_buffers();

        update_controller();

        if (n_ents) {
            if (check_btn(1 << 5)) {
                // d-pad down
                if (curs < (n_ents-1))
                    curs++;
            }

            if (check_btn(1 << 4)) {
                // d-pad up
                if (curs > 0)
                    curs--;
            }

            // a button
            if (check_btn(1 << 2)) {
                cur_ent = menu_entries;
                while (curs) {
                    curs--;
                    cur_ent++;
                }

                return cur_ent->fn;
            }
        }
    }
}

static void* run_tlb_read_miss_delay_test(void) {

    unsigned *res = testcase_tlb_miss_delay_slot( );

    for (;;) {
        void volatile *fb = get_backbuffer();
        clear_screen(fb, make_color(0, 0, 0));

        drawstring(fb, fonts[4], "     THE TEST", 7, 0);
        /* if (res == 0) { */
        drawstring(fb, fonts[1], "SUCCESS - ", 7, 21);
        drawstring(fb, fonts[1], hexstr(*res), 7, 31);
        /* } else { */
            /* drawstring(fb, fonts[2], "FAILURE", 7, 21); */
        /* } */

        while (!check_vblank())
            ;
        swap_buffers();
        update_controller();

        if (check_btn(1 << 2)) // a button
            break;
    }

    return main_menu;
}

/*
 * our entry point (after _start).
 *
 * I had to call this dcmain because the linker kept wanting to put main at the
 * entry instead of _start, and this was the only thing I tried that actually
 * fixed it.
 */
int dcmain(int argc, char **argv) {
    /*
     * The reason why these big arrays are static is to save on stack space.
     * We only have 4KB!
     */
    /* static char txt_buf[N_CHAR_ROWS][N_CHAR_COLS]; */
    /* static int txt_colors[N_CHAR_ROWS][N_CHAR_COLS]; */

    configure_video();

    create_font(fonts[0], make_color(0, 0, 0), make_color(0, 0, 0));
    create_font(fonts[1], make_color(0, 197, 0), make_color(0, 0, 0));
    create_font(fonts[2], make_color(197, 0, 9), make_color(0, 0, 0));
    create_font(fonts[3], make_color(255, 255, 255), make_color(0, 0, 0));
    create_font(fonts[4], make_color(197, 197, 230), make_color(0, 0, 0));
    create_font(fonts[5], make_color(255, 131, 24), make_color(0, 0, 0));

    state = main_menu;

    for (;;) {
        state = state();
        /* switch (state) { */
        /* case STATE_DELAY_SLOT_READ_MISS: */
            
            /* case STATE_SH4_VRAM_TEST_SLOW: */
        /*     state = run_sh4_vram_slow_test(); */
        /*     break; */
        /* case STATE_SH4_VRAM_TEST_FAST: */
        /*     state = run_sh4_vram_fast_test(); */
        /*     break; */
        /* case STATE_SH4_VRAM_TEST_RESULTS: */
        /*     state = disp_results(); */
        /*     break; */
        /* case STATE_DMA_TEST_32BIT: */
        /*     state = run_dma_tests(1); */
        /*     break; */
        /* case STATE_DMA_TEST_64BIT: */
        /*     state = run_dma_tests(0); */
        /*     break; */
        /* case STATE_DMA_TEST_YUV: */
        /*     state = run_yuv_dma_tests(); */
        /*     break; */
        /* case STATE_DMA_TEST_RESULTS: */
        /*     state = show_dma_test_results(); */
        /*     break; */
        /* case STATE_DMA_TEST_YUV_RESULTS: */
        /*     state = show_dma_test_yuv_results(); */
        /*     break; */
        /* default: */
        /* case STATE_MENU: */
        /*     state = main_menu(); */
        /*     break; */
        /* } */
    }

    return 0;
}
