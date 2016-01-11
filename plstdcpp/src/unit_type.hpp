/*
 * Copyright (c) 2015 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#pragma once

namespace pl {
    /**
     * Empty type.
     */
    constexpr struct Unit {
    } unit {};

    /** Equality support for Unit. Two unit values are always equal */
    constexpr bool operator== (const Unit &, const Unit &) { return true; }
} /* namespace pl */
