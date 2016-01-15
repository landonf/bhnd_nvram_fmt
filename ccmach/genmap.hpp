//
//  genmap.h
//  ccmach
//
//  Created by Landon Fuller on 1/14/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#ifndef __ccmach__genmap__
#define __ccmach__genmap__

#include "nvram.hpp"

namespace nvram {

class genmap {
private:
    nvram_map _nv;
    int _depth = 0;

public:
    int print(const char *fmt, ...);
    genmap (const nvram_map &nv) : _nv(nv) {}

    void generate();
};
    
}

#endif /* defined(__ccmach__genmap__) */
