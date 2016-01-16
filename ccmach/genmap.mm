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
    auto vsets = _nv.var_sets();
    for (const auto &v : vsets) {
        printf("%s {\n", v.name().c_str());
        _depth++;
        if (v.cis().is<var_set_cis>()) {
            auto cis = ftl::get<var_set_cis>(v.cis());
            print("cis\t%s\t(%s", cis.compat().description().c_str(), cis.tag().name().c_str());
            if (cis.hnbu_tag().is<symbolic_constant>()) {
                printf(", %s", ftl::get<symbolic_constant>(cis.hnbu_tag()).name().c_str());
            }
            printf(")\n");
        }
        _depth--;
        print("}\n");
    }
}

}