/* テスト用共通ヘッダ */

`ifndef TEST_VH
`define TEST_VH

/* 期待値との比較 誤っていた場合はテストベンチを終了 */
`define ASSERT_EQ(actual, expected) \
    if ((actual) !== (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
        $finish; \
    end

/* 期待値と違うこと比較 同じ場合はテストベンチを終了 */
`define ASSERT_NEQ(actual, expected) \
    if ((actual) === (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
        $finish; \
    end

/* 期待値との比較 誤っていてもテストベンチを継続 */
`define EXPECT_EQ(actual, expected) \
    if ((actual) !== (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
    end

/* 期待値と違うことを比較 同じでもテストベンチを継続 */
`define EXPECT_NEQ(actual, expected) \
    if ((actual) === (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
    end

`endif /* TEST_VH */
