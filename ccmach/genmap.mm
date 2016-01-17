//
//  genmap.mm
//  ccmach
//
//  Created by Landon Fuller on 1/14/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "genmap.hpp"

namespace nvram {

int genmap::vprint (const char *fmt, va_list args) {
    int cnt = 0;
    for (int i = 0; i < _depth; i++)
        cnt += printf("\t");
    
    cnt += vprintf(fmt, args);
    return (cnt);
}
    
int genmap::print (const char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    int cnt = vprint(fmt, ap);
    va_end(ap);

    return (cnt);
}

int genmap::println (const char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    int cnt = vprint(fmt, ap);
    va_end(ap);
    
    cnt += printf("\n");
    return (cnt);
}

int genmap::prints(const char *fmt, ...) {
    va_list ap;
    void (^interior)(void);
    
    va_start(ap, fmt);
    int cnt = vprint(fmt, ap);
    cnt += printf(" {\n");
    _depth++;
    interior = va_arg(ap, void (^)(void));
    va_end(ap);
    
    interior();

    _depth--;
    cnt += println("}");

    return (cnt);
}

void genmap::generate() {
    auto vsets = _nv.var_sets();
    for (const auto &v : vsets) {
        if (v->comment().size() > 0)
            println("# %s", [@(v->comment().c_str()) stringByReplacingOccurrencesOfString:@"\n" withString:@"\n# "].UTF8String);
        prints("%s", v->name().c_str(), ^{
            if (v->cis().is<var_set_cis>()) {
                auto cis = ftl::get<var_set_cis>(v->cis());
                
                print("cis_tuple\t%s\t(%s", cis.compat().revdesc().c_str(), cis.tag().name().c_str());
                if (cis.hnbu_tag().is<symbolic_constant>()) {
                    printf(", %s", ftl::get<symbolic_constant>(cis.hnbu_tag()).name().c_str());
                }
                printf(")\n");
            }
            
            for (const auto &v : *v->vars()) {
                string vtype = to_string(v->type());
                if (v->count() > 1)
                    vtype += "[" + to_string(v->count()) + "]";

                prints("%s %s", vtype.c_str(), v->name().c_str(), ^{
                    println("sfmt\t%s", to_string(v->sfmt()).c_str());
                    for (const auto &cis : *v->cis_offsets()) {
                        string type = to_string(cis.type());
                        if (cis.count() > 1)
                            type += "[" + to_string(cis.count()) + "]";
                        
                        auto seg = value_seg(cis.offset(), cis.type(), cis.count(), cis.mask(), cis.shift());

                        
                        print("cis\t{ %s @ %s", type.c_str(), seg.description().c_str());
                        printf(" }\n");
                    }
                    
                    
                    for (const auto &sp : *v->sprom_offsets()) {
                        print("srom %s\t{ ", sp.compat().revdesc().c_str());
                        for (size_t vi = 0; vi < sp.values()->size(); vi++) {
                            const auto &val = sp.values()->at(vi);
                            auto segs = val.segments();
                            for (size_t seg = 0; seg < segs->size(); seg++) {
                                auto s = segs->at(seg);
                                printf("%s @ %s", to_string(s.type()).c_str(), s.description().c_str());
                                if (seg+1 < segs->size())
                                    printf(" | ");
                            }
                            
                            if (vi+1 < sp.values()->size())
                                printf(", ");
                        }
                        printf(" }\n");
                    }
                });

            }

        });
        printf("\n");
    }
}

}