/* テスト用共通ヘッダ */

`ifndef TEST_VH
`define TEST_VH

/* TRUEであることを期待 */
`define ASSERT_TRUE(condition) \
    if (!(condition)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %b", (condition)); \
        $finish; \
    end

/* FALSEであることを期待 */
`define ASSERT_FALSE(condition) `ASSERT_TRUE(!(condition))

/* 期待値との比較 */
`define ASSERT_EQ(actual, expected) \
    if ((actual) !== (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
        $finish; \
    end

/* 期待値と違うこと比較 */
`define ASSERT_NEQ(actual, expected) \
    if ((actual) === (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
        $finish; \
    end

/* TRUEであることを期待 */
`define EXPECT_TRUE(condition) \
    if (!(condition)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %b", (condition)); \
    end

/* FALSEであることを期待 */
`define EXPECT_FALSE(condition) `EXPECT_TRUE(!(condition))

/* 期待値との比較 */
`define EXPECT_EQ(actual, expected) \
    if ((actual) !== (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
    end

/* 期待値と違うことを比較 */
`define EXPECT_NEQ(actual, expected) \
    if ((actual) === (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
    end

`endif /* TEST_VH */
