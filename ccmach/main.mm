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

static uint32_t     compute_literal_u32(PLClangTranslationUnit *tu, NSArray *tokens);
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
        raw_value = compute_literal_u32(tu, tokens);
        
        /** bcmsrom offsets assume 16-bit pointer arithmetic */
        raw_byte_offset = raw_value * sizeof(uint16_t);
    }

    vector<string> referenced_constants () {
        vector<string> ret;
        
        if (virtual_base)
            ret.push_back(virtual_base.UTF8String);
        
        for (PLClangToken *t in tokens) {
            switch (t.kind) {
                case PLClangTokenKindIdentifier:
                    ret.push_back(t.spelling.UTF8String);
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
    BHND_NVRAM_DT_CCODE,	/**< country code format (2-3 ASCII chars) */
} bhnd_nvram_dt;

/** NVRAM data type string representations */
typedef enum {
    BHND_NVRAM_SFMT_HEX,		/**< hex string format */
    BHND_NVRAM_SFMT_SDEC,		/**< signed decimal format */
    BHND_NVRAM_SFMT_MACADDR,	/**< mac address (canonical form, hex octets,
                                 seperated with ':') */
    BHND_NVRAM_SFMT_ASCII		/**< ASCII string */
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
    
    const char *width_str () const {
        switch (width) {
            case 1:
                return "u8";
            case 2:
                return "u16";
            case 4:
                return "u32";
            default:
                errx(EXIT_FAILURE, "Unsupported width: %zu", width);
        }
    }
    
    bool has_default_mask () const {
        switch (width) {
            case 1:
                return (mask == 0xFF);
            case 2:
                return (mask == 0xFFFF);
            case 4:
                return (mask == 0xFFFFFFFF);
            default:
                errx(EXIT_FAILURE, "Unsupported width: %zu", width);
        }
    }
    
    bool has_default_shift () const {
        return (shift == 0);
    }

    bool has_defaults () const {
        return (has_default_mask() && has_default_shift());
    }
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
    
    
    bool operator < (const bhnd_nvram_var &other) const {
        return ([@(name.c_str()) compare:@(other.name.c_str()) options:NSNumericSearch] == NSOrderedAscending);
    }
};


static id<NSObject> get_literal(PLClangTranslationUnit *tu, PLClangToken *t);

static PLClangToken *
resolve_pre(PLClangTranslationUnit *tu, PLClangToken *t) {
    PLClangCursor *def;
    if (t.cursor.referencedCursor != nil)
        def = t.cursor.referencedCursor;
    else
        def = t.cursor;

    NSArray *tokens = [tu tokensForSourceRange: def.extent];
    
    if (tokens.count < 2)
        errx(EXIT_FAILURE, "macro def %s unsupported token count %lu", t.spelling.UTF8String, (unsigned long)tokens.count);

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
compute_literal_u32(PLClangTranslationUnit *tu, NSArray *tokens)
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
    uint32_t revmask = compute_literal_u32(tu, grouped[1]);
    uint32_t flags = compute_literal_u32(tu, grouped[2]);
    symbolic_offset off(tu, (NSArray *) grouped[3]);
    uint32_t valmask = compute_literal_u32(tu, grouped[4]);

    *nout = nvar(name, revmask, flags, off, valmask);
    return true;
}

static const char *dtstr (bhnd_nvram_dt dt) {
    switch (dt) {
        case BHND_NVRAM_DT_UINT: return "uint";
        case BHND_NVRAM_DT_SINT: return "sint";
        case BHND_NVRAM_DT_MAC48: return "mac48";
        case BHND_NVRAM_DT_LEDDC: return "led";
        case BHND_NVRAM_DT_CCODE: return "cc";
    }
}

static const char *sfmtstr (bhnd_nvram_sfmt sfmt) {
    switch (sfmt) {
        case BHND_NVRAM_SFMT_HEX: return "hex";
        case BHND_NVRAM_SFMT_SDEC: return "sdec";
        case BHND_NVRAM_SFMT_MACADDR: return "macaddr";
        case BHND_NVRAM_SFMT_ASCII: return "ascii";
    }
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

    shared_ptr<vector<nvar>> extract_nvars (NSString *symbol) {
        auto nvars = std::make_shared<std::vector<nvar>>();
        
        /* Fetch all sromvars */
        PLClangCursor *tbl = api[symbol];
        if (tbl == nil)
            errx(EXIT_FAILURE, "missing %s", symbol.UTF8String);
        for (PLClangCursor *init in get_array_inits(tbl)) {
            nvar n;
            if (extract_struct(tu, init, &n))
                nvars->push_back(n);
        }
        
        /* Coalesce continuations */
        return coalesce(nvars);
    }

    NSArray *get_tokens (PLClangCursor *cursor) {
        return [tu tokensForSourceRange: cursor.extent];
    }
    
    int _depth = 0;
    int dprintf(const char *fmt, ...) {
        va_list vap;
   
        for (int i = 0; i < _depth; i++)
            printf("\t");

        va_start(vap, fmt);
        int r = vprintf(fmt, vap);
        va_end(vap);
        return r;
    }
    
    void output_vars (const vector<shared_ptr<bhnd_nvram_var>> &vars) {
        for (const auto &v : vars) {
            if (v->flags & BHND_NVRAM_VF_MFGINT)
                printf("private ");
            
            dprintf("%s %s", dtstr(v->type), v->name.c_str());
            
            if (v->flags & BHND_NVRAM_VF_ARRAY)
                printf("[]");
            
            printf(" {\n");
            _depth++;
            
            dprintf("sfmt\t%s\n", sfmtstr(v->fmt));
            if (v->flags & BHND_NVRAM_VF_IGNALL1)
                dprintf("all1\tignore\n");
            
            for (const auto &t : v->sprom_descs) {
                dprintf("revs ");
                if (t.compat.last == BHND_SPROMREV_MAX)
                    printf(">= %u", t.compat.first);
                else if (t.compat.first == t.compat.last)
                    printf("%u", t.compat.first);
                else
                    printf("%u-%u", t.compat.first, t.compat.last);
                
                size_t vlines = 0;
                for (const auto &val : t.values) {
                    for (__unused const auto &seg : val.segs) {
                        vlines++;
                    }
                }
                if (vlines <= 1) {
                    printf("\t{ ");
                } else {
                    printf(" {\n");
                    _depth++;
                }
                
                size_t vali = 0;
                for (const auto &val : t.values) {
                    for (size_t i = 0; i < val.segs.size(); i++) {
                        const auto &seg = val.segs[i];
                        
                        if (vlines > 1)
                            dprintf("");
                        printf("%s 0x%04zX", seg.width_str(), seg.offset);
                        if (!seg.has_defaults()) {
                            printf(" (");
                            if (!seg.has_default_mask()) {
                                printf("&0x%X", seg.mask);
                                if (!seg.has_default_shift())
                                    printf(", ");
                            }
                            if (!seg.has_default_shift()) {
                                if (seg.shift < 0)
                                    printf("<<%zu", -seg.shift);
                                else
                                    printf(">>%zu", seg.shift);
                            }
                            printf(")");
                        }
                        
                        if (i+1 != val.segs.size())
                            printf(" |\n");
                        else if (vlines > 1 && vali+1 != t.values.size())
                            printf(",\n");
                    }
                    vali++;
                }
                if (vlines <= 1)
                    printf(" }\n");
                else {
                    printf("\n");
                    _depth--;
                    dprintf("}\n");
                }
            }
            _depth--;
            dprintf("}\n\n");
        }
    }

    vector<shared_ptr<bhnd_nvram_var>> convert_nvars (shared_ptr<vector<nvar>> &nvars) {
        unordered_map<string, shared_ptr<bhnd_nvram_var>> var_table;
        vector<shared_ptr<bhnd_nvram_var>> vars;
        unordered_set<string> consts;
        
        for (size_t i = 0; i < nvars->size(); i++) {
            nvar *n = &(*nvars)[i];
            
            /* Record symbolic constants that we'll need to preserve */
            auto refconst = n->off.referenced_constants();
            for (const auto &rc : refconst) {
                if (consts.count(rc) == 0)
                    consts.insert(rc);
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
                v->type = BHND_NVRAM_DT_CCODE;
                v->fmt = BHND_NVRAM_SFMT_ASCII;
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
                
                if (orig->flags != v->flags) {
                    /* VF_ARRAY mismatch is OK, but nothing else is */
                    if ((orig->flags & ~BHND_NVRAM_VF_ARRAY) != (v->flags & ~BHND_NVRAM_VF_ARRAY))
                        errx(EXIT_FAILURE, "%s: flag mismatch (0x%X vs. 0x%X)", name.c_str(), orig->flags, v->flags);
                    
                    /* Promote to an array */
                    orig->flags |= BHND_NVRAM_VF_ARRAY;
                }
                
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
        
        return vars;
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

        /* Output all PCI sromvars */
        auto nvars = extract_nvars(@"pci_sromvars");
        auto vars = convert_nvars(nvars);
        output_vars(vars);

        /* Output the per-path vars */
        auto path_nvars = extract_nvars(@"perpath_pci_sromvars");
        auto path_vars = convert_nvars(path_nvars);

        struct pathcfg {
            NSString *path_pfx;
            NSString *path_num;
            const char *revdesc;
        } pathcfgs[] = {
            { @"SROM4_PATH",    @"MAX_PATH_SROM",       "revs 4-7" },
            { @"SROM8_PATH",    @"MAX_PATH_SROM",       "revs 8-10" },
            { @"SROM11_PATH",   @"MAX_PATH_SROM_11",    "revs >= 11" },
            { nil, nil }
        };

        printf("#\n"
                "# Any variables defined within a `struct` block will be interpreted relative to\n"
                "# the provided array of SPROM base addresses; this is used to define\n"
                "# a common layout defined at the given base addresses.\n"
                "#\n"
                "# To produce SPROM variable names matching those used in the Broadcom HND\n"
                "# ASCII 'key=value\\0' NVRAM, the index number of the variable's\n"
                "# struct instance will be appended (e.g., given a variable of noiselvl5ga, the\n"
                "# generated variable instances will be named noiselvl5ga0, noiselvl5ga1,\n"
                "# noiselvl5ga2, noiselvl5ga3 ...)\n"
                "#\n");
        printf("struct pathvars[] {\n");
        _depth++;
        
        for (auto cfg = pathcfgs; cfg->path_pfx != nil; cfg++) {
            PLClangCursor *maxCursor = api[cfg->path_num];
            if (maxCursor == nil)
                errx(EXIT_FAILURE, "missing %s", cfg->path_num.UTF8String);
            uint32_t max = compute_literal_u32(tu, get_tokens(maxCursor));
    
            dprintf("%s\t[", cfg->revdesc);
            for (uint32_t i = 0; i < max; i++) {
                NSString *path = [NSString stringWithFormat: @"%@%u", cfg->path_pfx, i];
                PLClangCursor *c = api[path];
                if (c == nil)
                    errx(EXIT_FAILURE, "missing %s", path.UTF8String);
                uint32_t offset = compute_literal_u32(tu, get_tokens(c));
                printf("0x%04zX", offset*sizeof(uint16_t));
                if (i+1 != max)
                    printf(", ");
            }
            printf("]\n");
        }
        
        printf("\n");
        output_vars(path_vars);
        
        _depth--;
        dprintf("}\n");

#if 0
        auto path_nvars = generate_path_vars();
        nvars->reserve(nvars->size() + path_nvars->size());
        nvars->insert(nvars->end(), path_nvars->begin(), path_nvars->end());

        sort(vars.begin(), vars.end(), [](const shared_ptr<bhnd_nvram_var> &lhs, const shared_ptr<bhnd_nvram_var> &rhs) {
            return *lhs < *rhs;
        });
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