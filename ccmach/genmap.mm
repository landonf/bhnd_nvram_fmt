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
    
void genmap::emit_offset (const string &src, const string &vtype, const nv_offset &sp, bool skip_rdesc) {
    auto rdesc = sp.compat().description();
    if (skip_rdesc)
        rdesc = "";
    else
        rdesc = " " + rdesc;

    print("%s%s\t", src.c_str(), rdesc.c_str());
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
                type = type + " @ ";
            
            printf("%s%s", type.c_str(), s.description().c_str());
            if (seg+1 < segs->size())
                printf(" | ");
        }
        
        if (vi+1 < sp.values()->size())
            printf(", ");
    }
    printf("\n");

}

void genmap::generate() {
    auto vsets = _nv.var_sets();
    for (const auto &vs : vsets) {
        if (vs->comment().size() > 0 && vs->comment() != vs->name())
            println("# %s", [@(vs->comment().c_str()) stringByReplacingOccurrencesOfString:@"\n" withString:@"\n# "].UTF8String);
        
        NSString *sectName = @(vs->name().c_str());
        if ([sectName hasPrefix: @"HNBU_"])
            sectName = [[sectName substringFromIndex: 5] lowercaseString];
        else if ([sectName hasPrefix: @"CISTPL_"])
            sectName = [@"pcmcia_" stringByAppendingString: [[sectName substringFromIndex: 7] lowercaseString]];
    
        prints("%s", sectName.UTF8String, ^{
            if (vs->cis().is<var_set_cis>()) {
                auto cis = ftl::get<var_set_cis>(vs->cis());
                
                if (cis.hnbu_tag().is<symbolic_constant>()) {
                    print("cis_tuple\t%s,%s\n", cis.tag().name().c_str(), ftl::get<symbolic_constant>(cis.hnbu_tag()).name().c_str());
                } else {
                    print("cis_tuple\t%s\n", cis.tag().name().c_str());
                }
            }
            
            bool skip_rdesc = false;
            if (vs->hasCommonCompatRange() && (vs->vars()->size() > 1 || (vs->vars()->size() == 1 && vs->vars()->at(0)->cis_offsets()->size() + vs->vars()->at(0)->sprom_offsets()->size() > 1))) {
                if (!vs->getCommonCompatRange().elidable())
                    println("compat\t\t%s", vs->getCommonCompatRange().description().c_str());
                skip_rdesc = true;
            }
            
            for (const auto &v : *vs->vars()) {
                string vtype = to_string(v->decoded_type());
                if (v->count() > 1)
                    vtype += "[" + to_string(v->count()) + "]";
                
                if (v->flags() & nvram::FLAG_MFGINT)
                    vtype = "private " + vtype;

                prints("%s %s", vtype.c_str(), v->name().c_str(), ^{
                    if (v->sfmt() != SFMT_HEX)
                        println("sfmt\t%s", to_string(v->sfmt()).c_str());
                    
                    if (v->flags() & FLAG_NOALL1)
                        println("all1\tignore");
                    
                    for (const auto &cis : *v->cis_offsets())
                        emit_offset("cis\t", vtype, cis, skip_rdesc);
                    
                    for (const auto &sp : *v->sprom_offsets())
                        emit_offset("srom", vtype, sp, skip_rdesc);
                });
            }

        });
        printf("\n");
    }
}

}