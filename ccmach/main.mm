//
//  main.mm
//  ccmach
//
//  Created by Landon Fuller on 12/31/15.
//  Copyright (c) 2015 Landon Fuller. All rights reserved.
//

#include <stdio.h>

#include <err.h>
#include <getopt.h>

#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <iostream>
#include <iomanip>

#import <ObjectDoc/ObjectDoc.h>
#import <ObjectDoc/PLClang.h>

extern "C" {
#include "bcm/bcmsrom_tbl.h"
}

using namespace std;

static uint32_t     compute_literal(PLClangTranslationUnit *tu, NSArray *tokens);
static id<NSObject> get_literal(PLClangTranslationUnit *tu, PLClangToken *t);

/** A symbolic constant definition */
struct symbolic_constant {
    PLClangTranslationUnit *tu;
    PLClangToken           *token;
    std::string name() const { return token.spelling.UTF8String; }
};

/** A symbolic offset definition */
struct symbolic_offset {
    PLClangTranslationUnit *tu;
    NSArray                *tokens;
    uint16_t                raw_value;
    size_t                  raw_byte_offset;
    NSString               *virtual_base = nil;

    symbolic_offset() {}

    symbolic_offset(PLClangTranslationUnit *_tu, NSArray *_tokens) : tu(_tu), tokens(_tokens) {
        raw_value = compute_literal(tu, tokens);
        
        /** bcmsrom offsets assume 16-bit pointer arithmetic */
        raw_byte_offset = raw_value * sizeof(uint16_t);
    }

    vector<symbolic_constant> referenced_constants () {
        vector<symbolic_constant> ret;
        for (PLClangToken *t in tokens) {
            switch (t.kind) {
                case PLClangTokenKindIdentifier:
                    ret.push_back({tu, t});
                    break;
                default:
                    break;
            }
        }
        return ret;
    }

    std::string byte_adjusted_string_rep () {
        NSMutableArray *strs = [NSMutableArray array];

        if (virtual_base != nil) {
            [strs addObject: virtual_base];
            [strs addObject: @"+"];
        }

        for (PLClangToken *t in tokens) {
            switch (t.kind) {
                case PLClangTokenKindIdentifier:
                case PLClangTokenKindPunctuation:
                    [strs addObject: t.spelling];
                    break;
                case PLClangTokenKindLiteral: {
                    NSNumber *n = (NSNumber *) get_literal(tu, t);
                    u_int off = [n unsignedIntValue];
                    NSString *soff = [NSString stringWithFormat: @"%u", off*2];
                    [strs addObject: soff];
                    break;
                } default:
                    errx(EXIT_FAILURE, "unsupported token %s", t.description.UTF8String);
            }
        }

        return [strs componentsJoinedByString:@""].UTF8String;
    }

    bool isSimple() const {
        return (tokens.count == 1);
    };
};

namespace std {
    std::string to_string(const struct symbolic_offset &off) {
        std::string ret;
        
        ret = [off.tokens componentsJoinedByString: @" "].UTF8String;

        return ret;
    }
}

/* A parsed SPROM record from the vendor header file */
struct nvar {
    NSString *name;
    uint32_t revmask;
    uint32_t flags;
    symbolic_offset off;
    uint32_t valmask;
    nvar () {}
    nvar (NSString *n,
          uint32_t _revmask,
          uint32_t _flags,
          symbolic_offset _off,
          uint32_t _valmask) : name(n), revmask(_revmask), flags(_flags), off(_off), valmask(_valmask) {}

