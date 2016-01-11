This directory contains source and binary dependencies:

ftl
    Description:
      C++11 functional programming library.

    Version:
      2a02e64232bcb2da53f799dafc3bb2f0aff92310 checked out from https://github.com/beark/ftl

    License:
      BSD-like

    Modifications:
      Disabled value-type overload of `bind_helper<eitherT<L,M2>>` in either_trans.h; this
      triggers build errors when the value within the target monad is *not* an lvalue
      reference.

XSmallTest
    Description:
      A minimal single-header unit test DSL, compatible with Xcode's XCTest.

    Version:
      ecbbe255eb499f376c83d31528316214b80bbdc2 checked out from https://github.com/landonf/XSmallTest

    License:
      MIT

    Modifications:
      None
