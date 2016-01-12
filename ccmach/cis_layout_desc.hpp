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


#include <string>
#include <unistd.h>
#include <err.h>
#include <sysexits.h>
#include <vector>
#include <unordered_map>
#include <unordered_set>

#include <Foundation/Foundation.h>


void parse_layouts (NSString *layouts);

#endif