    size_t byte_off() const {
        size_t offset = off.raw_byte_offset;
        if (!(valmask & 0xFF00))
            offset += sizeof(uint8_t);
        
        return offset;
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
    size_t      offset;	/**< byte offset within SPROM */
    size_t		width;	/**< 1, 2, or 4 bytes */
    uint32_t	mask;	/**< mask to be applied to the value */
    ssize_t		shift;	/**< shift to be applied to the value on extraction. if negative, left shift. if positive, right shift. */
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

    NSString *name = (NSString *) get_literal(tu, nameToken);
    uint32_t revmask = compute_literal(tu, grouped[1]);
    uint32_t flags = compute_literal(tu, grouped[2]);
    symbolic_offset off(tu, (NSArray *) grouped[3]);
    uint32_t valmask = compute_literal(tu, grouped[4]);

    *nout = nvar(name, revmask, flags, off, valmask);
    return true;
}

class Extractor {
private:
    PLClangSourceIndex *idx;
    PLClangTranslationUnit *tu;
    NSDictionary *api;

    /**
     * Coalesce unnecessary continuations in nvars
     */
    shared_ptr<vector<nvar>> coalesce (shared_ptr<vector<nvar>> &nvars) {
        auto clean_nvars = make_shared<vector<nvar>>();

        for (size_t i = 0; i < nvars->size(); i++) {
            const nvar &n = (*nvars)[i];
            
            std::string name = n.name.UTF8String;
            uint32_t flags = n.flags;
            uint16_t offset = n.byte_off();
            size_t width = n.width();
            uint32_t valmask = n.valmask;
            
            /* Unify unnecessary continuations */
            const nvar *c = &n;
            while (c->flags & SRFL_MORE) {
                i++;
                c = &(*nvars)[i];
                
                /* Can't unify sparse continuations */
                if (c->byte_off() != offset + width) {
                    warnx("%s: sparse continuation (%zx, %hu, %zu)", name.c_str(), c->byte_off(), offset, width);
                    i--;
                    break;
                }
                
                if (c->revmask != 0 && c->revmask != n.revmask)
                    errx(EXIT_FAILURE, "%s: continuation has non-matching revmask", name.c_str());
                
                if (c->valmask != 0xFFFF)
                    errx(EXIT_FAILURE, "%s: unsupported valmask", name.c_str());
                
                width += c->width();
                valmask <<= c->width()*8;
                valmask |= c->valmask;
                flags &= ~SRFL_MORE;
            }
            
            clean_nvars->emplace_back(n.name, n.revmask, flags, n.off, valmask);
        }
        
        return clean_nvars;
    }

    /* Return the cursors composing the given array's initializers */
    NSArray *get_array_inits (PLClangCursor *tbl) {
        NSMutableArray *result = [NSMutableArray array];

        [tbl visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
            if (cursor.kind != PLClangCursorKindInitializerListExpression)
                return PLClangCursorVisitContinue;
            
            [cursor visitChildrenUsingBlock: ^PLClangCursorVisitResult(PLClangCursor *cursor) {
                if (cursor.kind == PLClangCursorKindInitializerListExpression)
                    [result addObject: cursor];
                
                return PLClangCursorVisitContinue;
            }];
            
            return PLClangCursorVisitContinue;
        }];

