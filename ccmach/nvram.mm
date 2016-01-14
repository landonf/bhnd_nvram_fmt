//
//  nvram.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/10/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "nvram.hpp"

using namespace nvram;

const uint8_t nvram::compat_range::MAX_SPROMREV = 31;	/**< maximum supported SPROM revision */

prop_type nvram::prop_type_widen (prop_type operand) {
    switch (operand) {
        case BHND_T_UINT8:
        case BHND_T_UINT16:
        case BHND_T_UINT32:
            return BHND_T_UINT32;
        case BHND_T_INT8:
        case BHND_T_INT16:
        case BHND_T_INT32:
            return BHND_T_INT32;
        case BHND_T_CHAR:
            return BHND_T_CHAR;
    }
}

bool nvram::prop_type_compat (prop_type lhs, prop_type rhs) {
    return (prop_type_widen(lhs) == prop_type_widen(rhs));
}

string std::to_string(nvram::prop_type t) {
    switch (t) {
        case nvram::BHND_T_UINT8: return "u8";
        case nvram::BHND_T_UINT16: return "u16";
        case nvram::BHND_T_UINT32: return "u32";
        case nvram::BHND_T_INT8: return "i8";
        case nvram::BHND_T_INT16: return "i16";
        case nvram::BHND_T_INT32: return "i32";
        case nvram::BHND_T_CHAR: return "char";
            
    }
}

static nvram::grouping srom_misc =       { "srom_misc",            "SROM variables not supported by CIS",  0xFF };
static nvram::grouping paparams_c0 =     { "HNBU_PAPARMS_C0",      NULL,  HNBU_PAPARMS_C0 };
static nvram::grouping paparams_c1 =     { "HNBU_PAPARMS_C1",      NULL,  HNBU_PAPARMS_C1 };
static nvram::grouping paparams_c2 =     { "HNBU_PAPARMS_C2",      NULL,  HNBU_PAPARMS_C2 };
static nvram::grouping paparams_c3 =     { "HNBU_PAPARMS_C3",      NULL,  HNBU_PAPARMS_C3 };

static nvram::grouping rxgainerr =       { "HNBU_RXGAIN_ERR",      NULL,  HNBU_RXGAIN_ERR };

unordered_map<string, grouping&> nvram::srom_subst_groupings = {
    { "cckPwrOffset",       srom_misc },
    { "et1macaddr",         srom_misc },
    { "eu_edthresh2g",      srom_misc },
    { "eu_edthresh5g",      srom_misc },
    { "freqoffset_corr",    srom_misc },
    { "hw_iqcal_en",        srom_misc },
    { "il0macaddr",         srom_misc },
    { "iqcal_swp_dis",      srom_misc },
    
    { "noisecaloffset",     srom_misc },
    { "noisecaloffset5g",   srom_misc },
    
    { "noiselvl5gha0",      srom_misc },    // TODO: CIS unified a lot of these into a single array
    { "noiselvl5gha1",      srom_misc },
    { "noiselvl5gha2",      srom_misc },
    { "noiselvl5gla0",      srom_misc },
    { "noiselvl5gla1",      srom_misc },
    { "noiselvl5gla2",      srom_misc },
    { "noiselvl5gma0",      srom_misc },
    { "noiselvl5gma1",      srom_misc },
    { "noiselvl5gma2",      srom_misc },
    { "noiselvl5gua0",      srom_misc },
    { "noiselvl5gua1",      srom_misc },
    { "noiselvl5gua2",      srom_misc },
    
    { "pcieingress_war",    srom_misc },
    
    { "pdoffsetcckma0",     srom_misc },
    { "pdoffsetcckma1",     srom_misc },
    { "pdoffsetcckma2",     srom_misc },

    { "pa2gw2a0",           paparams_c0 },
    { "pa2gw2a1",           paparams_c1 },
    { "pa2gw2a2",           paparams_c2 },
    { "pa2gw2a3",           paparams_c3 },
    
    { "pa2gw3a0",           paparams_c0 },
    { "pa2gw3a1",           paparams_c1 },
    { "pa2gw3a2",           paparams_c2 },
    { "pa2gw3a3",           paparams_c3 },
    
    { "pa5ghw3a0",           paparams_c0 },
    { "pa5ghw3a1",           paparams_c1 },
    { "pa5ghw3a2",           paparams_c2 },
    { "pa5ghw3a3",           paparams_c3 },
    
    { "pa5glw3a0",           paparams_c0 },
    { "pa5glw3a1",           paparams_c1 },
    { "pa5glw3a2",           paparams_c2 },
    { "pa5glw3a3",           paparams_c3 },
    
    { "pa5gw3a0",           paparams_c0 },
    { "pa5gw3a1",           paparams_c1 },
    { "pa5gw3a2",           paparams_c2 },
    { "pa5gw3a3",           paparams_c3 },

    
    
    { "rxgainerr5gha0",     rxgainerr },
    { "rxgainerr5gha1",     rxgainerr },
    { "rxgainerr5gha2",     rxgainerr },

    { "rxgainerr5gma0",     rxgainerr },
    { "rxgainerr5gma1",     rxgainerr },
    { "rxgainerr5gma2",     rxgainerr },
    
    { "rxgainerr5gla0",     rxgainerr },
    { "rxgainerr5gla1",     rxgainerr },
    { "rxgainerr5gla2",     rxgainerr },
    
    { "rxgainerr5gua0",     rxgainerr },
    { "rxgainerr5gua1",     rxgainerr },
    { "rxgainerr5gua2",     rxgainerr },
    
    { "sar2g",              srom_misc },      // specific absorption rate ??
    { "sar5g",              srom_misc },      // specific absorption rate ??
    
    { "subvid",             srom_misc },      // no OTP analog? or subvendid?
    
    { "swctrlmap_2g",       srom_misc },      // TODO: what are these?

    { "tssifloor2g",       srom_misc },      // TODO: what are these?
    { "tssifloor5g",       srom_misc },      // TODO: what are these?
    { "txidxcap2g",       srom_misc },      // TODO: what are these?
    { "txidxcap5g",       srom_misc },      // TODO: what are these?
    { "txpid2ga0",       srom_misc },      // TODO: what are these?
    { "txpid2ga1",       srom_misc },      // TODO: what are these?
    { "txpid2ga2",       srom_misc },      // TODO: what are these?
    { "txpid2ga3",       srom_misc },      // TODO: what are these?
    { "txpid5ga0",       srom_misc },      // TODO: what are these?
    { "txpid5ga1",       srom_misc },      // TODO: what are these?
    { "txpid5ga2",       srom_misc },      // TODO: what are these?
    { "txpid5ga3",       srom_misc },      // TODO: what are these?
    { "txpid5gha0",       srom_misc },      // TODO: what are these?
    { "txpid5gha1",       srom_misc },      // TODO: what are these?
    { "txpid5gha2",       srom_misc },      // TODO: what are these?
    { "txpid5gha3",       srom_misc },      // TODO: what are these?
    { "txpid5gla0",       srom_misc },      // TODO: what are these?
    { "txpid5gla1",       srom_misc },      // TODO: what are these?
    { "txpid5gla2",       srom_misc },      // TODO: what are these?
    { "txpid5gla3",       srom_misc },      // TODO: what are these?

#if 0
    { "itt2ga2",            paparams_c2 },
    { "itt2ga3",            paparams_c3 },
    { "itt5ga2",            paparams_c2 },
    { "itt5ga3",            paparams_c3 },
#endif
};

