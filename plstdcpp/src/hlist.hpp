/*
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * This API is based on the design of Michael Pilquist and Paul Chiusano's
 * Scala scodec library: https://github.com/scodec/scodec/
 */

#pragma once

#include <functional>
#include <type_traits>
#include <limits>
#include <array>

#include <PLStdCPP/ftl/functional.h>
#include <PLStdCPP/ftl/type_functions.h>
#include <PLStdCPP/ftl/concepts/monad.h>
#include <PLStdCPP/ftl/concepts/monoid.h>

/**
 * Polymorphic type-safe operations over tuples containing heterogeneous values.
 */
namespace pl {
namespace hlist {
    /* Internal implementation of C++14's index_sequence */
    template <std::size_t ...> struct index_sequence {};
    
    template <std::size_t N, std::size_t ... Indices>
    struct make_index_sequence : make_index_sequence<N - 1, N - 1, Indices...> {};
    
    template <std::size_t ... Indices>
    struct make_index_sequence<std::size_t(0), Indices...> : index_sequence<Indices...> {};

    /**
     * Range-based construction of index_sequence.
     *
     * @tparam I The initial index of the returned sequence.
     * @tparam Size The sequence length.
     */
    template <std::size_t I, std::size_t Size, std::size_t ... Indices>
    struct make_index_range : make_index_range<I, Size - 1, I + (Size - 1), Indices...> {};
    
    template <std::size_t I, std::size_t ... Indices>
    struct make_index_range<I, std::size_t(0), Indices...> : index_sequence<Indices...> {};
    
#pragma mark Selection
    /**
     * Return a new tuple representing the selection of `Indices' from the provided @a tuple.
     *
     * @tparam Ts The element types of the provided tuple.
     * @param tuple The tuple from which to return the selected elements.
     */
    template <std::size_t ... Indices, typename ... Ts> static constexpr auto select (const std::tuple<Ts...> &tuple) -> decltype(std::make_tuple(std::get<Indices>(tuple)...)) {
        return std::make_tuple(std::get<Indices>(tuple)...);
    }
    
    /**
     * Return a new tuple representing the selection of `Indices' from the provided @a tuple.
     *
     * @tparam Ts The element types of the provided tuple.
     * @param tuple The tuple from which to return the selected elements.
     */
    template <std::size_t ... Indices, typename ... Ts> static constexpr auto select (const std::tuple<Ts...> &tuple, const index_sequence<Indices...> &) -> decltype(std::make_tuple(std::get<Indices>(tuple)...)) {
        return select<Indices...>(tuple);
    }
    
    /**
     * Return the head of the given @a tuple.
     *
     * @param tuple The tuple from which to return the first element.
     */
    template <typename ... Ts> static constexpr auto head (const std::tuple<Ts...> &tuple) -> typename std::tuple_element<0, std::tuple<Ts...>>::type {
        return std::get<0>(tuple);
    }
    
    /**
     * Return the tail of the given @a tuple.
     *
     * @param tuple The tuple from which to return the tail elements.
     */
    template <typename ... Ts> static constexpr auto tail (const std::tuple<Ts...> &tuple) -> decltype(select(tuple, make_index_range<1, sizeof...(Ts) - 1>())) {
        return select(tuple, make_index_range<1, sizeof...(Ts) - 1>());
    }

#pragma mark Map
    
    /**
     * @internal
     * Type-safe mapping via polymorphic application of F.
     */
    template<typename Fn, typename ... Ts> struct Mapper {
        template<std::size_t ... Indices> static constexpr auto map (const std::tuple<Ts...> &tuple, const Fn &fn, const index_sequence<Indices...> &) ->
        decltype(std::make_tuple(fn(std::get<Indices>(tuple))...))
        {
            return std::make_tuple(fn(std::get<Indices>(tuple))...);
        }
    };
    
    
    
    /**
     * Map polymorphic function `F` over all values of @a tuple, returning a new tuple containing the well-typed results.
     *
     * @tparam Fn A templated function-like struct that accepts tuple elements as its single argument.
     * @param tuple The tuple over which `F` will be applied.
     */
    template <typename Fn, typename ... Ts> constexpr auto map (const std::tuple<Ts...> &tuple, const Fn &f) -> decltype(Mapper<Fn, Ts...>::map(tuple, f, make_index_sequence<sizeof...(Ts)>())) {
        return Mapper<Fn, Ts...>::map(tuple, f, make_index_sequence<sizeof...(Ts)>());
    }
    
    
#pragma mark Apply
    /**
     * @internal
     * Type-safe mapping via application of (fn1, f2, ...) and (val1, val2, ...) tuples.
     */
    template<typename ... Fn> struct Applier {
        template<std::size_t ... Indices> static constexpr std::tuple<typename std::decay<typename Fn::result_type>::type...> apply (const std::tuple<Fn...> &funcs, const std::tuple<typename std::decay<typename Fn::argument_type>::type...> &values, const index_sequence<Indices...> &) {
            return std::make_tuple(std::get<Indices>(funcs)(std::get<Indices>(values))...);
        }
    };
    
