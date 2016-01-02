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
#import <unordered_map>

extern "C" {
#import "bcm/bcmsrom_tbl.h"
}

/* A parsed SPROM record from the vendor header file */
struct nvar {
    NSString *name;
    uint32_t revmask;
    uint32_t flags;
    uint16_t off;
    NSArray *off_tokens;
    uint32_t valmask;
    nvar () {}
    nvar (NSString *n, uint32_t _revmask, uint32_t _flags, uint16_t _off, NSArray *_off_tokens,
          uint32_t _valmask) : name(n), revmask(_revmask), flags(_flags), off(_off),
    off_tokens(_off_tokens), valmask(_valmask) {}
    
    uint16_t unaligned_off() const {
        if (valmask & 0xFF00)
            return off;
        else
            return off+sizeof(uint8_t);
    }
    
    size_t width() const {
        size_t w = 4;
        if (!(valmask & 0xFF000000))
            w -= 1;
        
        if (!(valmask & 0x00FF0000))
            w -= 1;
        
        if (!(valmask & 0x0000FF00))
            w -= 1;
        
        if (!(valmask & 0x000000FF))
            w -= 1;
        
        return w;
    }
};


/*
 * A copy of our output target's types, modified to support generating
 * output code, allow use of std::vector instead of C arrays, etc.
 */

/** NVRAM primitive data types */
typedef enum {
    BHND_NVRAM_DT_UINT,	/**< unsigned integer */
    BHND_NVRAM_DT_SINT,	/**< signed integer */
    BHND_NVRAM_DT_MAC48,	/**< MAC-48 address */
    BHND_NVRAM_DT_LEDDC,	/**< LED PWM duty-cycle */
    BHND_NVRAM_DT_ASCII	/**< ASCII character */
} bhnd_nvram_dt;

/** NVRAM data type string representations */
typedef enum {
    BHND_NVRAM_SFMT_HEX,	/**< hex string format */
    BHND_NVRAM_SFMT_SDEC,	/**< signed decimal format */
    BHND_NVRAM_SFMT_CCODE,	/**< country code format (ascii string) */
    BHND_NVRAM_SFMT_MACADDR,	/**< mac address (canonical form, hex octets,
                                 seperated with ':') */
} bhnd_nvram_sfmt;

/** NVRAM variable flags */
enum {
    BHND_NVRAM_VF_DFLT	= 0,
    BHND_NVRAM_VF_ARRAY	= (1<<0),	/**< variable is an array */
    BHND_NVRAM_VF_MFGINT	= (1<<1),	/**< mfg-internal variable; should not be externally visible */
    BHND_NVRAM_VF_IGNALL1	= (1<<2)	/**< hide variable if its value has all bits set. */
};

#define	BHND_SPROMREV_MAX	UINT16_MAX	/**< maximum supported SPROM revision */

/** SPROM revision compatibility declaration */
struct bhnd_sprom_compat {
    uint16_t	first;	/**< first compatible SPROM revision */
    uint16_t	last;	/**< last compatible SPROM revision, or BHND_SPROMREV_MAX */
};

/** SPROM value segment descriptor */
struct bhnd_sprom_vseg {
    uint16_t	offset;	/**< byte offset within SPROM */
    size_t		width;	/**< 1, 2, or 4 bytes */
    uint32_t	mask;	/**< mask to be applied to the value */
    size_t		shift;	/**< shift to be applied to the value */
};

/** SPROM value descriptor */
struct bhnd_sprom_value {
    std::vector<bhnd_sprom_vseg>	segs;		/**< segment(s) containing this value */
};

/** SPROM-specific variable definition */
struct bhnd_sprom_var {
    const bhnd_sprom_compat	 compat;	/**< sprom compatibility declaration */
    std::vector<bhnd_sprom_value> values;	/**< value descriptor(s) */
};

/** NVRAM variable definition */
struct bhnd_nvram_var {
    std::string		name;		/**< variable name */
    bhnd_nvram_dt		 type;		/**< base data type */
    bhnd_nvram_sfmt		 fmt;		/**< string format */
    uint32_t		 flags;		/**< BHND_NVRAM_VF_* flags */
    size_t			 array_len;	/**< array element count (if BHND_NVRAM_VF_ARRAY) */
    
