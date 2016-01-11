//
//  nvram.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/10/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "nvram.hpp"

using namespace nvram;

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