    /**
     * Type-safe 1:1 function application.
     *
     * @param funcs The functions to be applied to @a values.
     * @param values The values to which @a funcs will be applied.
     */
    template <typename ... Fn> constexpr const std::tuple<typename std::decay<typename Fn::result_type>::type...> apply (const std::tuple<Fn...> &funcs, const std::tuple<typename std::decay<typename Fn::argument_type>::type...> &values) {
        return Applier<Fn...>::apply(funcs, values, make_index_sequence<sizeof...(Fn)>());
    }
    
    
#pragma mark Fold
    /**
     * @internal
     * Type-safe folding via polymorphic application of F.
     */
    template<typename F, typename S, typename ... Ts> struct Folder {
        /* Terminal leftFold implementation */
        template<std::size_t Idx> static constexpr typename std::enable_if<Idx == sizeof...(Ts), S>::type leftFold (const S &state, const std::tuple<Ts...> &tuple, const F &fn) {
            return state;
        }
        
        /* Recursively defined left fold */
        template<std::size_t Idx> static constexpr typename std::enable_if<Idx < sizeof...(Ts), S>::type leftFold (const S &state, const std::tuple<Ts...> &tuple, const F &fn) {
            return leftFold<Idx+1>(fn(state, std::get<Idx>(tuple)), tuple, fn);
        }
    };
    
    /**
     * Type-safe polymorphic left fold over @a tuple.
     *
     * @param state Initial state.
     * @param tuple Tuple over which the left fold will be computed.
     * @param fn A struct providing a unary function-call operator that may be applied to all elements of @a tuple.
     */
    template <typename F, typename S, typename ... Ts> constexpr typename std::decay<S>::type leftFold (const S &state, const std::tuple<Ts ...> &tuple, const F &fn) {
        return Folder<F, typename std::decay<S>::type, Ts...>::template leftFold<0>(state, tuple, fn);
    }
    
    
#pragma mark Zip
    /**
     * @internal
     * Type-safe zipping via polymorphic application of the given zipper function F. This is essentially a specialization of
     * map() across two tuples.
     */
    template<typename LHS, typename RHS> struct Zipper {
        static_assert(ftl::is_same_template<std::tuple<>, LHS>::value, "The `lhs' argument is not a tuple.");
        static_assert(ftl::is_same_template<std::tuple<>, RHS>::value, "The `rhs' argument is not a tuple.");
        static_assert(std::tuple_size<LHS>::value == std::tuple_size<RHS>::value, "The `lhs' and `rhs' tuple operands must be identically sized");
        
        template<typename Fn, std::size_t ... Indices> static auto zipWith (const LHS &lhs, const RHS &rhs, const Fn &fn, const index_sequence<Indices...> &) ->
        decltype(std::make_tuple(fn(std::get<Indices>(lhs), std::get<Indices>(rhs))...))
        {
            return std::make_tuple(fn(std::get<Indices>(lhs), std::get<Indices>(rhs))...);
        }
    };
    
    /**
     * @internal
     * Polymorphic zipper function; maps (L, R) pairs to std::pair<L, R>.
     */
    static constexpr struct zip_pair_fn {
        template <typename L, typename R> std::pair<L, R> constexpr operator() (const L &lhs, const R &rhs) const {
            return std::make_pair(lhs, rhs);
        }
    } zip_pair {};
    
    /**
     * Type-safe polymorphic zipWith over @a lhs and @rhs tuple operands.
     *
     * @param lhs The first tuple operand.
     * @param rhs The second tuple operand.
     * @param fn A struct providing a binary function-call operator that may be applied to all pairs in @a lhs and @a rhs.
     */
    template <typename Fn, typename LHS, typename RHS> constexpr auto zipWith (const LHS &lhs, const RHS &rhs, const Fn &fn) ->
    decltype(Zipper<LHS, RHS>::zipWith(lhs, rhs, fn, make_index_sequence<std::tuple_size<RHS>::value>()))
    {
        return Zipper<LHS, RHS>::zipWith(lhs, rhs, fn, make_index_sequence<std::tuple_size<RHS>::value>());
    }
    
