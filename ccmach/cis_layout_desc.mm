//
//  cis_layout_desc.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/12/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "cis_layout_desc.hpp"

void parse_layout (NSString *layout) {
    
}

void parse_layouts (NSString *layouts) {
    NSArray *varls = [layouts componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *layout in varls) {
        parse_layout(layout);
    }
}