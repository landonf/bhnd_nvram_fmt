//
//  main.mm
//  ccmach
//
//  Created by Landon Fuller on 12/31/15.
//  Copyright (c) 2015 Landon Fuller. All rights reserved.
//

#include "nvram.hpp"

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


using namespace std;

class Compiler {
private:
    PLClangSourceIndex *_idx;
    PLClangTranslationUnit *_tu;
    NSDictionary *_symbols;

public:
    PLClangCursor *translationUnit (void) {
        return _tu.cursor;
    }

    PLClangCursor *find_symbol (const string &name) {
        return _symbols[@(name.c_str())];
    }

    nvram::symbolic_constant resolve_constant (const string &name) {
        PLClangCursor *c = find_symbol(name);
        if (c == nil)
            errx(EXIT_FAILURE, "can't find constant named %s", name.c_str());
        
        auto val = tokens_literal_u32(get_tokens(c));
        return nvram::symbolic_constant(name, val);
    }
    
    NSArray *get_tokens (PLClangCursor *cursor) {
        return [_tu tokensForSourceRange: cursor.extent];
    }
    
    PLClangToken *
    resolve_macro_def(PLClangToken *t) {
        PLClangCursor *def;
        if (t.cursor.referencedCursor != nil)
            def = t.cursor.referencedCursor;
        else
            def = t.cursor;
        
        NSArray *tokens = [_tu tokensForSourceRange: def.extent];
        
        if (tokens.count < 2)
            errx(EXIT_FAILURE, "macro def %s unsupported token count %lu", t.spelling.UTF8String, (unsigned long)tokens.count);
        
        return tokens[1];
    }
    
    /* Return the cursors composing the given array's initializers */
    NSArray *
    get_array_inits (PLClangCursor *tbl) {
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

    id<NSObject>
    token_literal(PLClangToken *t) {
        if (t.kind == PLClangTokenKindIdentifier && t.cursor.isPreprocessing)
            return token_literal(resolve_macro_def(t));
        
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
            case PLClangCursorKindStringLiteral:
            case PLClangCursorKindCharacterLiteral: {
                NSString *lit = t.spelling;
                lit = [lit substringFromIndex: 1];
                lit = [lit substringToIndex: lit.length - 1];
                return lit;
            }
            default:
                return nil;
        }
    }

    string token_literal_string (PLClangToken *token) {
        id<NSObject> value = token_literal(token);
        if (value == nil)
            errx(EX_DATAERR, "can't fetch literal value for %s", token.spelling.UTF8String);
        
        if ([value isKindOfClass: [NSString class]]) {
            return ((NSString *)(value)).UTF8String;
        } else {
            errx(EX_DATAERR, "%s is not a string literal", token.spelling.UTF8String);
        }
    }
    
    uint32 token_literal_u32 (PLClangToken *token) {
        id<NSObject> value = token_literal(token);
        if (value == nil)
            errx(EX_DATAERR, "can't fetch literal value for %s", token.spelling.UTF8String);
        
        if ([value isKindOfClass: [NSNumber class]]) {
            return [((NSNumber *)(value)) unsignedIntValue];
        } else {
            errx(EX_DATAERR, "%s is not an integer literal", token.spelling.UTF8String);
        }
    }
    
