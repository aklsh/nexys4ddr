#include <stdint.h>     // uint8_t, etc.
#include <string.h>     // memmove
#include "memorymap.h"  // MEM_CHAR

// This is just a very simple implementation of the write() function.
// The only control character it supports is newline.

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
static uint8_t pos_x = 0;
static uint8_t pos_y = 0;

void gotoxy(uint8_t x, uint8_t y)
{
   pos_x = x;
   pos_y = y;
} // end of gotoxy

void newline(void)
{
   pos_y++;

   // End of screen, so scroll.
   if (pos_y >= V_CHARS)
   {
      // Move screen up one line
      memmove(MEM_CHAR, MEM_CHAR+H_CHARS, H_CHARS*(V_CHARS-1));

      // Clean bottom line
      memset(MEM_CHAR+H_CHARS*(V_CHARS-1), ' ', H_CHARS);

      pos_y = V_CHARS-1;
   }
} // end of newline

void cputc(char ch)
{
   switch (ch)
   {
      case '\n' :
         pos_x = 0;
         pos_y++;
         break;

      default :
         MEM_CHAR[H_CHARS*pos_y+pos_x] = ch;
         pos_x++;
   } // end of switch

   // End of line, just start at next line
   if (pos_x >= H_CHARS)
   {
      pos_x = 0;
      newline();
   }

} // end of cputc

void cputcxy(uint8_t x, uint8_t y, char ch)
{
   gotoxy(x, y);
   cputc(ch);
} // end of cputcxy

// For now, we just ignore the file descriptor fd.
int write (int fd, const uint8_t* buf, const unsigned count)
{
   unsigned cnt = count;
   (void) fd;                // Hack to avoid warning about unused variable.

   while (cnt--)
   {
      cputc(*buf);
      buf++;
   }

   return count;
} // end of write

