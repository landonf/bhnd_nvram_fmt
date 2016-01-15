//
//  cis_layout_desc.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/12/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "cis_layout_desc.hpp"
#include "nvram.hpp"

namespace nvram {

static cis_var_layout parse_layout (NSString *layout, size_t offset) {
    NSScanner *s = [NSScanner scannerWithString: layout];
    NSString *varname;
    int sz;
    int count = 1;
    prop_type ptype;
    uint32_t mask;
    size_t shift = 0;
    bool special_case = false;

    bool isInt;
    bool isString = false;
    bool isArray = false;
    isInt = [s scanInt: &sz];
    if (!isInt) {
        isString = [s scanString: @"s" intoString:NULL];
    } else {
        /* array? */
        isArray = [s scanString: @"*" intoString: NULL];
        if (isArray) {
            if (![s scanInt: &count])
                errx(EX_DATAERR, "array specifier missing length in %s", layout.UTF8String);
        } else {
            count = 1;
        }
    }

    if (!isInt && !isString)
        errx(EX_DATAERR, "can't parse initial type char in %s", layout.UTF8String);

    if (![s scanCharactersFromSet: [NSCharacterSet whitespaceAndNewlineCharacterSet].invertedSet intoString: &varname])
        errx(EX_DATAERR, "failed to scan variable name in %s", layout.UTF8String);

    if (isString) {
        ptype = BHND_T_CSTR;
        sz = 0;
        count = 0;
        mask = 0xFF;
        special_case = true;
    } else {
        switch (sz) {
            case 0: {
                ptype = BHND_T_UINT8;
                shift = 0;
                mask = 0xFF;

                if (cis_subst_layout.count(varname.UTF8String) == 0) {
                    errx(EX_DATAERR, "%s missing CIS layout record, no substitute found", varname.UTF8String);
                }
                
                const auto &vseg = cis_subst_layout.at(varname.UTF8String);
                if (vseg.offset() != offset) {
                    warnx("layout has different offset for %s; expected %zu, got %zu", layout.UTF8String, offset, vseg.offset());
                }
                offset = vseg.offset();
                ptype = vseg.type();
                count = (int) vseg.count();
                mask = vseg.mask();
                shift = vseg.shift();
                sz = (int) prop_type_size(ptype);
                break;
            }
            case 1:
                ptype = BHND_T_UINT8;
                mask = 0xFF;
                break;
            case 2:
                ptype = BHND_T_UINT16;
                mask = 0xFFFFF;
                break;
            case 4:
                ptype = BHND_T_UINT32;
                mask = 0xFFFFFFFF;
                break;
            case 8:
                ptype = BHND_T_UINT32;
                mask = 0xFFFFFFFF;
                sz = 4;
                warnx("%s uses an 8 byte size spec; this is ignored and treated as a 4 byte number by wlu.c", layout.UTF8String);
                break;
            default:
                if ([layout isEqualToString: @"6macaddr"]) {
                    warnx("%s is used to derive the boardnum and requires special handling; treating as MAC-48 value", layout.UTF8String);
                    ptype = BHND_T_UINT8;
                    sz = 1;
                    mask = 0xFF;
                    count = 48;
                    special_case = true;
                } else if ([layout isEqualToString: @"16uuid"]) {
                    // TODO - do we need a UUID type?
                    ptype = BHND_T_UINT8;
                    mask = 0xFF;
                    sz = 1;
                    count = 16;
                } else {
                    errx(EX_DATAERR, "unhandled size spec in %s", layout.UTF8String);
                }
        }
    }

    return nvram::cis_var_layout(varname.UTF8String, offset, sz, ptype, count, mask, shift, special_case);
}

vector<cis_layout> parse_layouts (shared_ptr<Compiler> &c) {
    vector<cis_layout> result;
    unordered_map<uint32, symbolic_constant> cis_tags;
    unordered_map<uint32, symbolic_constant> hnbu_tags;

    for (NSString *name in c->symbols()) {
        if (![name hasPrefix: @"HNBU_"] && ![name isEqual: @"OTP_RAW1"] && ![name isEqual: @"OTP_VERS_1"] && ![name isEqual: @"OTP_MANFID"] && ![name isEqual: @"OTP_RAW1"])
            continue;

        auto tag = c->resolve_constant(name.UTF8String);
        if (hnbu_tags.count(tag.value()) > 0)
            errx(EX_DATAERR, "duplicate constant value for %s", name.UTF8String);
    
        hnbu_tags.insert({tag.value(), tag});
    }
    
    for (NSString *name in c->symbols()) {
        if (![name hasPrefix: @"CISTPL_"])
            continue;
        
        auto tag = c->resolve_constant(name.UTF8String);
        if (cis_tags.count(tag.value()) > 0)
            errx(EX_DATAERR, "duplicate CIS constant value for %s", name.UTF8String);
        cis_tags.insert({tag.value(), tag});
    }

    for (const cis_tuple_t *t = cis_hnbuvars; t->tag != 0xFF; t++) {
        symbolic_constant tag("", 0xFF);
        ftl::maybe<symbolic_constant> hnbu_tag = ftl::nothing<symbolic_constant>();
        switch (t->tag) {
            case OTP_VERS_1:
                tag = cis_tags.at(CISTPL_VERS_1);
                break;
            case OTP_MANFID:
                tag = cis_tags.at(CISTPL_MANFID);
                break;
            case OTP_RAW:
            case OTP_RAW1:
                continue;
            default:
                tag = cis_tags.at(CISTPL_BRCM_HNBU);
                
                if (hnbu_tags.count(t->tag) == 0)
                    errx(EX_DATAERR, "can't find constant for tag %hhx (%s)", t->tag, t->params);

                hnbu_tag = ftl::just(hnbu_tags.at(t->tag));
                break;
                
        }

        if (strlen(t->params) == 0) {
            result.emplace_back(tag, hnbu_tag, compat_range::from_revmask(t->revmask), t->len, vector<cis_var_layout>());
            continue; // special case
        }

        NSArray *varls = [@(t->params) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        size_t offset = 0;
        vector<cis_var_layout> vars;
        for (NSString *layout in varls) {
            auto vl = parse_layout(layout, offset);
            vars.push_back(vl);
            offset += vl.size() * vl.count();
        }
        result.emplace_back(tag, hnbu_tag, compat_range::from_revmask(t->revmask), t->len, vars);
    }
    
    return result;
}

}