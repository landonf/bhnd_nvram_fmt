//
//  nvram_map.h
//  ccmach
//
//  Created by Landon Fuller on 1/1/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#ifndef _cis_layout_desc_h_
#define _cis_layout_desc_h_

#include "nvtypes.h"
#include "cc.hpp"

#include <string>
#include <unistd.h>
#include <err.h>
#include <sysexits.h>
#include <vector>
#include <unordered_map>
#include <unordered_set>

#include <Foundation/Foundation.h>

namespace nvram {

PL_RECORD_STRUCT(cis_var_layout,
    (string,    name),
    (size_t,    offset),
    (size_t,    size),
    (size_t,    count)
);
    
PL_RECORD_STRUCT(cis_layout,
    (symbolic_constant,    tag),
    (compat_range,         compat),
    (size_t,               tuple_size),
    (vector<cis_var_layout>, vars)
);

vector<cis_layout> parse_layouts (shared_ptr<Compiler> &c);

}

#endif