    std::vector<bhnd_sprom_var>	sprom_descs;	/**< SPROM-specific variable descriptors */
};


static id<NSObject> get_literal(PLClangTranslationUnit *tu, PLClangToken *t);

static PLClangToken *
resolve_pre(PLClangTranslationUnit *tu, PLClangToken *t) {
    PLClangCursor *def = t.cursor.referencedCursor;
    NSArray *tokens = [tu tokensForSourceRange: def.extent];
    
    if (tokens.count < 2)
        errx(EXIT_FAILURE, "macro def %s missing expected token count", t.spelling.UTF8String);

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
    char op = '\0';

    if (tokens.count == 0)
        errx(EXIT_FAILURE, "empty token list");

    for (__strong PLClangToken *t in tokens) {
        if (t.kind == PLClangTokenKindIdentifier)
            t = resolve_pre(tu, t);
        
        switch (t.kind) {
            case PLClangTokenKindLiteral: {
                NSNumber *n = (NSNumber *) get_literal(tu, t);
                uint32_t nv = (uint32_t) [n unsignedIntegerValue];
                switch (op) {
                    case '\0':
                        v = nv;
                        break;
                    case '|':
                        v |= nv;
                        break;
                    case '+':
                        v += nv;
                        break;
                    case '-':
                        v -= nv;
                        break;
                    default:
                        errx(EXIT_FAILURE, "unsupported op %c", op);
                }
                break;
            }
            case PLClangTokenKindPunctuation:
                op = t.spelling.UTF8String[0];
                break;
            default:
                errx(EXIT_FAILURE, "Unsupported token type!");
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
    NSArray *off_tokens = (NSArray *) grouped[3];
    uint16_t off = compute_literal(tu, off_tokens);
    uint32_t valmask = compute_literal(tu, grouped[4]);

    *nout = nvar(name, revmask, flags, off, off_tokens, valmask);
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


    std::vector<nvar> clean_nvars;
    for (size_t i = 0; i < nvars->size(); i++) {
        nvar *n = &(*nvars)[i];

        std::string name = n->name.UTF8String;
        uint32_t flags = n->flags;
        uint16_t offset = n->unaligned_off();
        size_t width = n->width();
        uint32_t valmask = n->valmask;

        /* Unify unnecessary continuations */
        nvar *c = n;
        while (c->flags & SRFL_MORE) {
            i++;
            c = &(*nvars)[i];

            /* Can't unify sparse continuations */
            if (c->unaligned_off() != (offset + (width / sizeof(uint16_t)))) {
                warnx("%s: sparse continuation (%hu, %hu, %zu)", name.c_str(), c->unaligned_off(), offset, width);
                i--;
                break;
            }

            if (c->revmask != 0 && c->revmask != n->revmask)
                errx(EXIT_FAILURE, "%s: continuation has non-matching revmask", name.c_str());

            if (c->valmask != 0xFFFF)
                errx(EXIT_FAILURE, "%s: unsupported valmask", name.c_str());

            width += c->width();
            valmask <<= c->width()*8;
            valmask |= c->valmask;
            flags &= ~SRFL_MORE;
        }

        clean_nvars.emplace_back(n->name, n->revmask, flags, n->off, n->off_tokens, valmask);
    }
    
    std::unordered_map<std::string, std::shared_ptr<bhnd_nvram_var>> var_table;
    std::vector<std::shared_ptr<bhnd_nvram_var>> vars;

    for (size_t i = 0; i < clean_nvars.size(); i++) {
        nvar *n = &clean_nvars[i];
    
        std::string name = n->name.UTF8String;
        uint32_t revmask = n->revmask;
        uint32_t flags = n->flags;
        uint16_t offset = n->unaligned_off();
        size_t width = n->width();
        uint32_t valmask = n->valmask;

        warnx("%s", name.c_str());
        if (name.length() == 0)
            errx(EXIT_FAILURE, "variable has zero-length name");

        /* Generate the basic bhnd_nvram_var record */
        auto v = std::make_shared<bhnd_nvram_var>();
        v->name = name;
        
        /* Determine fmt and type */
        if (flags & SRFL_CCODE) {
            v->type = BHND_NVRAM_DT_ASCII;
            v->fmt = BHND_NVRAM_SFMT_CCODE;
        } else if (flags & SRFL_ETHADDR) {
            v->type = BHND_NVRAM_DT_MAC48;
            v->fmt = BHND_NVRAM_SFMT_MACADDR;
        } else if (flags & SRFL_LEDDC) {
            v->type = BHND_NVRAM_DT_LEDDC;
            v->fmt = BHND_NVRAM_SFMT_HEX;
        } else if (flags & SRFL_PRSIGN) {
            v->type = BHND_NVRAM_DT_SINT;
            v->fmt = BHND_NVRAM_SFMT_SDEC;
        } else if (flags & SRFL_PRHEX) {
            v->type = BHND_NVRAM_DT_UINT;
            v->fmt = BHND_NVRAM_SFMT_HEX;
        } else {
            /* Default behavior */
            v->type = BHND_NVRAM_DT_UINT;
            v->fmt = BHND_NVRAM_SFMT_HEX;
        }
        
        /* Apply flags */
        v->flags = 0;
        if (flags & SRFL_NOFFS)
            v->flags |= BHND_NVRAM_VF_IGNALL1;
        
        if (flags & SRFL_ARRAY)
            v->flags |= BHND_NVRAM_VF_ARRAY;
        
        if (flags & SRFL_NOVAR)
            v->flags |= BHND_NVRAM_VF_MFGINT;

        /* Compare against previous variable with this name, or
         * register the new variable */
        if (var_table.count(name) == 0) {
            vars.push_back(v);
            var_table.insert({name, v});
        } else {
            auto orig = var_table.at(name);

            if (orig->type != v->type)
                errx(EXIT_FAILURE, "%s: type mismatch (%u vs %u)", name.c_str(), orig->type, v->type);

            if (orig->fmt != v->fmt)
                errx(EXIT_FAILURE, "fmt mismatch");

            if (orig->flags != v->flags)
                errx(EXIT_FAILURE, "flag mismatch");

            v = orig;
        }

        /* Handle array/sparse continuation records */
        std::vector<bhnd_sprom_value> vals;
        if (clean_nvars[i].flags & SRFL_ARRAY) {
            do {
                auto c = &clean_nvars[i];
                bhnd_sprom_value val;
                
                val.segs.push_back({
                    c->unaligned_off(),
                    c->width(),
                    c->valmask,
                    0 /* TODO: Shift */
                });
                
                while (c->flags & SRFL_MORE) {
                    i++;
                    auto c = &clean_nvars[i];

                    val.segs.push_back({
                        c->unaligned_off(),
                        c->width(),
                        c->valmask,
                        0 /* TODO: Shift */
                    });
                }

                vals.push_back(val);
                i++;
            } while (clean_nvars[i].flags & SRFL_ARRAY);
        } else {
            
            while (clean_nvars[i].flags & SRFL_MORE) {
                i++;
            }
        }
        
        v->sprom_descs.push_back({{0,0}, vals});

#if 0
        NSString *offstr = [n->off_tokens componentsJoinedByString:@""];
        
        const char *type = "???";
        switch (width) {
            case 1:
                type = "u8";
                break;
            case 2:
                type = "u16";
                break;
            case 4:
                type = "u32";
                break;
        }
        printf("%s:\t0x%x 0x%x %s(0x%08hX) 0x%x (%s%s)\n", name.c_str(), revmask, flags, offstr.UTF8String, offset, valmask, type, (flags & SRFL_ARRAY) ? "[]" : "");
        
        int ctz = __builtin_ctz(revmask);
        printf("\tmin-ver = %u\n", (1<<ctz));
        printf("\tmax-ver = %u\n", revmask);
#endif
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