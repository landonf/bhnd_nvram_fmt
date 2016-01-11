/*
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#pragma once

#include <tuple>
#include <PLStdCPP/ftl/concepts/basic.h>
#include <PLStdCPP/ftl/type_functions.h>

namespace pl {

/**
 * @defgroup product Product Types
 */

/**
 * @interface product
 *
 * Struct that must be specialised to implement the `product` type class.
 *
 * @ingroup product
 */
template<typename T> struct product {
    /**
     * The ordered element types composing a product of type `R`.
     *
     * For example, given a product type of `record<int, std::string>`, then
     *`T` = `ftl::type_seq<int, std::string>`.
     */
    using P = std::tuple<>;
    
    /**
     * Return the std::tuple representation of the given product.
     *
     * @param product The product for which a std::tuple representation should be returned.
     */
    static P unapply (const T &product);
    
    /**
     * Return the product representation of the given values.
     *
     * @param T std::tuple of values to be applied to `R`.
     */
    static T apply (const P &values);
    
    /**
     * If true, a specialization of product<R> will satisfy compile time
     * Product<F> requirements.
     *
     * Concrete implementations of this type class must override this default
     * with a value of `true`.
     */
    static constexpr bool instance = false;
};

/**
 * Predicate to check whether a given type `F` is an instance of `product`.
 *
 * Can of course be used for similar purposes by way of SFINAE already.
 *
 * @par Example
 *
 * @code
 *   template<
 *       typename P,
 *       typename = Requires<Product<P>{}>
 *   >
 *   exampleFunction (const F& f);
 * @endcode
 *
 * @ingroup product
 */
template<typename T>
struct Product {
    static constexpr bool value = product<T>::instance;
    constexpr operator bool() const noexcept { return value; }
};

/**
 * Support for automatic conversion between structs and tuples, as a stage in serialization.
 *
 * To support conversion, define a fields() method that takes no parameters and returns a
 * std::tuple containing references to fields that should be serialized. For example:
 *
 * std::tuple<int32_t &, uint8_t &> fields() { ... }
 *
 * As a shortcut, the FIELDS macro can be used to automatically define such a method that
 * returns a tuple of references to member variables. For example:
 * struct Person {
 *     std::string name;
 *     int age;
 *     char dog;
 *
 *     FIELDS(name, age, dog);
 * };
 */
#define FIELDS(...) decltype(std::tie(__VA_ARGS__)) fields() const { return std::tie(__VA_ARGS__); }

} /* namespace pl */
