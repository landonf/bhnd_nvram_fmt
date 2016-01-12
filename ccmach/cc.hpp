//
//  cc.h
//  ccmach
//
//  Created by Landon Fuller on 1/12/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#ifndef __ccmach__cc__
#define __ccmach__cc__

#include "nvtypes.h"
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

    NSDictionary *symbols (void) { return _symbols; }
    
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
    
    NSArray *
    resolve_macro_def_tokens(PLClangToken *t) {
        if (t.kind != PLClangTokenKindIdentifier)
            errx(EXIT_FAILURE, "can't resolve non-identifier token %s", t.spelling.UTF8String);

        PLClangCursor *def = find_symbol(t.spelling.UTF8String);
        if (def.referencedCursor != nil)
            def = def.referencedCursor;

        NSArray *tokens = [_tu tokensForSourceRange: def.extent];
        if (tokens.count < 2)
            errx(EXIT_FAILURE, "macro def %s unsupported token count %lu", t.spelling.UTF8String, (unsigned long)tokens.count);
        
        return [tokens subarrayWithRange: NSMakeRange(1, tokens.count-1)];
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
    tokens_literal(NSArray *tokens)
    {
        if (tokens.count == 0)
            errx(EX_DATAERR, "empty token array");

        if (tokens.count == 1)
            return token_literal(tokens[0]);

        return [NSNumber numberWithUnsignedInteger:tokens_literal_u32(tokens)];
    }
    
    id<NSObject>
    token_literal(PLClangToken *t) {
        if (t.kind == PLClangTokenKindIdentifier && t.cursor.isPreprocessing) {
            return tokens_literal(resolve_macro_def_tokens(t));
        }
        
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

        for (NSUInteger i = 0; i < tokens.count; i++) {
            PLClangToken *t = tokens[i];
            
            switch (t.kind) {
                case PLClangTokenKindPunctuation:
                case PLClangTokenKindIdentifier:
                case PLClangTokenKindLiteral: {
                    uint32_t nv;
                    if (t.kind == PLClangTokenKindLiteral) {
                        nv = token_literal_u32(t);
                    } else if (t.kind == PLClangTokenKindIdentifier) {
                        NSArray *resolved = resolve_macro_def_tokens(t);
                        id<NSObject> obj = tokens_literal(resolved);
                        if (obj == nil || ![obj isKindOfClass: [NSNumber class]])
                            errx(EX_DATAERR, "could not resolve identifier token %s (got %s)", t.spelling.UTF8String, obj.description.UTF8String);
                        nv = [(NSNumber *)obj unsignedIntValue];
                    } else if (t.kind == PLClangTokenKindPunctuation) {
                        if (t.spelling.UTF8String[0] != '(') {
                            op = t.spelling.UTF8String[0];
                            break;
                        }

                        NSUInteger closeParen = i;
                        for (NSUInteger o = closeParen; o < tokens.count; o++) {
                            PLClangToken *nt = tokens[o];
                            if (nt.kind == PLClangTokenKindPunctuation && nt.spelling.UTF8String[0] == ')') {
                                closeParen = o;
                                break;
                            }
                        }
                        
                        if (closeParen == i) {
                            errx(EXIT_FAILURE, "could not finding closing parenthesis in '%s'", tokens.description.UTF8String);
                        }
                        
                        NSArray *subexpr = [tokens subarrayWithRange: NSMakeRange(i+1, closeParen-i-1)];
                        i = closeParen+1;
                        
                        id<NSObject> obj = tokens_literal(subexpr);
                        if (obj == nil || ![obj isKindOfClass: [NSNumber class]])
                            errx(EX_DATAERR, "could not resolve identifier token %s", t.spelling.UTF8String);
                        nv = [(NSNumber *)obj unsignedIntValue];
                    } else {
                        errx(EX_SOFTWARE, "unreachable case reached!");
                    }

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
                        case '/':
                            v /= nv;
                            break;
                        default:
                            errx(EXIT_FAILURE, "unsupported op %c", op);
                    }
                    break;
                }
                case PLClangTokenKindComment:
                    /* Ignore */
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

#endif /* defined(__ccmach__cc__) */