    /**
     * Type-safe zip over equally sized @a lhs and @rhs tuple operands, producing a new tuple
     * composed of std::pair<lhs..., rhs...> values.
     *
     * @param lhs The first tuple operand.
     * @param rhs The second tuple operand.
     */
    template <typename LHS, typename RHS> constexpr auto zip (const LHS &lhs, const RHS &rhs) ->
    decltype(zipWith(lhs, rhs, zip_pair))
    {
        return zipWith(lhs, rhs, zip_pair);
    }
    
#pragma mark Array Conversion
    
    /**
     * @internal
     *
     * Conversion of std::tuple values to std::array.
     */
    template <typename T> struct ToArray {
        template<std::size_t ... Indices> constexpr static std::array<
        typename std::tuple_element<0, T>::type,
        std::tuple_size<T>::value
        > to_array (const T &tuple, const index_sequence<Indices...> &) {
            return {{ std::get<Indices>(tuple)... }};
        }
    };
    
    /**
     * Convert a std::tuple to a std::array.
     */
    template <typename T> constexpr static auto to_array (const T &tuple) -> decltype(ToArray<T>::to_array(tuple, make_index_sequence<std::tuple_size<T>::value>())) {
        return ToArray<T>::to_array(tuple, make_index_sequence<std::tuple_size<T>::value>());
    }
    
#pragma mark Sequence
    /**
     * @internal
     *
     * Sequencing (essentially a fold) over a tuple of Monad<Monoid> values.
     */
    template<typename M> struct Sequencer {
        /* Perform a sequence with the supplied initial value. */
        template <typename ... Ms> static M sequence (const M &zero, const std::tuple<Ms...> &operand)
        {
            typedef ftl::Value_type<M> V;
            typedef ftl::monad<M> TMonad;
            typedef ftl::monoid<V> VMonoid;
            
            const auto operands = to_array(operand);
            
            auto accum = zero;
            for (size_t i = 0; i < operands.size(); i++) {
                const auto &next = operands[i];
                
                accum = accum >>= [&next](const V &a) {
                    return [&a](const V &n) {
                        return VMonoid::append(a, n);
                    } % next;
                };
            }
            
            return accum;
        }
        
        /* Perform a sequence with the monoid<V>-supplied zero value as the initial zero value. */
        template <typename ... Ms> static M sequence (const std::tuple<Ms...> &operand) {
            typedef ftl::Value_type<M> V;
            typedef ftl::monad<M> TMonad;
            typedef ftl::monoid<V> VMonoid;
            
            const auto zero = TMonad::pure(VMonoid::id());
            return sequence(zero, operand);
        }
        
    };
    
    /**
     * Given a tuple containing monadic-wrapped monoidal values, sequence all values, producing a single accumulated value.
     *
     * @param initial The initial value to which all sequenced values will be appended.
     * @param tuple A tuple containing monadic values to be sequenced.
     */
    template <typename M, typename ... Ms> static auto sequence (const M &initial, const std::tuple<M, Ms...> &tuple) -> decltype(Sequencer<M>::sequence(tuple)) {
        return Sequencer<M>::sequence(initial, tuple);
    }
    
    /**
     * Given a tuple containing monadic-wrapped monoidal values, sequence all values, producing a single accumulated value.
     *
     * @param tuple A tuple containing monadic values to be sequenced.
     */
    template <typename M, typename ... Ms> static auto sequence (const std::tuple<M, Ms...> &tuple) -> decltype(Sequencer<M>::sequence(tuple)) {
        return Sequencer<M>::sequence(tuple);
    }
    
    /**
     * Given an empty tuple with a known type, sequence returns an empty result.
     *
     * @param tuple An empty tuple to sequence.
     */
    template <
    typename M,
    typename V = ftl::Value_type<M>,
    typename R = ftl::Requires<ftl::Monad<M>{}>,
    typename RV = ftl::Requires<ftl::Monoid<V>{}>
    > constexpr M sequence (const std::tuple<> &empty) {
        return ftl::monad<M>::pure(ftl::monoid<V>::id());
    }
    
    /**
     * Given an empty tuple, sequence returns the initial value.
     *
     * @param initial The initial value to which all sequenced values will be appended.
     * @param tuple An empty tuple to sequence.
     */
    template <typename M> constexpr const M sequence (const M &initial, const std::tuple<> &empty) {
        return initial;
    }
}
};
#pragma mark -
