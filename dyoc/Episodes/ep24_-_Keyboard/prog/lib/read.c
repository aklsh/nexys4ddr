#include <stdint.h>     // uint8_t, etc.
#include <conio.h>      // cgetc()

// This is just a very simple implementation of the read() function.

// For now, we just ignore the file descriptor fd.
int read (int fd, uint8_t* buf, const unsigned count)
{
   unsigned cnt = count;
   (void) fd;                // Hack to avoid warning about unused variable.

   while (cnt--)
   {
      *buf = cgetc();
      buf++;
   }
   
   return count;
} // end of read

