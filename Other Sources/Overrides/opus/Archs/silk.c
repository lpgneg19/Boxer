//
//  silk.c
//  opus_boxer
//
//  Created by C.W. Betts on 10/14/23.
//

#ifdef __x86_64__
#include "silk/x86/NSQ_sse4_1.c"
#include "silk/x86/NSQ_del_dec_sse4_1.c"
#include "silk/x86/VAD_sse4_1.c"
#include "silk/x86/VQ_WMat_EC_sse4_1.c"
#include "silk/fixed/x86/vector_ops_FIX_sse4_1.c"
#include "silk/fixed/x86/burg_modified_FIX_sse4_1.c"
#elif defined(__aarch64__)
#include "silk/arm/biquad_alt_neon_intr.c"
#include "silk/arm/NSQ_neon.c"
#include "silk/arm/LPC_inv_pred_gain_neon_intr.c"
#include "silk/arm/NSQ_del_dec_neon_intr.c"
#endif
