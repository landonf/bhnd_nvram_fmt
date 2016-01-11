/*
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import "XSmallTest.h"

#include "record_type.hpp"
#include "product_type.hpp"

#include <string>

PL_RECORD_STRUCT(TestRecord,
    (int, age),
    (std::string, name),
    /* Tests paren-escaping of types containing "," */
    ((std::array<uint8_t, 2>), complexType)
);

/* If this compiles at all, the test has passed; this verifies that PL_RECORD_STRUCT only enables
 * equality operators when all of its members themselves support the operators. */
struct TestEqualityEnablementTarget {};
PL_RECORD_STRUCT(TestEqualityEnablement, ((TestEqualityEnablementTarget), st));

xsm_given("a record") {
    auto record = TestRecord(42, "Mr. Awesome", std::array<uint8_t, 2>{{1, 2}});
    
    xsm_then("it should be convertable to/from a product representation") {
        auto applied = TestRecord::apply(record.unapply());
        XCTAssertTrue(record == applied);
    }
    
    xsm_then("it should provide equality operators") {
        auto equalRecord = record;
        auto nonEqualRecord = TestRecord(record.age() + 10, record.name(), record.complexType());
        
        XCTAssertTrue(equalRecord == record);
        XCTAssertTrue(nonEqualRecord != record);
    }
    
    xsm_then("it should be modifiable") {
        auto modifiedAge = record.age(-8);
        auto modifiedAll = record
            .age(-42)
            .name("Bort")
            .complexType(std::array<uint8_t, 2>{{3, 4}});
        
        XCTAssertEqual(modifiedAge.age(), -8);
        XCTAssertTrue(modifiedAge != record);
        XCTAssertTrue(modifiedAge.age(42) == record);
        
        XCTAssertEqual(modifiedAll.age(), -42);
        XCTAssertTrue(modifiedAll.name() == "Bort");
        XCTAssertTrue(modifiedAll.complexType() == (std::array<uint8_t, 2>{{3, 4}}));
    }
}