        return result;
    }

public:
    Extractor(int argc, char * const argv[]) {
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

        idx = [PLClangSourceIndex indexWithOptions: PLClangIndexCreationDisplayDiagnostics];
        tu = [idx addTranslationUnitWithSourcePath: input
                                      compilerArguments: args
                                                options: PLClangTranslationUnitCreationDetailedPreprocessingRecord
                                                  error:&error];
        if (tu == nil)
            errx(EXIT_FAILURE, "%s", error.description.UTF8String);
        
        if (tu.didFail)
            errx(EXIT_FAILURE, "parse failed");

        /* Map symbol names to their definitions */
        auto symbols = [NSMutableDictionary dictionary];
        [tu.cursor visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
            if (cursor.location.isInSystemHeader || cursor.location.path == nil)
                return PLClangCursorVisitContinue;

            if (cursor.displayName.length == 0)
                return PLClangCursorVisitContinue;

            if (cursor.isReference)
                return PLClangCursorVisitContinue;

            symbols[cursor.displayName] = cursor;
            
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
        api = symbols;

        /* Fetch all PCI sromvars */
        auto nvars = std::make_shared<std::vector<nvar>>();
        PLClangCursor *tbl = api[@"pci_sromvars"];
        if (tbl == nil)
            errx(EXIT_FAILURE, "missing pci_sromvars");
        for (PLClangCursor *init in get_array_inits(tbl)) {
            nvar n;
            if (extract_struct(tu, init, &n))
                nvars->push_back(n);
        }

        /* Coalesce continuations */
        nvars = coalesce(nvars);
        
        std::unordered_map<std::string, std::shared_ptr<bhnd_nvram_var>> var_table;
        std::vector<std::shared_ptr<bhnd_nvram_var>> vars;
        std::unordered_map<std::string, symbolic_constant> consts;

        for (size_t i = 0; i < nvars->size(); i++) {
            nvar *n = &(*nvars)[i];
            
            /* Record symbolic constants that we'll need to preserve */
            auto refconst = n->off.referenced_constants();
            for (const auto &rc : refconst) {
                if (consts.count(rc.name()) == 0)
                    consts.insert({rc.name(), rc});
            }

            std::string name = n->name.UTF8String;
            uint32_t revmask = n->revmask;
            uint32_t flags = n->flags;

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
            bhnd_sprom_value base_val;
            bhnd_sprom_vseg base_seg = {
                n->byte_off(),
                n->width(),
                n->valmask,
                static_cast<ssize_t>(__builtin_ctz(n->valmask))
            };

            base_val.segs.push_back(base_seg);
            size_t more_width = n->width();
            while (n->flags & SRFL_MORE) {
                i++;
                n = &(*nvars)[i];
                
                base_val.segs.push_back({
                    n->byte_off(),
                    n->width(),
                    n->valmask,
                    static_cast<ssize_t>(__builtin_ctz(n->valmask) - (more_width * 8))
                });

                more_width += n->width();
            }
            vals.push_back(base_val);

            while (n->flags & SRFL_ARRAY) {
                bhnd_sprom_value val;

                i++;
                n = &(*nvars)[i];

                val.segs.push_back({
                    n->byte_off(),
                    n->width(),
                    n->valmask,
                    static_cast<ssize_t>(__builtin_ctz(n->valmask))
                });

                more_width = n->width();
                while (n->flags & SRFL_MORE) {
                    i++;
                    n = &(*nvars)[i];
                    
                    val.segs.push_back({
                        n->byte_off(),
                        n->width(),
                        n->valmask,
                        static_cast<ssize_t>(__builtin_ctz(n->valmask) - (more_width * 8))
                    });
                    
                    more_width += n->width();
                }
                
                vals.push_back(val);
            }

            int ctz = __builtin_ctz(revmask);
            uint16_t first_ver = (1UL << ctz);
            uint16_t last_ver = revmask | (((~revmask) << (sizeof(revmask)*8 - ctz)) >> (sizeof(revmask)*8 - ctz));
            
            v->sprom_descs.push_back({{first_ver, last_ver}, vals});
        }

    #if 1
        for (const auto &v : vars) {
            printf("%s:\n", v->name.c_str());
            for (const auto &t : v->sprom_descs) {
                printf("\trevs 0x%04X - 0x%04X\n", t.compat.first, t.compat.last);
                size_t idx = 0;
                for (const auto &val : t.values) {
                    printf("\t\t%s[%zu]\n", v->name.c_str(), idx);
                    for (const auto &seg : val.segs) {
                        printf("\t\t  seg offset=0x%04zX width=%zu mask=0x%08X shift=%zd\n", seg.offset, seg.width, seg.mask, seg.shift);
                    }
                    idx++;
                }
            }
        }
    #endif
    }
};

int
main (int argc, char * const argv[])
{
    @autoreleasepool {
        Extractor(argc, argv);
        return (0);
    }
}