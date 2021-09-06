#include "print.h"

// Constants defining the layout of the video memory
const static size_t NUM_COLS = 80;
const static size_t NUM_ROWS = 25;

// Printing works by video memory holding an array of characters
struct Char {
    uint8_t character;  // ASCII character itself
    uint8_t colour;  // 8-bit colour code
};

struct Char* buffer = (struct Char*) 0xb8000;  // Buffer variable which is a reference to the video memory
size_t col = 0;  // Track current column and row numbers we are printing at
size_t row = 0;
uint8_t colour = PRINT_COLOUR_WHITE | PRINT_COLOUR_BLACK << 4;  // Keep track of the current colour when printing

void clear_row(size_t row) {
    // Print an empty space character
    struct Char empty = (struct Char) {
        character: ' ',
        colour: colour,
    };

    for (size_t col = 0; col < NUM_COLS; col++) {  // For each column in thie row, print the empty space character
        buffer[col + NUM_COLS * row] = empty;
    }
}

void print_clear() {
    for (size_t i = 0; i < NUM_ROWS; i++) {
        clear_row(i);
    }
}

void print_newline() {
    col = 0;

    if (row < NUM_ROWS - 1) {  // Check if we're not at the last row
        row++;
        return;
    }

    // If we're on the last row, we have to scroll all the text up so that we have space for a new row
    for (size_t row = 1; row < NUM_ROWS; row++) {  // Loop through from the second row onwards, as the first row will be cut off the screen
        for (size_t col = 0; col < NUM_COLS; col++) {  // Iterate over all the columns
            struct Char character = buffer[col + NUM_COLS * row];  // Get the character at this row and column
            buffer[col + NUM_COLS * (row - 1)] = character;  // Move this character up by one row
        }
    }
    // When we move last row up, we have to clear that row before we can do any printing on it
    clear_row(NUM_COLS - 1);
}

void print_char(char character) {
    if (character == '\n') {
        print_newline();
        return;
    }

    if (col > NUM_COLS) {  // If the column number exceeds the total number of columns in a row, we need to print a new line
        print_newline();
    }

    buffer[col + NUM_COLS * row] = (struct Char) {
        character: (uint8_t) character,  // Downcast character to 8 bits
        colour: colour,
    };

    col++;
}

void print_str(char* str){
    for (size_t i = 0; 1; i++) {
        char character = (uint8_t) str[i];

        if (character == '\0') {
            return;
        }

        print_char(character);
    }
}

void print_set_colour(uint8_t foreground, uint8_t background) {
    // Foreground colour will take the first 4 bits and we'll bit shift the background colour by 4 bits so it takes up the other 4 bits
    colour = foreground + (background << 4);
}