    uint32_t
    tokens_literal_u32 (NSArray *tokens)
    {
        uint32_t v = 0;
        char op = '\0';
        
        if (tokens.count == 0)
            errx(EXIT_FAILURE, "empty token list");
        
        for (__strong PLClangToken *t in tokens) {
            if (t.kind == PLClangTokenKindIdentifier) {
                t = resolve_macro_def(t);

            } else if (t.kind == PLClangTokenKindComment) {
                continue;
            }
            
            switch (t.kind) {
                case PLClangTokenKindLiteral: {
                    uint32_t nv = token_literal_u32(t);
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
                    errx(EXIT_FAILURE, "Unsupported token type: %u", (unsigned int) t.kind);
            }
        }
        
        return v;
    }

    Compiler () {}

    Compiler (NSArray *arguments) {
        NSError *error;
    
        _idx = [PLClangSourceIndex indexWithOptions: PLClangIndexCreationDisplayDiagnostics];
        _tu = [_idx addTranslationUnitWithCompilerArguments: arguments
                                                    options: PLClangTranslationUnitCreationDetailedPreprocessingRecord
                                                      error: &error];
        if (_tu == nil)
            errx(EXIT_FAILURE, "%s", error.description.UTF8String);
        
        if (_tu.didFail)
            errx(EXIT_FAILURE, "parse failed");
        
        /* Map symbol names to their definitions */
        auto symbols = [NSMutableDictionary dictionary];
        [_tu.cursor visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
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
        _symbols = symbols;
    }
};

/* A parsed SPROM record from the vendor header file */
struct nvar {
    NSString *name;
    uint32_t revmask;
    uint32_t flags;
    size_t off;
    uint32_t valmask;
    size_t width;

    nvar () {}
    nvar (NSString *n,
          uint32_t _revmask,
          uint32_t _flags,
          size_t _off,
          uint32_t _valmask) : name(n), revmask(_revmask), flags(_flags), off(_off), valmask(_valmask)
    {
        if (valmask & 0xFFFF0000)
            width = 4;
        else if (valmask & 0x0000FF00)
            width = 2;
        else
            width = 1;
    }
private:
    nvram::prop_type uint_type () {
        switch (width) {
            case 1: return nvram::BHND_T_UINT8;
            case 2: return nvram::BHND_T_UINT16;
            case 4: return nvram::BHND_T_UINT32;
            default: errx(EX_DATAERR, "unknown width %zu", width);
        }
    }
    
    nvram::prop_type int_type () {
        switch (width) {
            case 1: return nvram::BHND_T_INT8;
            case 2: return nvram::BHND_T_INT16;
            case 4: return nvram::BHND_T_INT32;
            default: errx(EX_DATAERR, "unknown width %zu", width);
        }
    }
public:
    
    nvram::prop_type get_type () {
        if (flags & SRFL_CCODE) {
            return nvram::BHND_T_CHAR;
        } else if (flags & SRFL_ETHADDR) {
            return nvram::BHND_T_UINT8;
        } else if (flags & SRFL_LEDDC) {
            return nvram::BHND_T_UINT8;
        } else if (flags & SRFL_PRSIGN) {
            return int_type();
        } else if (flags & SRFL_PRHEX) {
            return uint_type();
        } else {
            /* Default behavior */
            return uint_type();
        }
    }
    
    nvram::str_fmt get_sfmt() {
        if (flags & SRFL_CCODE) {
            return nvram::SFMT_CCODE;
        } else if (flags & SRFL_ETHADDR) {
            return nvram::SFMT_MACADDR;
        } else if (flags & SRFL_LEDDC) {
            return nvram::SFMT_LEDDC;
        } else if (flags & SRFL_PRSIGN) {
            return nvram::SFMT_DECIMAL;
        } else if (flags & SRFL_PRHEX) {
            return nvram::SFMT_HEX;
        } else {
            /* Default behavior */
            return nvram::SFMT_HEX;
        }
    }
    
    size_t nvram_count() {
        if (flags & SRFL_CCODE) {
            return 2;
        } else if (flags & SRFL_ETHADDR) {
            return 48;
        } else if (flags & SRFL_LEDDC) {
            return 2;
        } else {
            return 1;
        }
    }

    uint32_t nvram_flags() {
        uint32_t ret = 0;
        if (flags & SRFL_NOVAR)
            ret |= nvram::FLAG_MFGINT;
        if (flags & SRFL_NOFFS)
            ret |= nvram::FLAG_NOALL1;
        return (ret);
    }
};

class Extractor {
private:
    shared_ptr<Compiler> _c;

    /**
     * Coalesce unnecessary continuations in nvars
     */
    shared_ptr<vector<nvar>> coalesce (shared_ptr<vector<nvar>> &nvars) {
        auto clean_nvars = make_shared<vector<nvar>>();

        for (size_t i = 0; i < nvars->size(); i++) {
            const nvar &n = (*nvars)[i];
            
            std::string name = n.name.UTF8String;
            uint32_t flags = n.flags;
            uint16_t offset = n.off;
            size_t width = n.width;
            uint32_t valmask = n.valmask;
            
            /* Unify unnecessary continuations */
            const nvar *c = &n;
            while (c->flags & SRFL_MORE) {
                i++;
                c = &(*nvars)[i];
                
                /* Can't unify sparse continuations */
                if (c->off != offset + width) {
                    warnx("%s: sparse continuation (%zx, %zx)", name.c_str(), c->off, offset+width);
                    i--;
                    break;
                }
                
                if (c->revmask != 0 && c->revmask != n.revmask)
                    errx(EXIT_FAILURE, "%s: continuation has non-matching revmask", name.c_str());
                
                if (c->valmask != 0xFFFF)
                    errx(EXIT_FAILURE, "%s: unsupported valmask: 0x%X", name.c_str(), c->valmask);
                
                width += c->width;
                valmask <<= c->width*8;
                valmask |= c->valmask;
                flags &= ~SRFL_MORE;
            }
            
            clean_nvars->emplace_back(n.name, n.revmask, flags, n.off, valmask);
        }
        
        return clean_nvars;
    }
    
    bool
    extract_srom_struct(PLClangCursor *c, nvar *nout) {
        NSMutableArray *tokens = [_c->get_tokens(c) mutableCopy];
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
        
        NSString *name = (NSString *) _c->token_literal(nameToken);
        uint32_t revmask = _c->tokens_literal_u32(grouped[1]);
        uint32_t flags = _c->tokens_literal_u32(grouped[2]);
        uint16_t raw_off = _c->tokens_literal_u32(grouped[3]);
        uint32_t valmask = _c->tokens_literal_u32(grouped[4]);
        
        uint16_t byte_off = raw_off * sizeof(uint16_t);
        
        
        if (valmask & 0xFF00) {
            if (!(valmask & 0x00FF)) {
                valmask >>= 8;
            }
        } else if (valmask & 0x00FF) {
            byte_off++;
        }
        
        *nout = nvar(name, revmask, flags, byte_off, valmask);
        return true;
    }

    shared_ptr<vector<nvar>> extract_nvars (NSString *symbol) {
        auto nvars = std::make_shared<std::vector<nvar>>();
        
        /* Fetch all sromvars */
        PLClangCursor *tbl = _c->find_symbol(symbol.UTF8String);
        if (tbl == nil)
            errx(EXIT_FAILURE, "missing %s", symbol.UTF8String);
        for (PLClangCursor *init in _c->get_array_inits(tbl)) {
            nvar n;
            if (extract_srom_struct(init, &n))
                nvars->push_back(n);
        }
        
        /* Coalesce continuations */
        return coalesce(nvars);
    }
    
    vector<shared_ptr<nvram::var>> convert_nvars (shared_ptr<vector<nvar>> &nvars) {
        unordered_map<string, shared_ptr<nvram::var>> var_table;
        vector<shared_ptr<nvram::var>> ret;

        for (size_t i = 0; i < nvars->size(); i++) {
            nvar *n = &(*nvars)[i];
            
            std::string name = n->name.UTF8String;
            
            if (name.length() == 0)
                errx(EXIT_FAILURE, "variable has zero-length name");

            auto v = make_shared<nvram::var>(name, n->get_type(), n->get_sfmt(), 0 /* array count */, n->nvram_flags(), make_shared<vector<nvram::sprom_offset>>());
            
            /* Compare against previous variable with this name, or
             * register the new variable */
            if (var_table.count(name) == 0) {
                var_table.insert({name, v});
            } else {
                auto orig = var_table.at(name);
                
                if (!nvram::prop_type_compat(orig->type(), v->type())) {
                    errx(EX_DATAERR, "%s: type mismatch (%u vs %u)", name.c_str(), orig->type(), v->type());
                }

                if (orig->sfmt() != v->sfmt())
                    errx(EX_DATAERR, "fmt mismatch");
                
                if (orig->flags() != v->flags())
                    errx(EX_DATAERR, "%s: flag mismatch (0x%X vs. 0x%X)", name.c_str(), orig->flags(), v->flags());

                /* array size may only increase */
                if (v->count() < orig->count())
                    *v = v->count(orig->count());
                
                /* type width may only increase */
                if (v->type() < orig->type())
                    *v = v->type(orig->type());

                *v = v->sprom_offsets(orig->sprom_offsets());
                var_table.insert({name, v});
            }
            
            /* Handle array/sparse continuation records */
            auto vals = make_shared<vector<nvram::value>>();
            nvram::value base_val(make_shared<vector<nvram::value_seg>>());
            nvram::value_seg base_seg = {
                n->off,
                n->get_type(),
                n->nvram_count(),
                n->valmask,
                static_cast<ssize_t>(__builtin_ctz(n->valmask))
            };
            
            base_val.segments()->push_back(base_seg);
            size_t more_width = n->width;
            while (n->flags & SRFL_MORE) {
                i++;
                n = &(*nvars)[i];
                base_val.segments()->emplace_back(n->off, n->get_type(), 1, n->valmask, static_cast<ssize_t>(__builtin_ctz(n->valmask) - (more_width * 8)));
                
                more_width += n->width;
            }
            vals->push_back(base_val);
            
            while (n->flags & SRFL_ARRAY) {
                nvram::value val(make_shared<vector<nvram::value_seg>>());
                
                i++;
                n = &(*nvars)[i];
                
                val.segments()->emplace_back(
                    n->off,
                    n->get_type(),
                    1,
                    n->valmask,
                    static_cast<ssize_t>(__builtin_ctz(n->valmask))
                );
                
                more_width = n->width;
                while (n->flags & SRFL_MORE) {
                    i++;
                    n = &(*nvars)[i];
                    
                    val.segments()->emplace_back(
                        n->off,
                        n->get_type(),
                        1,
                        n->valmask,
                        static_cast<ssize_t>(__builtin_ctz(n->valmask) - (more_width * 8))
                    );
                    
                    more_width += n->width;
                }
                
                vals->push_back(val);
            }
            
            nvram::sprom_offset sp_off(nvram::compat_range::from_revmask(n->revmask), vals);
            v->sprom_offsets()->push_back(sp_off);
        }

        for (const auto &v : var_table)
            ret.push_back(v.second);
        return ret;
    }
    
    struct vstr_decl {
        vector<nvram::cis_vstr> elems;
    };
    
    struct cis_tuple {
        nvram::symbolic_constant tag;
        vector<nvram::cis_vstr> vars;
        
        cis_tuple (const nvram::symbolic_constant t) : tag(t) {}
    };
    
    NSString *apply_fmt_lits (NSString *fmt, NSArray *fmtargs) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: @"%(x|X|d|z|u|c)" options: 0 error: NULL];
        if ([regex numberOfMatchesInString: fmt options:0 range:NSMakeRange(0, fmt.length)] == 0)
            return fmt;

        NSMutableString *varstr = [NSMutableString string];
        __block NSUInteger last_loc = 0;
        __block NSUInteger idx = 0;
        
        [regex enumerateMatchesInString: fmt options: 0 range: NSMakeRange(0, fmt.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            [varstr appendString: [fmt substringWithRange: NSMakeRange(last_loc, result.range.location - last_loc)]];
            last_loc = NSMaxRange(result.range);

            NSArray *tokes = _c->get_tokens(fmtargs[idx]);
            PLClangToken *arg = tokes[0];
            NSUInteger tcount = tokes.count;
            if (tokes.count <= 2 && arg.kind == PLClangTokenKindIdentifier) {
                tokes = _c->get_tokens(arg.cursor.definition);
                if (tokes.count >= 3) {
                    NSUInteger pos = tokes.count-1-2;
                    if ([[tokes[pos] spelling] isEqual: @"="]) {
                        if ([(PLClangToken *)tokes[pos+1] kind] == PLClangTokenKindLiteral) {
                            arg = tokes[pos+1];
                            tcount = 2;
                        }
                    }
                }
            }
            
            if (tcount > 2 || arg.kind != PLClangTokenKindLiteral || _c->token_literal(arg) == nil) {
                [varstr appendString: [fmt substringWithRange: result.range]];
            } else {
                [varstr appendString: [_c->token_literal(arg) description]];
            }
            
            idx++;
        }];

        [varstr appendString: [fmt substringWithRange: NSMakeRange(last_loc, fmt.length - last_loc)]];
        return varstr;
    }

