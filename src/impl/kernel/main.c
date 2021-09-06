#include "print.h"

void kernel_main() {
    print_clear();
    print_set_colour(PRINT_COLOUR_YELLOW, PRINT_COLOUR_BLACK);
    print_str("Welcome to the 64 bit kernel!");
}