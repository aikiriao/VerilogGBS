IVERILOG := iverilog
VVP := vvp
RM_RF := rm -rf

BUILD_DIR := build
FILELIST_DIR := sim/filelist

ifeq ($(OS),Windows_NT)
	RM_RF := rmdir /S /Q
endif

TESTS := $(basename $(notdir $(wildcard $(FILELIST_DIR)/*.f)))

.PHONY: all test clean list $(addprefix test-,$(TESTS))

all: test

clean:
	$(RM_RF) $(BUILD_DIR)

# 全テスト
test: $(TESTS)

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

# 個別テスト
test_%: $(BUILD_DIR)
	$(IVERILOG) \
		-g2001 \
		-s test_$* \
		-I sim/include \
		-f $(FILELIST_DIR)/test_$*.f \
		-o $(BUILD_DIR)/test_$*.vvp
	$(VVP) $(BUILD_DIR)/test_$*.vvp

