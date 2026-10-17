IVERILOG := iverilog
VVP := vvp
VERILATOR := verilator
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
	$(VERILATOR) \
		--lint-only -Wall --default-language 1364-2001 -Wno-MULTITOP -Wno-UNUSEDPARAM --no-sched-zero-delay --report-unoptflat \
		-Irtl/include \
		-Isim/include \
	   	-f $(FILELIST_DIR)/test_$*.f
	$(IVERILOG) \
		-g2001 -Wall -Wno-sensitivity-entire-array \
		-s test_$* \
		-I rtl/include \
		-I sim/include \
		-f $(FILELIST_DIR)/test_$*.f \
		-o $(BUILD_DIR)/test_$*.vvp
	$(VVP) $(BUILD_DIR)/test_$*.vvp

