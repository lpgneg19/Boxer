//
//  celt.c
//  opus_boxer
//
//  Created by C.W. Betts on 10/14/23.
//

#ifdef __x86_64__
#include "celt/x86/celt_lpc_sse4_1.c"
#include "celt/x86/pitch_sse4_1.c"
#include "celt/x86/vq_sse2.c"
#include "celt/x86/pitch_sse2.c"
#elif defined(__aarch64__)
#include "celt/arm/pitch_neon_intr.c"
#include "celt/arm/celt_neon_intr.c"
#endif