    vstr_decl extract_vstr (nvram::symbolic_constant tag, PLClangCursor *def, NSArray *fmtargs, uint32_t asserted_revmask) {
        __block vstr_decl ret;

        [def visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
            switch (cursor.kind) {
                case PLClangCursorKindStringLiteral: {
                    NSString *var_fmt;
                    NSString *val_fmt;
                    NSString *lit = (NSString *)_c->token_literal(_c->get_tokens(cursor)[0]);
                    NSArray *lits = [lit componentsSeparatedByString: @"="];
                    var_fmt = apply_fmt_lits(lits[0], fmtargs);
                    val_fmt = lits[1];
                    
                    ret.elems.emplace_back(tag, var_fmt.UTF8String, val_fmt.UTF8String, def.spelling.UTF8String, asserted_revmask);
                    break;
                }
                case PLClangCursorKindInitializerListExpression: {
                    for (PLClangToken *t in _c->get_tokens(cursor)) {
                        
                        switch (t.kind) {
                            case PLClangTokenKindLiteral: {
                                NSString *var_fmt;
                                NSString *val_fmt;
                                NSString *lit = (NSString *)_c->token_literal(t);
                                NSArray *lits = [lit componentsSeparatedByString: @"="];
                                var_fmt = apply_fmt_lits(lits[0], fmtargs);
                                val_fmt = lits[1];
                                
                                ret.elems.emplace_back(tag, var_fmt.UTF8String, val_fmt.UTF8String, def.spelling.UTF8String, asserted_revmask);
                                break;
                            } default:
                                break;
                        }
                    }
                    break;
                } case PLClangCursorKindIntegerLiteral:
                    break;
                default:
                    errx(EXIT_FAILURE, "unsupported kind %u", (unsigned int) cursor.kind);
            }
            return PLClangCursorVisitContinue;
        }];
        
