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

enum {
    STATE_MENU,
    STATE_DELAY_SLOT_READ_MISS
};

int run_dma_tests(unsigned which_bus);
int run_yuv_dma_tests(void);

int show_dma_test_results(void);
int show_dma_test_yuv_results(void);

void drawstring(void volatile *fb, unsigned short const *font,
                char const *msg, unsigned row, unsigned col);

void clear_screen(void volatile* fb, unsigned short color);
unsigned short make_color(unsigned red, unsigned green, unsigned blue);
void volatile *get_backbuffer(void);
char const *hexstr(unsigned val);

void update_controller(void);
int check_btn(int btn_no);

#define N_FONTS 6
extern unsigned short fonts[N_FONTS][288 * 24 * 12];

void swap_buffers(void);

int check_vblank(void);

void disable_video(void);

void enable_video(void);
