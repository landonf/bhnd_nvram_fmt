//
//  cis_tuples.cpp
//  ccmach
//
//  Created by Landon Fuller on 1/8/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include "cis_tuples.hpp"

#include <stdio.h>

#include <err.h>

#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <iostream>
#include <sstream>

#import <ObjectDoc/ObjectDoc.h>
#import <ObjectDoc/PLClang.h>

extern "C" {
#include "bcm/bcmsrom_tbl.h"
}
#define	nitems(x)	(sizeof((x)) / sizeof((x)[0]))

using namespace std;

vector<string> vector_from_array(NSArray *array) {
    vector<string> vec;
    for (NSString *str in array) {
        vec.push_back(str.UTF8String);
    }
    return (vec);
}

void enumerate_cis_tuples (void) {
    NSMutableSet *sromvars = [NSMutableSet set];
    NSMutableSet *cisvars = [NSMutableSet set];

    for (const sromvar_t *v = pci_sromvars; v->name != NULL; v++)
        [sromvars addObject: @(v->name)];

    for (const sromvar_t *v = perpath_pci_sromvars; v->name != NULL; v++) {
        if (strlen(v->name) == 0)
            continue;
    
        for (NSUInteger i = 0; i < 4; i++)
            [sromvars addObject: [@(v->name) stringByAppendingFormat: @"%lu", i]];
    }

    for (const cis_tuple_t *t = cis_hnbuvars; t->tag != 0xFF; t++) {
        auto vars = [@(t->params) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        for (NSString *v in vars) {
            const char *cstr = v.UTF8String;
            const char *p;
            
            for (p = cstr; isdigit(*p) || *p == '*'; p++);
            auto offset = p - cstr;
            NSString *tv = [v substringFromIndex: offset];
            [cisvars addObject: tv];
        }

    }

    NSMutableSet *intersect = [sromvars mutableCopy];
    [intersect intersectSet: cisvars];

    for (NSString *v in intersect) {
        [sromvars removeObject: v];
        [cisvars removeObject: v];
    }

    for (NSString *v in sromvars)
        printf("srom-unique %s\n", v.UTF8String);
    
    for (NSString *v in cisvars)
        printf("cis-unique %s\n", v.UTF8String);
#if 0
        uint16_t first_ver = __builtin_ctz(t->revmask);
        uint16_t last_ver = 31 - __builtin_clz(t->revmask);

        printf("%hhu (%hu-%hu)\n", t->tag, first_ver, last_ver);
        auto vars = [@(t->params) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        
        for (NSString *v in vars) {
            const char *cstr = v.UTF8String;
            const char *p;

            for (p = cstr; isdigit(*p) || *p == '*'; p++);
            auto offset = p - cstr;
            NSString *tv = [v substringFromIndex: offset];
            printf("\t%s\n", tv.UTF8String);
            [seen addObject: tv];
        }
#endif

#if 0
        auto components = vector_from_array([@(t->params) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]);
        for (const auto &c : components) {
            printf("\t%s\n", c.c_str());
        }
#endif
}