        return ret;
    }
    
    vector<shared_ptr<cis_tuple>> extract_cis_tuples () {
        PLClangCursor *srom_parsecis = _c->find_symbol("srom_parsecis(osl_t *, uint8 **, uint, char **, uint *)");
        if (srom_parsecis == nil)
            errx(EXIT_FAILURE, "srom_parsecis() not found");
        
        __block NSString *hnbu_sect = nil;
        __block vector<shared_ptr<cis_tuple>> cis_tuples;
        __block shared_ptr<cis_tuple> tuple;
        __block uint32_t asserted_revmask = 0;
        
        [srom_parsecis visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
            if (cursor.kind == PLClangCursorKindSwitchStatement) {
                [cursor visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
                    if (cursor.kind == PLClangCursorKindCaseStatement) {
                        PLClangToken *caseval = _c->get_tokens(cursor)[1];
                        if ([caseval.spelling hasPrefix: @"HNBU_"] || [caseval.spelling hasPrefix: @"CISTPL_"]) {
                            hnbu_sect = caseval.spelling;

                            asserted_revmask = 0;
                            tuple = make_shared<cis_tuple>(_c->resolve_constant(hnbu_sect.UTF8String));
                            cis_tuples.push_back(tuple);
                        }
                    } else if (cursor.kind == PLClangCursorKindCallExpression) {
                        NSString *fn = cursor.spelling;
                        if ([fn isEqual: @"varbuf_append"]) {
                            NSArray *args = cursor.arguments;
                            NSArray *vap = [args subarrayWithRange: NSMakeRange(2, args.count - 2)];
                            PLClangCursor *vs_arg = args[1];
                            
                            if (vs_arg.kind == PLClangCursorKindVariableReference || vs_arg.kind == PLClangCursorKindDeclarationReferenceExpression) {
                                if ([vs_arg.spelling hasPrefix: @"vstr_"]) {
                                    auto vstr = extract_vstr(tuple->tag, vs_arg.definition, vap, asserted_revmask);
                                    if (vstr.elems.size() != 1)
                                        errx(EXIT_FAILURE, "parsed too-large vstr: %s", vs_arg.definition.spelling.UTF8String);
                                    
                                    tuple->vars.push_back(vstr.elems[0]);
                                }
                            } else {
                                [vs_arg visitChildrenUsingBlock: ^PLClangCursorVisitResult(PLClangCursor *cursor) {
                                    if (cursor.kind == PLClangCursorKindArraySubscriptExpression) {
                                        auto tokens = _c->get_tokens(cursor);
                                        PLClangToken *base = tokens[0];
                                        PLClangToken *subscript = tokens[2];
                                        if ([base.spelling hasPrefix: @"vstr_"]) {
                                            uint32_t start, finish;
                                            string vstr_name = string(base.spelling.UTF8String);
                                            auto vstr = extract_vstr(tuple->tag, base.cursor.definition, vap, asserted_revmask);

                                            if (_c->token_literal(subscript) == nil) {
                                                if ((tuple->tag.name() == "HNBU_PAPARMS" && (vstr_name == "vstr_pa0b" || vstr_name == "vstr_pa0b_lo")) ||
                                                    (tuple->tag.name() == "HNBU_PAPARMS5G" && (vstr_name == "vstr_pa1b" || vstr_name == "vstr_pa1lob" || vstr_name == "vstr_pa1hib"))
                                                ) {
                                                    start = 0;
                                                    finish = 3;
                                                } else if (tuple->tag.name() == "HNBU_LEGOFDMBW205GPO" && vstr_name == "vstr_legofdmbw205gpo") {
                                                    start = 0;
                                                    finish = 6;
                                                } else if (tuple->tag.name() == "HNBU_MCS2GPO" && vstr_name == "vstr_mcs2gpo") {
                                                    start = 0; finish = 3;
                                                } else if (tuple->tag.name() == "HNBU_MCS5GLPO" && vstr_name == "vstr_mcs5glpo") {
                                                    start = 0; finish = 3;
                                                } else if (tuple->tag.name() == "HNBU_MCS5GMPO" && vstr_name == "vstr_mcs5gmpo") {
                                                    start = 0; finish = 3;
                                                } else if (tuple->tag.name() == "HNBU_MCS5GHPO" && vstr_name == "vstr_mcs5ghpo") {
                                                    start = 0; finish = 3;
                                                } else {
                                                    errx(EXIT_FAILURE, "can't parse subscript for %s %s", tuple->tag.name().c_str(), base.spelling.UTF8String);
                                                }
                                            } else {
                                                start = (uint32_t) _c->token_literal_u32(subscript);
                                                finish = start+1;
                                            }
                                            for (uint32_t i = start; i < finish; i++) {
                                                auto e = vstr.elems[i];
                                                tuple->vars.push_back(e);
                                            }
                                            
                                            
                                            return PLClangCursorVisitContinue;
                                        }
                                    }
                                    
                                    if (cursor.kind == PLClangCursorKindVariableReference || cursor.kind == PLClangCursorKindDeclarationReferenceExpression) {
                                        if ([cursor.spelling hasPrefix: @"vstr_"]) {
                                            auto vstr = extract_vstr(tuple->tag, cursor.definition, vap, asserted_revmask);
                                            tuple->vars.insert(tuple->vars.end(), vstr.elems.begin(), vstr.elems.end());
                                        }
                                    }
                                    return PLClangCursorVisitRecurse;
                                }];
                            }
                        } else if ([fn isEqual: @"ASSERT"]) {
                            NSArray *args = _c->get_tokens(cursor);
                            args = [args subarrayWithRange: NSMakeRange(2, args.count - 4)];
                            if ([[args[0] spelling] isEqual: @"sromrev"] || [[args[1] spelling] isEqual: @"sromrev"]) {
                                NSArray *sep = [[[[[args componentsJoinedByString: @""] stringByReplacingOccurrencesOfString: @"sromrev" withString: @""] stringByReplacingOccurrencesOfString: @"(" withString: @""] stringByReplacingOccurrencesOfString: @")" withString:@""] componentsSeparatedByString:@"||"];
                                
                                NSCharacterSet *trim = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
                                vector<nvram::compat_range> ranges;
                                for (NSString *rspec in sep) {
                                    NSString *numstr = [rspec stringByTrimmingCharactersInSet: trim];
                                    int num;
                                    if (![[NSScanner scannerWithString: numstr] scanInt: &num])
                                        errx(EXIT_FAILURE, "can't parse %s", numstr.UTF8String);
                                    
                                    if ([rspec hasPrefix: @">="]) {
                                        ranges.emplace_back(num, nvram::compat_range::MAX_SPROMREV);
                                    } else if ([rspec hasPrefix: @"<="]) {
                                        ranges.emplace_back(0, num);
                                    } else if ([rspec hasPrefix: @">"]) {
                                        ranges.emplace_back(num+1, nvram::compat_range::MAX_SPROMREV);
                                    } else if ([rspec hasPrefix: @"<"]) {
                                        ranges.emplace_back(0, num-1);
                                    } else if ([rspec hasPrefix: @"=="]) {
                                        ranges.emplace_back(num, num);
                                    } else {
                                        errx(EXIT_FAILURE, "can't parse %s", rspec.UTF8String);
                                    }
                                }

                                uint32_t revmask = 0;
                                for (const auto &r : ranges)
                                    revmask |= r.to_revmask();

                                // XXX: this is not entirely correct, in that we don't really handle
                                // independent code paths
                                if ((revmask & asserted_revmask) == 0) {
                                    asserted_revmask = revmask;
                                } else {
                                    asserted_revmask |= revmask;
                                }
    
                            } else {
                                // NSLog(@"UNHANDLED-MACRO: %@", args);
                            }
                        }
                    }
                    return PLClangCursorVisitRecurse;
                }];
                return PLClangCursorVisitContinue;
            } else {
                return PLClangCursorVisitRecurse;
            }
        }];
        
        for (auto &cs : cis_tuples) {
            size_t idx = 0;
            vector<nvram::cis_vstr> addtl;
                        
            if (cs->tag.name() == "HNBU_LEDS") {
                for (auto &vs : cs->vars) {
                    if (vs.name() != "ledbh%d")
                        errx(EXIT_FAILURE, "%s in HNBU_LEDS not handled", vs.name().c_str());
                }
                nvram::cis_vstr orig = cs->vars[0];
                cs->vars.clear();
                for (int i = 0; i < 16; i++)
                    cs->vars.emplace_back(orig.cis_tag(), string("ledbh") + to_string(i), orig.fmt_str(), orig.vstr_variable(), orig.asserted_revmask());
            }
            
            for (auto &vs : cs->vars) {
                if (cs->tag.name() == "HNBU_PO_MCS2G" && vs.name() == "mcs2gpo%d") {
                    vs = vs.name([NSString stringWithFormat: @(vs.name().c_str()), 0].UTF8String);
                    for (int i = 1; i < 8; i++) {
                        auto vap = vs.name([NSString stringWithFormat: @"mcs2gpo%d", i].UTF8String);
                        addtl.push_back(vap);
                    }
                } else if (cs->tag.name() == "HNBU_PO_MCS5GM" && vs.name() == "mcs5gpo%d") {
                    vs = vs.name([NSString stringWithFormat: @(vs.name().c_str()), 0].UTF8String);
                    for (int i = 1; i < 8; i++) {
                        auto vap = vs.name([NSString stringWithFormat: @"mcs5gpo%d", i].UTF8String);
                        addtl.push_back(vap);
                    }
                } else if (cs->tag.name() == "HNBU_PO_MCS5GLH" && vs.name() == "mcs5glpo%d") {
                    vs = vs.name([NSString stringWithFormat: @(vs.name().c_str()), 0].UTF8String);
                    for (int i = 1; i < 8; i++) {
                        auto vap = vs.name([NSString stringWithFormat: @"mcs5glpo%d", i].UTF8String);
                        addtl.push_back(vap);
                    }
                } else if (cs->tag.name() == "HNBU_PO_MCS5GLH" && vs.name() == "mcs5ghpo%d") {
                    vs = vs.name([NSString stringWithFormat: @(vs.name().c_str()), 0].UTF8String);
                    for (int i = 1; i < 8; i++) {
                        auto vap = vs.name([NSString stringWithFormat: @"mcs5ghpo%d", i].UTF8String);
                        addtl.push_back(vap);
                    }
                } else if (cs->tag.name() == "HNBU_USBSSPHY_MDIO" && vs.name() == "usbssmdio%d") {
                    // TODO
                    // XXX As many as will fit
                    vs = vs.name([NSString stringWithFormat: @(vs.name().c_str()), 0].UTF8String);
                }

                idx++;
            }
            
            if (cs->tag.name() == "HNBU_BOARDNUM") {
                // XXX: implicit; the boardnum may also be specified elsewhere
                PLClangCursor *c = _c->find_symbol("vstr_boardnum");
                if (c == nil) errx(EXIT_FAILURE, "could not find `vstr_boardnum`");
                addtl.emplace_back(cs->tag, "boardnum", "%d", "vstr_boardnum", 0);
            } else if (cs->tag.name() == "HNBU_MACADDR") {
                // XXX: may also be specified elsewhere
                PLClangCursor *c = _c->find_symbol("vstr_macaddr");
                if (c == nil) errx(EXIT_FAILURE, "could not find `vstr_macaddr`");
                addtl.emplace_back(cs->tag, "macaddr", "%d", "vstr_macaddr", 0);
            }
            
            cs->vars.insert(cs->vars.end(), addtl.begin(), addtl.end());
        }
        
        for (auto &cs : cis_tuples) {
            for (auto &vs : cs->vars) {
                if (vs.is_name_incomplete())
                    errx(EXIT_FAILURE, "unexpanded format string in %s", vs.name().c_str());
            }
        }
        
        return cis_tuples;
    }
    
