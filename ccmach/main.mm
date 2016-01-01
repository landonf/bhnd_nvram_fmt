//
//  main.mm
//  ccmach
//
//  Created by Landon Fuller on 12/31/15.
//  Copyright (c) 2015 Landon Fuller. All rights reserved.
//

#include <stdio.h>

#import <err.h>
#import <getopt.h>
#import <ObjectDoc/ObjectDoc.h>
#import <ObjectDoc/PLClang.h>

#import <string>
#import <vector>

extern "C" {
#import "/Users/landonf/Documents/Code/FreeBSD/freebsd/sys/dev/bhnd/bcmsrom_tbl.h"
}



struct nvar {
    NSString *name;
    uint32_t revmask;
    uint32_t flags;
    NSArray *off_tokens;
    uint16_t valmask;
    nvar () {}
    nvar (NSString *n, uint32_t _revmask, uint32_t _flags, NSArray *_off_tokens,
        uint16_t _valmask) : name(n), revmask(_revmask), flags(_flags),
        off_tokens(_off_tokens), valmask(_valmask) {}
};

static id<NSObject> get_literal(PLClangTranslationUnit *tu, PLClangToken *t);

static PLClangToken *
resolve_pre(PLClangTranslationUnit *tu, PLClangToken *t) {
    PLClangCursor *def = t.cursor.referencedCursor;
    NSArray *tokens = [tu tokensForSourceRange: def.extent];
    
    if (tokens.count < 2)
        errx(1, "macro def %s missing expected token count", t.spelling.UTF8String);

    return tokens[1];
}

static id<NSObject>
get_literal(PLClangTranslationUnit *tu, PLClangToken *t) {
    if (t.kind == PLClangTokenKindIdentifier && t.cursor.isPreprocessing)
        return get_literal(tu, resolve_pre(tu, t));
        
    if (t.kind != PLClangTokenKindLiteral)
        return nil;

    NSString *s = t.spelling;
    NSScanner *sc = [NSScanner scannerWithString: s];

    switch (t.cursor.kind) {
        case PLClangCursorKindMacroDefinition:
        case PLClangCursorKindIntegerLiteral: {
            unsigned long long ull;
            if ([s hasPrefix: @"0x"]) {
                [sc scanHexLongLong: &ull];
            } else if ([s hasPrefix: @"0"] && ![s isEqual: @"0"]) {
                // TODO
                errx(EXIT_FAILURE, "octal not supported srry");
            } else {
                [sc scanUnsignedLongLong: &ull];
            }
            return [NSNumber numberWithUnsignedLongLong: ull];
        }
        case PLClangCursorKindStringLiteral: {
            NSString *lit = t.spelling;
            lit = [lit substringFromIndex: 1];
            lit = [lit substringToIndex: lit.length - 1];
            return lit;
        }
        default:
            return nil;
    }
}

static uint32_t
compute_literal(PLClangTranslationUnit *tu, NSArray *tokens)
{
    uint32_t v = 0;
    
    if (tokens.count == 0)
        errx(1, "empty token list");

    for (__strong PLClangToken *t in tokens) {
        if (t.kind == PLClangTokenKindIdentifier)
            t = resolve_pre(tu, t);
        
        switch (t.kind) {
            case PLClangTokenKindLiteral: {
                NSNumber *n = (NSNumber *) get_literal(tu, t);
                v |= [n unsignedIntegerValue];
                break;
            }
            case PLClangTokenKindPunctuation:
                if (![t.spelling isEqualToString: @"|"])
                    errx(1, "I only support OR, sorry: %s", t.spelling.UTF8String);
                break;
            default:
                errx(1, "Unsupported token type!");
        }
    }

    return v;
}

