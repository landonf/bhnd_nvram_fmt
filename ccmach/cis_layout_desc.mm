//
//  cis_layout_desc.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/12/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "cis_layout_desc.hpp"

void parse_layout (NSString *layout) {
    NSScanner *s = [NSScanner scannerWithString: layout];
    NSString *varname;
    int sz;
    int count;

    if (![s scanInt: &sz] || sz == 0) {
        // TODO
        printf("special-var: %s\n", layout.UTF8String);
        return;
    }

    /* array? */
    if ([s scanString: @"*" intoString: NULL]) {
        if (![s scanInt: &count])
            errx(EX_DATAERR, "array specifier missing length in %s", layout.UTF8String);
    } else {
        count = 1;
    }
    
    if (![s scanCharactersFromSet: [NSCharacterSet whitespaceAndNewlineCharacterSet].invertedSet intoString: &varname])
        errx(EX_DATAERR, "failed to scan variable name in %s", layout.UTF8String);

    printf("parsed %s as %d[%d]\n", varname.UTF8String, sz, count);
}

void parse_layouts (const cis_tuple_t *t) {
    
    if (strlen(t->params) == 0)
        return; // special case

    NSArray *varls = [@(t->params) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *layout in varls) {
        parse_layout(layout);
    }
}