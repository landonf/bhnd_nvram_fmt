/*
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import "XSmallTest.h"

#include "hlist.hpp"
#include "PLSmallTestExt.hpp"

#include <PLStdCPP/ftl/concepts/monoid.h>

using namespace pl;

template<typename T>
class FuncWrapper {
public:
    typedef std::function<uint32_t(const T &)> Fn;
    
    FuncWrapper (const typename FuncWrapper<T>::Fn &fn) : _fn(fn) {}

    const Fn fn () const { return _fn; }

private:
    const Fn _fn;
};

constexpr struct _enclosed_fn {
    template <typename T> typename FuncWrapper<T>::Fn constexpr operator() (const FuncWrapper<T> &wrapper) const { return wrapper.fn(); }
} enclosed_fn {};

FuncWrapper<uint8_t> uint8_plus_one () {
    return FuncWrapper<uint8_t>(
        [](const uint8_t &value) {
            return value + 1;
        }
    );
}

FuncWrapper<uint16_t> uint16_plus_one () {
    return FuncWrapper<uint16_t>(
        [](const uint16_t &value) {
            return value + 1;
        }
    );
}

xsm_given("hlists") {
    
    xsm_when("applying selection APIs") {
        auto values = std::make_tuple(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
        
        xsm_then("head should operate over a non-empty tuple") {
            auto head = hlist::select<0>(values);
            XCTAssertEqual(std::get<0>(head), std::get<0>(values));
            XCTAssertTrue(std::tuple_size<decltype(head)>::value == 1);
            
            std::tuple<int, int> two = hlist::select<0, 1>(values);
            XCTAssertEqual(std::get<0>(two), std::get<0>(values));
            XCTAssertEqual(std::get<1>(two), std::get<1>(values));
            XCTAssertTrue(std::tuple_size<decltype(two)>::value == 2);
            
            std::tuple<int, int, int, int, int> half = hlist::select<5, 6, 7, 8, 9>(values);
            XCTAssertEqual(std::get<0>(half), 6);
            XCTAssertEqual(std::get<4>(half), 10);
            XCTAssertTrue(std::tuple_size<decltype(half)>::value == 5);
        }
        
        xsm_then("head should return the first element") {
            auto head = hlist::head(values);
            XCTAssertEqual(head, std::get<0>(values));
        }
        
        xsm_then("tail should return all but the first element") {
            auto tail = hlist::tail(values);
            XCTAssertEqual(std::get<0>(tail), 2);
            XCTAssertTrue(std::tuple_size<decltype(tail)>::value == 9);
        }
        
    }

    xsm_then("map (and application) should apply polymorphically") {
        auto values = std::make_tuple<uint8_t, uint16_t>(0xAB, 0xCAFE);
        auto wrappers = std::make_tuple(uint8_plus_one(), uint16_plus_one());
        
        const std::tuple<FuncWrapper<uint8_t>::Fn, FuncWrapper<uint16_t>::Fn> funcs = hlist::map(wrappers, enclosed_fn);
        std::tuple<uint32_t, uint32_t> applied = hlist::apply(funcs, values);
        
        auto expected = std::make_tuple<uint32_t, uint32_t>(0xAC, 0xCAFF);
        XCTAssertEqual(expected, applied);
    }
    
    xsm_then("leftFold should apply polymorphically") {
        auto values = std::make_tuple<uint8_t, uint16_t>(0x7, 0x3);
        auto wrappers = std::make_tuple(uint8_plus_one(), uint16_plus_one());
        
        auto funcs = hlist::map(wrappers, enclosed_fn);
        auto applied = hlist::apply(funcs, values);
        
        auto folded = hlist::leftFold((uint32_t)42, applied, [](const uint32_t &accum, const uint32_t &next) {
            return accum + next;
        });
        
        XCTAssertEqual(folded, (uint32_t)54);
    }
    
    xsm_then("zipWith should apply polymorphically") {
        auto values = std::make_tuple<uint8_t, uint16_t>(0xAB, 0xCAFE);
        auto wrappers = std::make_tuple(uint8_plus_one(), uint16_plus_one());
        
        auto pairs = hlist::zip(values, hlist::map(wrappers, enclosed_fn));
    }

    xsm_then("tuples of a consistent type should be convertable to std::array") {
        auto values = std::make_tuple<int, int>(123, 456);
        const std::array<int, 2> array_vals = hlist::to_array(values);
        
        XCTAssertEqual(array_vals[0], 123);
        XCTAssertEqual(array_vals[1], 456);
        XCTAssertEqual(array_vals.size(), 2ul);
    }
    
    xsm_then("sequence should operate over monads encapsulating monoids") {
        auto values = std::make_tuple(ftl::make_right<std::string>((ftl::sum_monoid<uint8_t>)7), ftl::make_right<std::string>((ftl::sum_monoid<uint8_t>)3));
        auto sequenced = hlist::sequence(ftl::make_right<std::string>((ftl::sum_monoid<uint8_t>)1), values);
        
        XCTAssertTrue(ftl::fromRight(sequenced) == (uint8_t)11);
    }
    
    xsm_then("sequence over empty tuples of known type returns identity value") {
        auto values = std::make_tuple<>();
        auto result = hlist::sequence<ftl::either<std::string, ftl::sum_monoid<uint8_t>>>(values);
        
        XCTAssertTrue(ftl::fromRight(result) == (ftl::sum_monoid<uint8_t>)0);
    }
}