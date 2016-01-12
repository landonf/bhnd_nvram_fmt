//
//  cis_layout_desc.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/12/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "cis_layout_desc.hpp"

namespace nvram {

static cis_var_layout parse_layout (NSString *layout, size_t offset) {
    NSScanner *s = [NSScanner scannerWithString: layout];
    NSString *varname;
    int sz;
    int count;

    if (![s scanInt: &sz]) {
        /* 'special' var */
        sz = 0;
        count = 0;
    } else {
        /* array? */
        if ([s scanString: @"*" intoString: NULL]) {
            if (![s scanInt: &count])
                errx(EX_DATAERR, "array specifier missing length in %s", layout.UTF8String);
        } else {
            count = 1;
        }
    }

    if (![s scanCharactersFromSet: [NSCharacterSet whitespaceAndNewlineCharacterSet].invertedSet intoString: &varname])
        errx(EX_DATAERR, "failed to scan variable name in %s", layout.UTF8String);

    return nvram::cis_var_layout(varname.UTF8String, offset, sz, count);
}

vector<cis_layout> parse_layouts (shared_ptr<Compiler> &c) {
    vector<cis_layout> result;
    unordered_map<uint32, symbolic_constant> tags;

    for (NSString *name in c->symbols()) {
        if (![name hasPrefix: @"HNBU_"] && ![name hasPrefix: @"CISTPL_"] && ![name hasPrefix: @"OTP_"])
            continue;

        auto tag = c->resolve_constant(name.UTF8String);
        tags.insert({tag.value(), tag});
        if ([name hasPrefix: @"OTP_"])
            NSLog(@"mapped %s to 0x%x", tag.name().c_str(), tag.value());
    }

    for (const cis_tuple_t *t = cis_hnbuvars; t->tag != 0xFF; t++) {
        if (tags.count(t->tag) == 0)
            errx(EX_DATAERR, "can't find constant for tag %hhx (%s)", t->tag, t->params);
        auto tag = tags.at(t->tag);

        if (strlen(t->params) == 0) {
            result.emplace_back(tag, compat_range::from_revmask(t->revmask), t->len, vector<cis_var_layout>());
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
        result.emplace_back(tag, compat_range::from_revmask(t->revmask), t->len, vars);
    }
    
    return result;
}

}