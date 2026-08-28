IVERILOG := iverilog
VVP      := vvp

BUILD_DIR   := build
FILELIST_DIR := sim/filelist

TESTS := $(basename $(notdir $(wildcard $(FILELIST_DIR)/*.f)))

.PHONY: all test clean list $(addprefix test-,$(TESTS))

all: test

clean:
	rm -rf $(BUILD_DIR)

# 全テスト
test: $(TESTS)

# 個別テスト
test_%:
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) \
		-g2001 \
		-s test_$* \
		-I sim/include \
		-f $(FILELIST_DIR)/test_$*.f \
		-o $(BUILD_DIR)/test_$*.vvp
	$(VVP) $(BUILD_DIR)/test_$*.vvp