static bool
extract_struct(PLClangTranslationUnit *tu, PLClangCursor *c, nvar *nout) {
    NSMutableArray *tokens = [[tu tokensForSourceRange: c.extent] mutableCopy];
    
    if (tokens.count == 0)
        errx(EXIT_FAILURE, "zero length");

    PLClangToken *sep = tokens.lastObject;
    if (sep.kind == PLClangTokenKindPunctuation && ([sep.spelling isEqual: @","] || [sep.spelling isEqual: @"}"])) {
        sep = nil;
        [tokens removeLastObject];
    }

    if (tokens.count < 2)
        errx(EXIT_FAILURE, "invalid length");

    PLClangToken *start = tokens.firstObject;
    PLClangToken *end = tokens.lastObject;

    if (start.kind != PLClangTokenKindPunctuation || end.kind != PLClangTokenKindPunctuation)
        errx(EXIT_FAILURE, "not an initializer");
    
    if (![start.spelling isEqual: @"{"] || ![end.spelling isEqual: @"}"])
        errx(EXIT_FAILURE, "not an initializer");

    [tokens removeObjectAtIndex: 0];
    [tokens removeLastObject];

    NSMutableArray *grouped = [NSMutableArray array];
    NSMutableArray *curgroup = [NSMutableArray array];
    for (PLClangToken *t in [tokens copy]) {
        if (t.kind == PLClangTokenKindPunctuation && [t.spelling isEqualToString: @","]) {
            [grouped addObject: curgroup];
            curgroup = [NSMutableArray array];
        } else {
            [curgroup addObject: t];
        }
    }
    [grouped addObject: curgroup];

    if (grouped.count != 5)
        errx(EXIT_FAILURE, "invalid length");
    
    PLClangToken *nameToken = tokens.firstObject;

    /* Skip terminating entry */
    if (nameToken.kind == PLClangTokenKindIdentifier && [nameToken.spelling isEqual: @"NULL"])
        return false;

//    nvar n((NSString *)get_literal(tu, name), tokens);

    NSString *name = (NSString *) get_literal(tu, nameToken);
    uint32_t revmask = compute_literal(tu, grouped[1]);
    uint32_t flags = compute_literal(tu, grouped[2]);
    NSArray *offset_tokens = (NSArray *) grouped[3];
    uint32_t valmask = compute_literal(tu, grouped[4]);

    *nout = nvar(name, revmask, flags, offset_tokens, valmask);
    return true;
}

static int
ar_main(int argc, char * const argv[])
{
    NSError *error;
    NSString *input;
    int optchar;
    
    static struct option longopts[] = {
        { "help",       no_argument,        NULL,          'h' },
        { NULL,           0,                NULL,           0  }
    };
    
    while ((optchar = getopt_long(argc, argv, "h", longopts, NULL)) != -1) {
        switch (optchar) {
            case 'h':
                // TODO
                break;
            case 'i':
                input = @(optarg);
                break;
            default:
                fprintf(stderr, "unhandled option -%c\n", optchar);
                break;
        }
    }
    argc -= optind;
    argv += optind;

    auto args = [NSMutableArray array];
    for (u_int i = 0; i < argc; i++) {
        [args addObject: @(argv[i])];
    }

    auto idx = [PLClangSourceIndex indexWithOptions: PLClangIndexCreationDisplayDiagnostics];
    auto tu = [idx addTranslationUnitWithSourcePath: input
                                  compilerArguments: args
                                            options: PLClangTranslationUnitCreationDetailedPreprocessingRecord
                                              error:&error];
    if (tu == nil) {
        errx(EXIT_FAILURE, "%s", error.description.UTF8String);
    }
    
    if (tu.didFail)
        errx(EXIT_FAILURE, "parse failed");
    
    
    auto api = [NSMutableDictionary dictionary];
    
    [tu.cursor visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
        if (cursor.location.isInSystemHeader || cursor.location.path == nil)
            return PLClangCursorVisitContinue;

        if (cursor.displayName.length == 0)
            return PLClangCursorVisitContinue;
        
        api[cursor.displayName] = cursor;
        
        switch (cursor.kind) {
            case PLClangCursorKindObjCInterfaceDeclaration:
            case PLClangCursorKindObjCCategoryDeclaration:
            case PLClangCursorKindObjCProtocolDeclaration:
            case PLClangCursorKindEnumDeclaration:
                return PLClangCursorVisitRecurse;
            default:
                break;
        }
        
        return PLClangCursorVisitContinue;
    }];

    auto nvars = std::make_shared<std::vector<nvar>>();
    PLClangCursor *tbl = api[@"pci_sromvars"];
    if (tbl == nil)
        errx(EXIT_FAILURE, "missing pci_sromvars");
    
    [tbl visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
        if (cursor.kind != PLClangCursorKindInitializerListExpression)
            return PLClangCursorVisitContinue;

        [cursor visitChildrenUsingBlock: ^PLClangCursorVisitResult(PLClangCursor *cursor) {
            if (cursor.kind == PLClangCursorKindInitializerListExpression) {
                nvar n;
                if (extract_struct(tu, cursor, &n))
                    nvars->push_back(n);
            }
                
            return PLClangCursorVisitContinue;
        }];
        
        return PLClangCursorVisitContinue;
    }];
    
    for (const auto &n : *nvars) {
        NSString *offset = [n.off_tokens componentsJoinedByString:@""];
        
        printf("%s:\t0x%x 0x%x %s 0x%x\n", n.name.UTF8String, n.revmask, n.flags, offset.UTF8String, n.valmask);
        
        int ctz = __builtin_ctz(n.revmask);
        printf("\tmin-ver = %u\n", (1<<ctz));
        printf("\tmax-ver = %u\n", n.revmask);
    }

    return (0);
}

int
main (int argc, char * const argv[])
{
    @autoreleasepool {
        return (ar_main(argc, argv));
    }
}