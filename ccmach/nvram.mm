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

prop_type nvram::prop_type_widen (prop_type lhs, prop_type rhs) {
    if (!nvram::prop_type_compat(lhs, rhs))
        errx(EX_DATAERR, "incompatible property types");
    
    return max(lhs, rhs);
}

prop_type nvram::prop_type_widest (prop_type operand) {
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
        case BHND_T_CSTR:
            return BHND_T_CSTR;
    }
}

bool nvram::prop_type_compat (prop_type lhs, prop_type rhs) {
    return (prop_type_widest(lhs) == prop_type_widest(rhs));
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
        case nvram::BHND_T_CSTR: return "cstr";
            
    }
}

string std::to_string(nvram::str_fmt f) {
    switch (f) {
            case SFMT_HEX:      return "hex";
            case SFMT_DECIMAL:      return "sdec";
            case SFMT_HEXBIN:      return "hexbin";
            case SFMT_MACADDR:      return "macaddr";
            case SFMT_CCODE:      return "ccode";
            case SFMT_ASCII:      return "ascii";
            case SFMT_LEDDC:      return "leddc";
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
        case nvram::BHND_T_CSTR: return "BHND_T_CSTR";
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
        case nvram::BHND_T_CSTR: return 1;
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

static unordered_map<string, prop_type> cis_ptype_overrides = {
    {"rxpo2g",  BHND_T_INT8},
    {"rxpo5g",  BHND_T_INT8}
};

static unordered_map<string, str_fmt> sfmt_overrides = {
    // CIS is wrong-ish here
    {"subband5gver", SFMT_HEX},
    {"boardnum", SFMT_HEX},
    {"bxa2g", SFMT_HEX},
    {"bxa5g", SFMT_HEX},
    {"opo", SFMT_HEX},
    {"macaddr", SFMT_MACADDR},
    
    {"rssisav2g", SFMT_HEX},
    {"rssisav5g", SFMT_HEX},
    {"rssismc2g", SFMT_HEX},
    {"rssismc5g", SFMT_HEX},
    {"rssismf2g", SFMT_HEX},
    {"rssismf5g", SFMT_HEX},
    {"cc", SFMT_HEX},
    
    {"tempcorrx", SFMT_HEX},
    {"tempsense_option", SFMT_HEX},
    {"tempsense_slope", SFMT_HEX},
    {"tempthresh", SFMT_HEX},
    
    {"tri2g", SFMT_HEX},
    {"tri5g", SFMT_HEX},
    {"tri2gh", SFMT_HEX},
    {"tri2gl", SFMT_HEX},

    {"tri5gl", SFMT_HEX},
    {"tri5gh", SFMT_HEX},

    // SROM is wrong-ish here
    {"epagain2g", SFMT_DECIMAL},
    {"epagain5g", SFMT_DECIMAL},
    {"femctrl", SFMT_DECIMAL},
    {"gainctrlsph", SFMT_DECIMAL},
    {"noiselvl2ga0", SFMT_DECIMAL},
    {"noiselvl2ga1", SFMT_DECIMAL},
    {"noiselvl2ga2", SFMT_DECIMAL},
    {"noiselvl5ga0", SFMT_DECIMAL},
    {"noiselvl5ga1", SFMT_DECIMAL},
    {"noiselvl5ga2", SFMT_DECIMAL},
    {"pa0b0", SFMT_DECIMAL},
    {"pa0b1", SFMT_DECIMAL},
    {"pa0b2", SFMT_DECIMAL},
    {"pa1b0", SFMT_DECIMAL},
    {"pa1b1", SFMT_DECIMAL},
    {"pa1b2", SFMT_DECIMAL},

    {"tempoffset", SFMT_DECIMAL},
    {"temps_hysteresis", SFMT_DECIMAL},
    {"temps_period", SFMT_DECIMAL},
    
    {"tssiposslope2g", SFMT_DECIMAL},
    {"tssiposslope5g", SFMT_DECIMAL},
    {"tworangetssi2g", SFMT_DECIMAL},
    {"tworangetssi5g", SFMT_DECIMAL},
    
    {"xtalfreq", SFMT_DECIMAL},
    

    {"pa0maxpwr", SFMT_DECIMAL},
    {"pa0itssit", SFMT_DECIMAL},
    {"pa1hib0", SFMT_DECIMAL},
    {"pa1hib1", SFMT_DECIMAL},
    {"pa1hib2", SFMT_DECIMAL},

    {"pa1himaxpwr", SFMT_DECIMAL},
    {"pa1itssit", SFMT_DECIMAL},
    {"pa1lob0", SFMT_DECIMAL},
    {"pa1lob1", SFMT_DECIMAL},
    {"pa1lob2", SFMT_DECIMAL},
    {"pa1lomaxpwr", SFMT_DECIMAL},
    {"pa1maxpwr", SFMT_DECIMAL},
    {"paparambwver", SFMT_DECIMAL},
    {"papdcap2g", SFMT_DECIMAL},
    {"papdcap5g", SFMT_DECIMAL},
    {"pdgain2g", SFMT_DECIMAL},
    {"pdgain5g", SFMT_DECIMAL},
    {"phycal_tempdelta", SFMT_DECIMAL},
    
    {"rxgains2gelnagaina0", SFMT_DECIMAL},
    {"rxgains2gelnagaina1", SFMT_DECIMAL},
    {"rxgains2gelnagaina2", SFMT_DECIMAL},
    {"rxgains2gtrelnabypa0", SFMT_DECIMAL},
    {"rxgains2gtrelnabypa1", SFMT_DECIMAL},
    {"rxgains2gtrelnabypa2", SFMT_DECIMAL},
    {"rxgains2gtrisoa0", SFMT_DECIMAL},
    {"rxgains2gtrisoa1", SFMT_DECIMAL},
    {"rxgains2gtrisoa2", SFMT_DECIMAL},
    {"rxgains5gelnagaina0", SFMT_DECIMAL},
    {"rxgains5gelnagaina1", SFMT_DECIMAL},
    {"rxgains5gelnagaina2", SFMT_DECIMAL},
    {"rxgains5ghelnagaina0", SFMT_DECIMAL},
    {"rxgains5ghelnagaina1", SFMT_DECIMAL},
    {"rxgains5ghelnagaina2", SFMT_DECIMAL},
    {"rxgains5ghtrelnabypa0", SFMT_DECIMAL},
    {"rxgains5ghtrelnabypa1", SFMT_DECIMAL},
    {"rxgains5ghtrelnabypa2", SFMT_DECIMAL},
    {"rxgains5ghtrisoa0", SFMT_DECIMAL},
    {"rxgains5ghtrisoa1", SFMT_DECIMAL},
    {"rxgains5ghtrisoa2", SFMT_DECIMAL},
    {"rxgains5gmelnagaina0", SFMT_DECIMAL},
    {"rxgains5gmelnagaina1", SFMT_DECIMAL},
    {"rxgains5gmelnagaina2", SFMT_DECIMAL},
    {"rxgains5gmtrelnabypa0", SFMT_DECIMAL},
    {"rxgains5gmtrelnabypa1", SFMT_DECIMAL},
    {"rxgains5gmtrelnabypa2", SFMT_DECIMAL},
    {"rxgains5gmtrisoa0", SFMT_DECIMAL},
    {"rxgains5gmtrisoa1", SFMT_DECIMAL},
    {"rxgains5gmtrisoa2", SFMT_DECIMAL},
    {"rxgains5gtrelnabypa0", SFMT_DECIMAL},
    {"rxgains5gtrelnabypa1", SFMT_DECIMAL},
    {"rxgains5gtrelnabypa2", SFMT_DECIMAL},
    {"rxgains5gtrisoa0", SFMT_DECIMAL},
    {"rxgains5gtrisoa1", SFMT_DECIMAL},
    {"rxgains5gtrisoa2", SFMT_DECIMAL},
};

namespace nvram {

unordered_map<string, value_seg> cis_subst_layout = {
    // HNBU_LEDDC
    { "leddc",  { 0, BHND_T_UINT8, 2, 0xFF, 0 }},

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
    

    // Manually constructed layouts follow
    
    // HNBU_CC
    { "cc", { 0, BHND_T_UINT8, 1, 0xF, 0 }},
    
    // HNBU_OEM
    { "oem", { 0, BHND_T_UINT8, 8, 0xF, 0 }},

    // HNBU_PAPARMS
    { "pa0b0_lo", { (size_t)-1, BHND_T_UINT16, 1, 0xFFFF, 0 }}, // XXXLAYOUT- we have no way of specifying that these
    { "pa0b1_lo", { (size_t)-2, BHND_T_UINT16, 1, 0xFFFF, 0 }}, // are appended to whatever variables may exist.
    { "pa0b2_lo", { (size_t)-3, BHND_T_UINT16, 1, 0xFFFF, 0 }}, // we probably want to key off SROM revision


    // CISTPL_CFTABLE
    { "regwindowsz", { 5, BHND_T_UINT16, 1, 0xFFFF, 0 }},

    // HNBU_USBFLAGS
    { "usbflags",   { 0, BHND_T_UINT32, 1, 0xFFFFFFFF, 0 }},

    // HNBU_USB30PHY_NOSS
    { "usbnoss",   { 0, BHND_T_UINT8, 1, 0xFF, 0 }},

    // HNBU_USBSSPHY_MDIO
    // XXXLAYOUT the size of the array in bytes is specified in the first byte
    // XXXLAYOUT the 4 array elements are 3 bytes in length and overlap; we can't use a dumb count
    { "usbssmdio", {0, BHND_T_UINT32, 4, 0x00FFFFFF, 0 }}, // XXXLAYOUT - we have no way of saying "as many as fit in the defined lenght"


    // HNBU_USBSSPHY_SLEEP0
    { "usbssphy_sleep0", { 0, BHND_T_UINT16, 1, 0xFFFF, 0 }},
    // HNBU_USBSSPHY_SLEEP1
    { "usbssphy_sleep1", { 0, BHND_T_UINT16, 1, 0xFFFF, 0 }},
    // HNBU_USBSSPHY_SLEEP2
    { "usbssphy_sleep2", { 0, BHND_T_UINT16, 1, 0xFFFF, 0 }},
    // HNBU_USBSSPHY_SLEEP3
    { "usbssphy_sleep3", { 0, BHND_T_UINT16, 1, 0xFFFF, 0 }},
    
    // HNBU_USBSSPHY_UTMI_CTL0
    { "usbssphy_utmi_ctl0", { 0, BHND_T_UINT32, 1, 0xFFFFFFFF, 0 }},
    // HNBU_USBSSPHY_UTMI_CTL1
    { "usbssphy_utmi_ctl1", { 0, BHND_T_UINT32, 1, 0xFFFFFFFF, 0 }},
    // HNBU_USBSSPHY_UTMI_CTL2
    { "usbssphy_utmi_ctl2", { 0, BHND_T_UINT32, 1, 0xFFFFFFFF, 0 }},
    
    // HNBU_USBUTMI_CTL
    { "usbutmi_ctl", { 0, BHND_T_UINT16, 1, 0xFFFF, 0 }},

    // HNBU_WOWLGPIO
    { "wowl_gpio", { 0, BHND_T_UINT8, 1, 0x7F, 0 }},
    { "wowl_gpiopol", { 0, BHND_T_UINT8, 1, 0x80, 7 }},

};
    
vector<shared_ptr<var_set>> nvram_map::var_sets () {
    unordered_map<string, shared_ptr<var_set>> sets;

    /*
     * Construct the CIS var sets
     */
    for (const auto &ct : _cis_consts) {
        symbolic_constant tag = ct.constant();
        ftl::maybe<symbolic_constant> hnbu_tag = ftl::nothing<symbolic_constant>();
        string name = ct.constant().name();
        
        if (strncmp(ct.constant().name().c_str(), "CISTPL_", strlen("CISTPL_")) == 0) {
            tag = ct.constant();
        } else {
            tag = symbolic_constant("CISTPL_BRCM_HNBU", CISTPL_BRCM_HNBU);
            hnbu_tag = ftl::just(ct.constant());
        }
        auto layout = get_layout(tag, hnbu_tag);
        
        NSString *comment = ct.comment();
        if (comment == nil)
            comment = @"";
        
        auto vars = make_shared<vector<shared_ptr<var>>>();
        for (const auto &v : layout.vars()) {
            str_fmt sfmt = SFMT_HEX;
            uint32_t flags = 0;
            prop_type ptype = v.type();
    
            if (has_vstr(v.name())) {
                sfmt = get_vstr(v.name())->sfmt();
            } else if (_srom_tbl.count(v.name()) > 0) {
                sfmt = _srom_tbl.at(v.name())->sfmt();
            } else if (v.name() == "usbmanfid" || v.name() == "muxenab") {
                sfmt = SFMT_HEX;
            } else {
                errx(EXIT_FAILURE, "no known format for CIS var %s", v.name().c_str());
            }

            if (sfmt_overrides.count(v.name()) > 0) {
                sfmt = sfmt_overrides.at(v.name());
            }
            
            if (cis_ptype_overrides.count(v.name()) > 0) {
                ptype = cis_ptype_overrides.at(v.name());
            }
            
            switch (v.type()) {
                case BHND_T_INT8:
                case BHND_T_INT16:
                case BHND_T_INT32:
                    if (sfmt != SFMT_DECIMAL)
                        errx(EX_DATAERR, "CIS '%s' defines a non-decimal SFMT for a signed integer", v.name().c_str());
                    break;
                default:
                    break;
            }
            
            /* Try to find a SROM var we can borrow flags from */
            if (_srom_tbl.count(v.name()) > 0) {
                flags = _srom_tbl.at(v.name())->flags();
            }
            
            cis_offset coff(layout.compat(), value_seg(v.offset(), ptype, v.count(), v.mask(), v.shift()));
            auto vl = make_shared<vector<cis_offset>>();
            vl->push_back(coff);
            vars->push_back(make_shared<var>(
                v.name(),
                ptype,
                sfmt,
                v.count(),
                flags,
                vl,
                make_shared<vector<sprom_offset>>()
            ));
        }
        
        auto vs = make_shared<var_set>(
            name,
            ftl::just(var_set_cis(tag, hnbu_tag, layout.compat())),
            comment.UTF8String,
            vars
        );
        sets.insert({ct.constant().name(), vs});
    }
    
    /*
     * Construct the SROM's stand-in varsets, unpopulated with SROM vars.
     */
    for (const auto &grtuple : srom_subst_groupings) {
        const auto gr = grtuple.second;
    
        shared_ptr<var_set> vs;
        if (sets.count(gr.name) == 0) {
            auto vsc = ftl::nothing<var_set_cis>();
            if (gr.builtin()) {
                auto tag = symbolic_constant("CISTPL_BRCM_HNBU", CISTPL_BRCM_HNBU);
                auto hnbu_tag = ftl::just(symbolic_constant(gr.name, gr.cis_tag));
                auto layout = get_layout(tag, hnbu_tag);
                vsc = ftl::just(var_set_cis(tag, hnbu_tag, layout.compat()));
            }
            
            vs = make_shared<var_set>(
                gr.name,
                vsc,
                gr.desc,
                make_shared<vector<shared_ptr<var>>>()
            );
            sets.insert({gr.name, vs});
        }
    }

    /*
     * Populate SROM vars
     */
    for (const auto &sv : _srom_vars) {
        /* Find the appropriate var set(s) */
        vector<shared_ptr<var_set>> vss;
    
        if (_cis_layout_tbl.count(sv->name()) == 0) {
            if (srom_subst_groupings.count(sv->name()) == 0) {
                errx(EX_DATAERR, "Missing group name for %s", sv->name().c_str());
            }
            const auto &gr = srom_subst_groupings.at(sv->name());
            vss.push_back(sets.at(gr.name));
        } else if (_cis_layout_tbl.count(sv->name()) > 0) {
            auto iter = _cis_layout_tbl.equal_range(sv->name());
            std::for_each(iter.first, iter.second, [&](decltype(_cis_layout_tbl)::value_type &cl){
                vss.push_back(sets.at(cl.second.index_tag()));
            });
        }
        
        /* Populate the var sets */
        for (auto &vs : vss) {
            shared_ptr<var> v;
            str_fmt sfmt = sv->sfmt();
            
            if (sfmt_overrides.count(sv->name()) > 0) {
                sfmt = sfmt_overrides.at(sv->name());
            }
            
            switch (sv->type()) {
                case BHND_T_INT8:
                case BHND_T_INT16:
                case BHND_T_INT32:
                    if (sfmt != SFMT_DECIMAL)
                        errx(EX_DATAERR, "SROM '%s' defines a non-decimal SFMT for a signed integer", sv->name().c_str());
                    break;
                default:
                    break;
            }
    
            for (auto &ventry : *vs->vars()) {
                if (ventry->name() != sv->name())
                    continue;
                
                v = ventry;
                break;
            }
            if (!v) {
                v = make_shared<var>(
                    sv->name(),
                    sv->type(),
                    sfmt,
                    sv->count(),
                    sv->flags(),
                    make_shared<vector<cis_offset>>(),
                    make_shared<vector<sprom_offset>>()
                );
                vs->vars()->push_back(v);
            } else {
                if (v->type() != sv->type()) {
                    if (v->name() == "ccode" && sv->type() == BHND_T_CHAR) {
                        // CIS is wrong-ish here
                        *v = v->type(BHND_T_CHAR);
                    } else {
                        if (!prop_type_compat(v->type(), sv->type()))
                            warnx("%s cis/srom mismatch: %s(cis) != %s(srom)", v->name().c_str(), to_string(v->type()).c_str(), to_string(sv->type()).c_str());

                        /* Widen the type */
                        *v = v->type(prop_type_widen(v->type(), sv->type()));
                    }
                }
                
                if (v->sfmt() != sfmt) {
                       errx(EX_DATAERR, "%s cis/srom mismatch: sfmt %s(cis) != %s(srom)", v->name().c_str(), to_string(v->sfmt()).c_str(), to_string(sv->sfmt()).c_str());
                }
                
                if (v->count() != sv->count()) {
                    warnx("'%s' cis/srom mismatch: count %zu(cis) != %zu(srom)", v->name().c_str(), v->count(), sv->count());
                    *v = v->count(max(v->count(), sv->count()));
                }
                
                if (v->flags() != sv->flags()) {
                    errx(EX_DATAERR, "%s cis/srom mismatch: flags 0x%x(cis) != 0x%x(srom)", v->name().c_str(), v->flags(), sv->flags());
                }
            }

            v->sprom_offsets()->insert(v->sprom_offsets()->end(), sv->sprom_offsets()->begin(), sv->sprom_offsets()->end());
        }
    }
    
    vector<shared_ptr<var_set>> result;
    for (const auto &kv : sets)
        result.push_back(kv.second);
    

    /* Report vars that live in multiple var sets */
    unordered_map<string, unordered_set<string>> vars_seen;
    for (const auto &vs : result) {
        for (const auto &v : *vs->vars()) {
            if (vars_seen.count(v->name()) == 0)
                vars_seen.insert({v->name(), unordered_set<string>()});
            
            vars_seen.at(v->name()).insert(vs->name());
        }
    }
    
    for (const auto &vpair : vars_seen) {
        const auto &vname = vpair.first;
        const auto &vset = vpair.second;
        if (vset.size() <= 1)
            continue;
    
        warnx("%s defined in multiple var sets:", vname.c_str());
        for (const auto &sname : vset) {
            fprintf(stderr, " %s ", sname.c_str());
        };
        fprintf(stderr, "\n");
    }
    
    /* alpha sort the list */
    sort(result.begin(), result.end(), [](const shared_ptr<var_set> &lhs, shared_ptr<var_set> &rhs) {
        return ([@(lhs->name().c_str()) compare: @(rhs->name().c_str()) options: NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending);
    });
    
    return result;
}


}