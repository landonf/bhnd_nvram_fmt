/*
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#pragma once

#include <tuple>
#include "hlist.hpp"

namespace pl {

/**
 * Check if a type conforms to the `record` structural type requirements:
 *
 * - A static apply() unary method must accept a std::tuple<T...> and return an instance of `R`.
 * - The non-static unapply() method must return an instance of std::tuple<T...> that may be
 *   passed to apply().
 */
template<class R, typename=void> struct is_record : std::false_type {}; \
template<class R> struct is_record<R, typename std::enable_if<
    std::is_same<
        R,
        decltype(
            R::apply(
                std::declval<decltype(
                    std::declval<R>().unapply()
                )>()
            )
        )
    >::value &&
    ftl::is_base_template<decltype(std::declval<R>().unapply()), std::tuple>::value
>::type> : std::true_type {};

/* Table of commas used to determine the argument count. */
#define _PL_RECORD_ARGC_TABLE()            \
   63,   62,   61,   60,   59,   58,   57,   56,   55,   54  \
   53,   52,   51,   50,   49,   48,   47,   46,   45,   44, \
   43,   42,   41,   40,   39,   38,   37,   36,   35,   34, \
   33,   32,   31,   30,   29,   28,   27,   26,   25,   24, \
   23,   22,   21,   20,   19,   18,   17,   16,   15,   14, \
   13,   12,   11,   10,    9,    8,    7,    6,    5,    4, \
    3,    2,    1,    0

/* Macro applied to _PL_RECORD_ARGC_TABLE to determine the number of arguments remaining. */
#define _PL_RECORD_ARG_MATCH( \
    _1,   _2,   _3,   _4,   _5,   _6,   _7,   _8,   _9,   _10, \
    _11,  _12,  _13,  _14,  _15,  _16,  _17,  _18,  _19,  _20, \
    _21,  _22,  _23,  _24,  _25,  _26,  _27,  _28,  _29,  _30, \
    _31,  _32,  _33,  _34,  _35,  _36,  _37,  _38,  _39,  _40, \
    _41,  _42,  _43,  _44,  _45,  _46,  _47,  _48,  _49,  _50, \
    _51,  _52,  _53,  _54,  _55,  _56,  _57,  _58,  _59,  _60, \
    _61,  _62,  _63,    N,  ...) N


/* Table of commas used to determine whether the argument count is >= 1. */
#define _PL_RECORD_ARGN_TABLE()            \
    n,    n,    n,    n,    n,    n,    n,    n,    n,    n  \
    n,    n,    n,    n,    n,    n,    n,    n,    n,    n, \
    n,    n,    n,    n,    n,    n,    n,    n,    n,    n, \
    n,    n,    n,    n,    n,    n,    n,    n,    n,    n, \
    n,    n,    n,    n,    n,    n,    n,    n,    n,    n, \
    n,    n,    n,    n,    n,    n,    n,    n,    n,    n, \
    n,    n,    n,    n,    0

/* Macro applied to _PL_RECORD_ARGN_TABLE to determine the number of arguments remaining. */
#define _PL_RECORD_ARGN_MATCH( \
    _empty, \
    _1,   _2,   _3,   _4,   _5,   _6,   _7,   _8,   _9,   _10, \
    _11,  _12,  _13,  _14,  _15,  _16,  _17,  _18,  _19,  _20, \
    _21,  _22,  _23,  _24,  _25,  _26,  _27,  _28,  _29,  _30, \
    _31,  _32,  _33,  _34,  _35,  _36,  _37,  _38,  _39,  _40, \
    _41,  _42,  _43,  _44,  _45,  _46,  _47,  _48,  _49,  _50, \
    _51,  _52,  _53,  _54,  _55,  _56,  _57,  _58,  _59,  _60, \
    _61,  _62,  _63,    N,  ...) N

/*
 * Given a set of arguments, counts the arguments and returns the argument count.
 */
#define _PL_RECORD_ARG_COUNT_(...)                         _PL_RECORD_ARG_MATCH(__VA_ARGS__)
#define _PL_RECORD_ARG_COUNT(...)                          _PL_RECORD_ARG_COUNT_(__VA_ARGS__, _PL_RECORD_ARGC_TABLE())

/*
 * Given a set of arguments, counts the arguments and returns whether there are 0 or n (>=1) count.
 */
#define _PL_RECORD_HAS_ARGS__(...)                         _PL_RECORD_ARGN_MATCH(__VA_ARGS__)
#define _PL_RECORD_HAS_ARGS_(...)                          _PL_RECORD_HAS_ARGS__(__VA_ARGS__, _PL_RECORD_ARGN_TABLE())
#define _PL_RECORD_HAS_ARGS(...)                          _PL_RECORD_HAS_ARGS_(_nothing, ## __VA_ARGS__)

#define _PL_RECORD_PASTE(x, ...) x ## __VA_ARGS__
#define _PL_RECORD_PASTE2(x, ...) _PL_RECORD_PASTE(x, __VA_ARGS__)

