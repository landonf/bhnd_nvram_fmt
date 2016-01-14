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

string nvram::prop_type_str (prop_type t) {
    switch (t) {
        case nvram::BHND_T_UINT8: return "BHND_T_UINT8";
        case nvram::BHND_T_UINT16: return "BHND_T_UINT16";
        case nvram::BHND_T_UINT32: return "BHND_T_UINT32";
        case nvram::BHND_T_INT8: return "BHND_T_INT8";
        case nvram::BHND_T_INT16: return "BHND_T_INT16";
        case nvram::BHND_T_INT32: return "BHND_T_INT32";
        case nvram::BHND_T_CHAR: return "BHND_T_CHAR";
    }
}

size_t nvram::prop_type_size (prop_type t) {
    switch (t) {
        case nvram::BHND_T_UINT8: return 1;
        case nvram::BHND_T_UINT16: return 2;
        case nvram::BHND_T_UINT32: return 4;
        case nvram::BHND_T_INT8: return 1;
        case nvram::BHND_T_INT16: return 2;
        case nvram::BHND_T_INT32: return 4;
        case nvram::BHND_T_CHAR: return 1;
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

unordered_set<string> nvram::cis_known_special_cases = {
    /* Standard CIS tuple */
    "manf",
    "productname",
    
    /* Requires special handling, but the layout is perfectly standard */
    "macaddr",
};

namespace nvram {

unordered_map<string, value_seg> cis_subst_layout = {
    // HNBU_RSSISMBXA2G
    { "rssismf2g",  { 0, BHND_T_UINT8, 1, 0x0F, 0 }},
    { "rssismc2g",  { 0, BHND_T_UINT8, 1, 0xF0, 4 }},
    { "rssisav2g",  { 1, BHND_T_UINT8, 1, 0x07, 0 }},
    { "bxa2g",      { 1, BHND_T_UINT8, 1, 0x18, 3 }},

    // HNBU_RSSISMBXA5G
    { "rssismf5g",  { 0, BHND_T_UINT8, 1, 0x0F, 0 }},
    { "rssismc5g",  { 0, BHND_T_UINT8, 1, 0xF0, 4 }},
    { "rssisav5g",  { 1, BHND_T_UINT8, 1, 0x07, 0 }},
    { "bxa5g",      { 1, BHND_T_UINT8, 1, 0x18, 3 }},

    // HNBU_FEM
    { "pdetrange2g", { 0, BHND_T_UINT8, 1, 0xF8, 3 }},
    { "extpagain2g", { 0, BHND_T_UINT8, 1, 0x6, 1 }},
    { "tssipos2g",   { 0, BHND_T_UINT8, 1, 0x1, 0 }},
    { "antswctl2g",  { 1, BHND_T_UINT8, 1, 0xF8, 3 }},
    { "triso2g",     { 1, BHND_T_UINT8, 1, 0x7, 0 }},
    
    { "pdetrange5g", { 2, BHND_T_UINT8, 1, 0xF8, 3 }},
    { "extpagain5g", { 2, BHND_T_UINT8, 1, 0x6, 1 }},
    { "tssipos5g",   { 2, BHND_T_UINT8, 1, 0x1, 0 }},
    { "antswctl5g",  { 3, BHND_T_UINT8, 1, 0xF8, 3 }},
    { "triso5g",     { 3, BHND_T_UINT8, 1, 0x7, 0 }},

    // HNBU_TEMPTHRESH
    { "temps_period", { 1, BHND_T_UINT8, 1, 0xF0, 4 }},  // XXX: Note that period/hysteresis is reversed from the SROM encoding
    { "temps_hysteresis", { 1, BHND_T_UINT8, 1, 0x0F, 0 }},
    
    { "tempcorrx", { 4, BHND_T_UINT8, 1, 0xFC, 2 }},
    { "tempsense_option", { 4, BHND_T_UINT8, 1, 0x3, 0 }},
    
    // HNBU_FEM_CFG
    //      fem_cfg1
    { "epagain2g",      { 0, BHND_T_UINT8, 1, 0xE, 1 }},
    { "tssiposslope2g", { 0, BHND_T_UINT8, 1, 0x1, 0 }},
    { "pdgain2g",       { 0, BHND_T_UINT16, 1, 0x1F0, 4 }},
    { "femctrl",        { 1, BHND_T_UINT8, 1, 0xF8, 3 }},
    { "papdcap2g",      { 1, BHND_T_UINT8, 1, 0x4, 2 }},
    { "tworangetssi2g", { 1, BHND_T_UINT8, 1, 0x2, 1 }},
    //      fem_cfg2
    { "epagain5g",      { 2, BHND_T_UINT8, 1, 0xE, 1 }},
    { "tssiposslope5g", { 2, BHND_T_UINT8, 1, 0x1, 0 }},
    { "pdgain5g",       { 2, BHND_T_UINT16, 1, 0x1F0, 4 }},
    { "gainctrlsph",    { 3, BHND_T_UINT8, 1, 0xF8, 3 }},
    { "papdcap5g",      { 3, BHND_T_UINT8, 1, 0x4, 2 }},
    { "tworangetssi5g", { 3, BHND_T_UINT8, 1, 0x2, 1 }},

    
    // HNBU_ACRXGAINS_C0
    // rxgains
    { "rxgains2gtrelnabypa0",   { 0, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains2gtrisoa0",       { 0, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains2gelnagaina0",    { 0, BHND_T_UINT8, 1, 0x7, 0 }},
    { "rxgains5gtrelnabypa0",   { 1, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5gtrisoa0",       { 1, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5gelnagaina0",    { 1, BHND_T_UINT8, 1, 0x7, 0 }},
    
    // rxgains1
    { "rxgains5ghtrelnabypa0",   { 2, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5ghtrisoa0",       { 2, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5ghelnagaina0",    { 2, BHND_T_UINT8, 1, 0x7, 0 }},
    { "rxgains5gmtrelnabypa0",   { 3, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5gmtrisoa0",       { 3, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5gmelnagaina0",    { 3, BHND_T_UINT8, 1, 0x7, 0 }},

    // HNBU_ACRXGAINS_C1
    // rxgains
    { "rxgains2gtrelnabypa1",   { 0, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains2gtrisoa1",       { 0, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains2gelnagaina1",    { 0, BHND_T_UINT8, 1, 0x7, 0 }},
    { "rxgains5gtrelnabypa1",   { 1, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5gtrisoa1",       { 1, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5gelnagaina1",    { 1, BHND_T_UINT8, 1, 0x7, 0 }},
    
    // rxgains1
    { "rxgains5ghtrelnabypa1",   { 2, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5ghtrisoa1",       { 2, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5ghelnagaina1",    { 2, BHND_T_UINT8, 1, 0x7, 0 }},
    { "rxgains5gmtrelnabypa1",   { 3, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5gmtrisoa1",       { 3, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5gmelnagaina1",    { 3, BHND_T_UINT8, 1, 0x7, 0 }},

    // HNBU_ACRXGAINS_C2
    // rxgains
    { "rxgains2gtrelnabypa2",   { 0, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains2gtrisoa2",       { 0, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains2gelnagaina2",    { 0, BHND_T_UINT8, 1, 0x7, 0 }},
    { "rxgains5gtrelnabypa2",   { 1, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5gtrisoa2",       { 1, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5gelnagaina2",    { 1, BHND_T_UINT8, 1, 0x7, 0 }},
    
    // rxgains1
    { "rxgains5ghtrelnabypa2",   { 2, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5ghtrisoa2",       { 2, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5ghelnagaina2",    { 2, BHND_T_UINT8, 1, 0x7, 0 }},
    { "rxgains5gmtrelnabypa2",   { 3, BHND_T_UINT8, 1, 0x80, 7 }},
    { "rxgains5gmtrisoa2",       { 3, BHND_T_UINT8, 1, 0x78, 3 }},
    { "rxgains5gmelnagaina2",    { 3, BHND_T_UINT8, 1, 0x7, 0 }},

    
    // HNBU_PDOFF_2G
    { "pdoffset2g40ma0", { 0, BHND_T_UINT8, 1, 0xF, 0 }},
    { "pdoffset2g40ma1", { 0, BHND_T_UINT8, 1, 0xF0, 4 }},
    { "pdoffset2g40ma2", { 1, BHND_T_UINT8, 1, 0xF, 0 }},
    { "pdoffset2g40mvalid", { 1, BHND_T_UINT8, 1, 0x80, 7 }},
    
#if 0
case HNBU_RSSISMBXA2G:
    ASSERT(sromrev == 3);
    varbuf_append(&b, vstr_rssismf2g, cis[i + 1] & 0xf);
    varbuf_append(&b, vstr_rssismc2g, (cis[i + 1] >> 4) & 0xf);
    varbuf_append(&b, vstr_rssisav2g, cis[i + 2] & 0x7);
    varbuf_append(&b, vstr_bxa2g, (cis[i + 2] >> 3) & 0x3);
    break;
    
case HNBU_RSSISMBXA5G:
    ASSERT(sromrev == 3);
    varbuf_append(&b, vstr_rssismf5g, cis[i + 1] & 0xf);
    varbuf_append(&b, vstr_rssismc5g, (cis[i + 1] >> 4) & 0xf);
    varbuf_append(&b, vstr_rssisav5g, cis[i + 2] & 0x7);
    varbuf_append(&b, vstr_bxa5g, (cis[i + 2] >> 3) & 0x3);
    break;
#endif
};

}