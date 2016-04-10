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
    
    void emit_offset (const string &src, const string &vtype, const nv_offset &sp, const compat_range &range, bool skip_rdesc, bool tnl);

public:
    int print(const char *fmt, ...);
    int println(const char *fmt, ...);
    int vprint(const char *fmt, va_list args);
    int prints(const char *fmt, ...);

    genmap (const nvram_map &nv) : _nv(nv) {}

    void generate(const compat_range &);
};
    
}

#endif /* defined(__ccmach__genmap__) */