/* This bit of ugly magic strips optional parenthesis from its argument */
#define _PL_RECORD_PARENS_EXTRACT(...) _PL_RECORD_PARENS_EXTRACT __VA_ARGS__
#define _PL_RECORD_WHEN_CONCATENATED_WITH_EXTRACT_BECOMES_NOTHING__PL_RECORD_PARENS_EXTRACT
#define _PL_RECORD_UNPAREN(x) _PL_RECORD_PASTE2(_PL_RECORD_WHEN_CONCATENATED_WITH_EXTRACT_BECOMES_NOTHING_, _PL_RECORD_PARENS_EXTRACT x)

/* Templates used to generate the contents of a Record */
#define _PL_RECORD_TYPE_LIST_TEMPL_n(type, name, ...)      _PL_RECORD_UNPAREN(type) __VA_ARGS__,
#define _PL_RECORD_TYPE_LIST_TEMPL_1(type, name, ...)      _PL_RECORD_UNPAREN(type) __VA_ARGS__

#define _PL_RECORD_PARAM_DECL_TEMPL_n(type, name, ...)     _PL_RECORD_UNPAREN(type) name __VA_ARGS__,
#define _PL_RECORD_PARAM_DECL_TEMPL_1(type, name, ...)     _PL_RECORD_UNPAREN(type) name __VA_ARGS__

#define _PL_RECORD_IVAR_DECL_TEMPL_n(type, name, ...)      _PL_RECORD_UNPAREN(type) _ ## name __VA_ARGS__;
#define _PL_RECORD_IVAR_DECL_TEMPL_1(type, name, ...)      _PL_RECORD_UNPAREN(type) _ ## name __VA_ARGS__;

#define _PL_RECORD_GETTER_TEMPL_n(type, name, ...)         _PL_RECORD_UNPAREN(type) name () const { return _ ## name; }
#define _PL_RECORD_GETTER_TEMPL_1(type, name, ...)         _PL_RECORD_UNPAREN(type) name () const { return _ ## name; }

#define _PL_RECORD_MODIFIER_TEMPL_n(type, name, ...)       Self name(_PL_RECORD_UNPAREN(type) new_ ## name) const { auto newObj = *this; newObj._ ## name = new_ ## name; return newObj; }
#define _PL_RECORD_MODIFIER_TEMPL_1(type, name, ...)       _PL_RECORD_MODIFIER_TEMPL_n(type, name, __VA_ARGS__)

#define _PL_RECORD_IVAR_INIT_TEMPL_n(type, name, ...)      _ ## name (name) __VA_ARGS__,
#define _PL_RECORD_IVAR_INIT_TEMPL_1(type, name, ...)      _ ## name (name) __VA_ARGS__

#define _PL_RECORD_PARAM_USE_TEMPL_n(type, name, ...)      _ ## name __VA_ARGS__,
#define _PL_RECORD_PARAM_USE_TEMPL_1(type, name, ...)      _ ## name __VA_ARGS__
    
#define _PL_RECORD_TYPE_TEMPL_n(type, name, ...)           _PL_RECORD_UNPAREN(type),
#define _PL_RECORD_TYPE_TEMPL_1(type, name, ...)           _PL_RECORD_UNPAREN(type)

#define _PL_RECORD_EQUALITY_TEMPL_n(type, name, ...)       if (_ ## name != other._ ## name) return false;
#define _PL_RECORD_EQUALITY_TEMPL_1(type, name, ...)       if (_ ## name != other._ ## name) return false;

/* Concatenate LHS and RHS */
#define _PL_RECORD_CONCAT_TEMPLATE(lhs, rhs)               lhs ## rhs

/* Apply rhs to lhs as an (argument list) */
#define _PL_RECORD_APPLY_TEMPLATE(lhs, rhs)                lhs rhs

/* Performs recursive expansion of a template */
#define _PL_RECORD_ITERATE_TEMPLATE_0(...)
#define _PL_RECORD_ITERATE_TEMPLATE_1(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _1), head) _PL_RECORD_ITERATE_TEMPLATE_0()
#define _PL_RECORD_ITERATE_TEMPLATE_2(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_1(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_3(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_2(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_4(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_3(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_5(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_4(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_6(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_5(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_7(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_6(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_8(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_7(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_9(template, head, ...)     _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_8(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_10(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_9(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_11(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_10(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_12(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_11(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_13(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_12(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_14(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_13(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_15(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_14(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_16(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_15(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_17(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_16(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_18(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_17(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_19(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_18(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_20(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_19(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_21(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_20(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_22(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_21(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_23(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_22(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_24(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_23(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_25(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_24(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_26(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_25(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_27(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_26(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_28(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_27(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_29(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_28(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_30(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_29(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_31(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_30(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_32(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_31(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_33(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_32(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_34(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_33(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_35(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_34(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_36(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_35(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_37(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_36(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_38(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_37(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_39(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_38(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_40(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_39(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_41(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_40(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_42(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_41(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_43(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_42(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_44(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_43(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_45(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_44(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_46(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_45(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_47(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_46(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_48(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_47(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_49(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_48(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_50(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_49(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_51(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_50(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_52(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_51(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_53(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_52(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_54(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_53(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_55(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_54(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_56(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_55(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_57(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_56(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_58(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_57(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_59(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_58(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_60(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_59(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_61(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_60(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_62(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_61(template, __VA_ARGS__)
#define _PL_RECORD_ITERATE_TEMPLATE_63(template, head, ...)    _PL_RECORD_APPLY_TEMPLATE(_PL_RECORD_CONCAT_TEMPLATE(template, _n), head) _PL_RECORD_ITERATE_TEMPLATE_62(template, __VA_ARGS__)