public:
    Extractor(int argc, char * const argv[]) {
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

        _c = make_shared<Compiler>(args);

        /* Output all PCI sromvars */
        auto nvars = extract_nvars(@"pci_sromvars");
        auto vars = convert_nvars(nvars);

        /* Output the per-path vars */
        auto path_nvars = extract_nvars(@"perpath_pci_sromvars");
        auto path_vars = convert_nvars(path_nvars);

        struct pathcfg {
            const char *path_pfx;
            const char *path_num;
            nvram::compat_range compat;
        } pathcfgs[] = {
            { "SROM4_PATH",    "MAX_PATH_SROM",       {4, 7}},
            { "SROM8_PATH",    "MAX_PATH_SROM",       {8, 10}},
            { "SROM11_PATH",   "MAX_PATH_SROM_11",    {11, nvram::compat_range::MAX_SPROMREV}},
            { nil, nil, {0, 0}}
        };
        
        unordered_map<string, shared_ptr<nvram::var>> path_var_tbl;
        for (const auto &v : path_vars) {
            for (auto cfg = pathcfgs; cfg->path_pfx != nil; cfg++) {
                PLClangCursor *maxCursor = _c->find_symbol(cfg->path_num);
                if (maxCursor == nil)
                    errx(EXIT_FAILURE, "missing %s", cfg->path_num);
    
                uint32_t max = _c->tokens_literal_u32(_c->get_tokens(maxCursor));
                
                shared_ptr<nvram::var> newv;
                for (uint32_t i = 0; i < max; i++) {
                    NSString *path = [NSString stringWithFormat: @"%s%u", cfg->path_pfx, i];
                    PLClangCursor *c = _c->find_symbol(path.UTF8String);
                    if (c == nil)
                        errx(EXIT_FAILURE, "missing %s", path.UTF8String);
                    uint32_t struct_base = _c->tokens_literal_u32(_c->get_tokens(c)) * sizeof(uint16_t);

                    for (const auto &sp : *v->sprom_offsets()) {
                        if (sp.compat().first() >= cfg->compat.first() && sp.compat().first() <= cfg->compat.last()) {
                            auto values = make_shared<vector<nvram::value>>();
                            for (const auto &val : *sp.values()) {
                                auto segs = make_shared<vector<nvram::value_seg>>();
                                for (const auto &seg : *val.segments()) {
                                    segs->push_back(seg.offset(seg.offset() + struct_base));
                                }
                                values->emplace_back(segs);
                            }
                            
                            string name = v->name() + to_string(i);
                            if (path_var_tbl.count(name) == 0) {
                                newv = make_shared<nvram::var>(v->name(name).sprom_offsets(make_shared<vector<nvram::sprom_offset>>()));
                                path_var_tbl.insert({name, newv});
                            } else {
                                newv = path_var_tbl.at(name);
                            }
                            newv->sprom_offsets()->emplace_back(sp.compat(), values);
                        }
                    }
                    
                    if (newv)
                        vars.push_back(newv);
                }
            }
        }

        sort(vars.begin(), vars.end(), [](const shared_ptr<nvram::var> &lhs, shared_ptr<nvram::var> &rhs) {
            return ([@(lhs->name().c_str()) compare: @(rhs->name().c_str()) options: NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending);
        });

#if 0
        for (const auto &v : vars) {
            printf("%s:\n", v->name().c_str());
            for (const auto &sp : *v->sprom_offsets()) {
                printf("\t%s\t%s\t{ ", sp.compat().description().c_str(), to_string(v->type()).c_str());
                for (size_t vi = 0; vi < sp.values()->size(); vi++) {
                    const auto &val = sp.values()->at(vi);
                    auto segs = val.segments();
                    for (size_t seg = 0; seg < segs->size(); seg++) {
                        auto s = segs->at(seg);
                        printf("%s", s.description().c_str());
                        if (seg+1 < segs->size())
                            printf(" | ");
                    }
                    
                    if (vi+1 < sp.values()->size())
                        printf(", ");
                }
                printf(" }\n");
            }
        }
#endif

        /* Extract CIS decode info from the parser */
        auto cis_tuples = extract_cis_tuples();
        vector<shared_ptr<nvram::cis_vstr>> cis_vstrs;
        for (const auto &t : cis_tuples)
            for (const auto &v : t->vars)
                cis_vstrs.emplace_back(make_shared<nvram::cis_vstr>(v));

        /* Find CIS constants/descriptions */
        __block vector<nvram::cis_tag> cis_constants;
        [_c->translationUnit() visitChildrenUsingBlock:^PLClangCursorVisitResult(PLClangCursor *cursor) {
            NSError *error;
            auto regex = [NSRegularExpression regularExpressionWithPattern: @"(^/\\*[ \t]*|[ \t]*\\*/$)"
                                                                   options:NSRegularExpressionCaseInsensitive
                                                                     error:&error];
            if (regex == nil)
                errx(EXIT_FAILURE, "failed to parse regex: %s", [error description].UTF8String);
            
            auto ws_regex = [NSRegularExpression regularExpressionWithPattern: @"[ \t\n\r]+\\*[ \t\n\r]+"
                                                                   options:NSRegularExpressionCaseInsensitive
                                                                     error:&error];
            if (ws_regex == nil)
                errx(EXIT_FAILURE, "failed to parse regex: %s", [error description].UTF8String);

            switch (cursor.kind) {
                case PLClangCursorKindMacroDefinition: {
                    if (![cursor.spelling hasPrefix: @"HNBU_"])
                        return PLClangCursorVisitContinue;

                    NSString *comment = nil;
                    for (PLClangToken *t in _c->get_tokens(cursor)) {
                        if (t.kind == PLClangTokenKindComment) {
                            comment = [regex stringByReplacingMatchesInString: t.spelling options: 0 range: NSMakeRange(0, t.spelling.length) withTemplate: @""];
                            comment = [ws_regex stringByReplacingMatchesInString: comment options: 0 range: NSMakeRange(0, comment.length) withTemplate: @"\n"];
                            break;
                        }
                    }

                    cis_constants.emplace_back(_c->resolve_constant(cursor.spelling.UTF8String), comment);
                    return PLClangCursorVisitContinue;
                }
                default:
                    return PLClangCursorVisitRecurse;
            }
        }];
        
        /* Report SROM/CIS differences */
        nvram::nvram_map m(vars, cis_vstrs, cis_constants);
        m.emit_diagnostics();
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