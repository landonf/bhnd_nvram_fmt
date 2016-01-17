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
    for (const auto &vs : vsets) {
        if (vs->comment().size() > 0)
            println("# %s", [@(vs->comment().c_str()) stringByReplacingOccurrencesOfString:@"\n" withString:@"\n# "].UTF8String);
    
        prints("%s", vs->name().c_str(), ^{
            if (vs->cis().is<var_set_cis>()) {
                auto cis = ftl::get<var_set_cis>(vs->cis());
                
                print("cis_tuple\t%s", cis.tag().name().c_str());
                if (cis.hnbu_tag().is<symbolic_constant>()) {
                    printf(",%s", ftl::get<symbolic_constant>(cis.hnbu_tag()).name().c_str());
                }
                printf("\n");
                
                println("compat\t\t%s", cis.compat().description().c_str());
            }
            
            for (const auto &v : *vs->vars()) {
                string vtype = to_string(v->type());
                if (v->count() > 1)
                    vtype += "[" + to_string(v->count()) + "]";

                prints("%s %s", vtype.c_str(), v->name().c_str(), ^{
                    if (v->sfmt() != SFMT_HEX)
                        println("sfmt\t%s", to_string(v->sfmt()).c_str());
                    
                    for (const auto &cis : *v->cis_offsets()) {
                        const auto &value = cis.value();
                        string type = to_string(value.type());
                        if (value.count() > 1)
                            type += "[" + to_string(value.count()) + "]";
                        
                        if (type == vtype)
                            type = " ";
                        else
                            type = " " + type + " @ ";
                        
                        string rdesc = cis.compat().description();
                        if (cis.compat() == ftl::get<var_set_cis>(vs->cis()).compat())
                            rdesc = "\t";
                        else
                            rdesc = " " + rdesc + "\t";
                        
                        print("cis%s{%s%s", rdesc.c_str(), type.c_str(), value.cis_description().c_str());
                        printf(" }\n");
                    }
                    
                    
                    for (const auto &sp : *v->sprom_offsets()) {
                        auto rdesc = sp.compat().description();
                        // TODO: Saner method for determining covered sromrevs
                        if (vs->cis().is<var_set_cis>() && sp.compat() == ftl::get<var_set_cis>(vs->cis()).compat() && v->sprom_offsets()->size() == 1)
                            rdesc = " ";
                        else
                            rdesc = " " + rdesc;
                        
                        print("srom%s\t{ ", rdesc.c_str());
                        for (size_t vi = 0; vi < sp.values()->size(); vi++) {
                            const auto &val = sp.values()->at(vi);
                            auto segs = val.segments();
                            for (size_t seg = 0; seg < segs->size(); seg++) {
                                auto s = segs->at(seg);

                                string type = to_string(s.type());
                                if (s.count() > 1)
                                    type += "[" + to_string(s.count()) + "]";
                                
                                if (type == vtype)
                                    type = "";
                                else
                                    type = " " + type + " @ ";
                                
                                printf("%s%s", type.c_str(), s.description().c_str());
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