#define _PL_RECORD_ITERATE_TEMPLATE__(c)                       _PL_RECORD_ITERATE_TEMPLATE_ ## c
#define _PL_RECORD_ITERATE_TEMPLATE_(c)                        _PL_RECORD_ITERATE_TEMPLATE__(c)
#define _PL_RECORD_ITERATE_TEMPLATE(...)                       _PL_RECORD_ITERATE_TEMPLATE_(_PL_RECORD_ARG_COUNT(__VA_ARGS__)) (__VA_ARGS__)

/* Non-empty record implementation */
#define _PL_RECORD_FIELDS_n(name, ...) \
public: \
    name (_PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_PARAM_DECL_TEMPL, __VA_ARGS__)) : _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_IVAR_INIT_TEMPL, __VA_ARGS__) {} \
    \
private: \
    template<std::size_t ... Indices> static inline name aapply (const std::tuple<_PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_TYPE_LIST_TEMPL, __VA_ARGS__)> &values, const pl::hlist::index_sequence<Indices...> &) { \
        return name(std::get<Indices>(values)...); \
    } \
public: \
    static inline name apply (const std::tuple<_PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_TYPE_LIST_TEMPL, __VA_ARGS__)> &values) { \
        return aapply(values, pl::hlist::make_index_sequence<_PL_RECORD_ARG_COUNT(__VA_ARGS__) + 1>()); \
    } \
    \
    std::tuple<_PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_TYPE_LIST_TEMPL, __VA_ARGS__)> unapply () const { \
        return std::make_tuple(_PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_PARAM_USE_TEMPL, __VA_ARGS__)); \
    } \
    \
    _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_GETTER_TEMPL, __VA_ARGS__); \
    \
private: \
    typedef name Self; \
public: \
    _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_MODIFIER_TEMPL, __VA_ARGS__); \
    \
    template <typename U, typename = typename std::enable_if<ftl::All<ftl::Eq, \
        _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_TYPE_TEMPL, __VA_ARGS__) \
    >{}, U>::type> \
    bool operator==(const U &other) const { \
        static_assert(std::is_same<U, name>::value, "right-hand operand must be of type " # name); \
        _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_EQUALITY_TEMPL, __VA_ARGS__) \
        return true; \
    } \
    \
    template <typename U, typename = typename std::enable_if<ftl::All<ftl::Eq, \
        _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_TYPE_TEMPL, __VA_ARGS__) \
    >{}, U>::type> \
    bool operator!=(const U &other) const { \
        static_assert(std::is_same<U, name>::value, "right-hand operand must be of type " # name); \
        return !operator==(other); \
    } \
    \
private: \
    _PL_RECORD_ITERATE_TEMPLATE(_PL_RECORD_IVAR_DECL_TEMPL, __VA_ARGS__)

/* Empty record implementation */
#define _PL_RECORD_FIELDS_0(name, ...) \
public: \
    name () {} \
    \
public: \
    static inline name apply (const std::tuple<> &values) { return name(); } \
    \
    inline std::tuple<> unapply () const { return std::make_tuple(); } \
    \
    bool operator==(const name &other) const { return true; } \
    \
    bool operator!=(const name &other) const { return !operator==(other); } \

#define _PL_RECORD_FIELDS__(c)                       _PL_RECORD_FIELDS_ ## c
#define _PL_RECORD_FIELDS_(c)                        _PL_RECORD_FIELDS__(c)

/**
 * @ingroup record
 *
 * Given the name of the enclosing class and a set of (T, name) tuples describing the record
 * fields, generates an appropriate constructor, accessors, `product` support, equality operators, and private member
 * variables.
 */
#define PL_RECORD_FIELDS(name, ...)                 _PL_RECORD_FIELDS_(_PL_RECORD_HAS_ARGS(__VA_ARGS__)) (name, __VA_ARGS__)


/**
 * @ingroup record
 *
 * Define a new Record struct with the given name and (type, name) member pairs.
 *
 * A valid constructor, accessors, modifiers, `product` support, equality operator, and private member variables will be
 * automatically generated.
 */
#define PL_RECORD_STRUCT(name, ...) struct name { \
    PL_RECORD_FIELDS(name, __VA_ARGS__); \
};

} /* namespace pl */