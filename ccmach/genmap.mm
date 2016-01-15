//
//  genmap.mm
//  ccmach
//
//  Created by Landon Fuller on 1/14/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "genmap.hpp"

namespace nvram {

int genmap::print (const char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    int cnt = 0;
    for (int i = 0; i < _depth; i++)
        cnt += printf("\t");

    cnt += vprintf(fmt, ap);
    va_end(ap);
    return (cnt);
}

void genmap::generate() {
    
}

}