#define MINIMP3_IMPLEMENTATION
#define MINIMP3_ALLOW_MONO_STEREO_TRANSITION
#define MINIMP3_NO_STDIO
#include "minimp3/minimp3.h"

extern "C" int mp3dec_version(void) {
    return 0x1010;
}