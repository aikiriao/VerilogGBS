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

/* 期待値との比較 誤っていてもテストベンチを継続 */
`define EXPECT_EQ(actual, expected) \
    if ((actual) !== (expected)) begin \
        $display("[  FAILED  ] %s:%0d", `__FILE__, `__LINE__); \
        $display("             actual   = %h", (actual)); \
        $display("             expected = %h", (expected)); \
    end

`endif /* TEST_VH */
