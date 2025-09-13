TARGET_DIR ?= .
EXCLUDE_DIRS ?= ./examples

EXCLUDE_DIRS := $(shell echo $(EXCLUDE_DIRS) | sed 's:/*$$::')


SOURCES := $(shell \
	find $(TARGET_DIR) $(foreach dir,$(EXCLUDE_DIRS),-path $(dir) -prune -o) -name '*.v' -not -name '*_tb.v' -print \
)

TB_SOURCES := $(shell \
	find $(TARGET_DIR) $(foreach dir,$(EXCLUDE_DIRS),-path $(dir) -prune -o) -name '*_tb.v' -print \
)

VCD_FILES := $(shell \
	find $(TARGET_DIR) $(foreach dir,$(EXCLUDE_DIRS),-path $(dir) -prune -o) -name '*.vcd' -print \
)

TB_DSN := $(TB_SOURCES:%.v=%.dsn)
TB_DSN_RES := $(TB_SOURCES:%.v=%.dsn.result)


DOCKER=docker
PWD = $(shell pwd)
DOCKERARGS = run --rm -v $(PWD):/src -w /src

YOSYS     = $(DOCKER) $(DOCKERARGS) ghdl/synth:beta yosys
NEXTPNR   = $(DOCKER) $(DOCKERARGS) ghdl/synth:nextpnr-ecp5 nextpnr-ecp5
ECPPACK   = $(DOCKER) $(DOCKERARGS) ghdl/synth:trellis ecppack
ECPPLL	  = $(DOCKER) $(DOCKERARGS) ghdl/synth:trellis ecppll
OPENOCD   = $(DOCKER) $(DOCKERARGS) --device /dev/bus/usb ghdl/synth:prog openocd
IVERILOG  = $(DOCKER) $(DOCKERARGS) alfredosavi/icarus iverilog
VVP       = $(DOCKER) $(DOCKERARGS) alfredosavi/icarus vvp
LITEETH   = $(DOCKER) $(DOCKERARGS) liteeth-env liteeth_gen


LPF=constraints/ecp5-hub75b_v82.lpf	# <-- MUDAR DE ACORDO COM A VERSAO DA PLACA -->
PACKAGE=CABGA256						# <-- MUDAR DE ACORDO COM O PACKAGE DO FPGA -->

NEXTPNR_FLAGS=--25k --freq 25 --speed 6 --write top-post-route.json
OPENOCD_JTAG_CONFIG=openocd/ft232.cfg
OPENOCD_DEVICE_CONFIG=openocd/LFE5U-25F.cfg

# VAR
PLL_CLOCK_IN ?= 25
PLL_CLOCK_OUT ?= 125
YML_FILE ?= ./liteeth.yml

# Defines
define PRINT_HELP
	@echo "Makefile commands available:"
	@echo "  make            	: build the bitstream (run 'make help_all' for details)"
	@echo "  make test       	: run all testbenches"
	@echo "  make prog       	: program the FPGA (top.svf) using openOCD"
	@echo "  make clean      	: clean all generated files (run 'make help_clean')"
	@echo "  make artifacts  	: compose artifacts.tar.bz2 with bitstream and test results"
	@echo "  make liteeth_gen	: generate LiteEth files (requires liteeth.yml) (run 'make help_liteeth')"
	@echo "  make pll        	: generate PLL file (pll.v) using ECPPLL (run 'make help_pll')"
	@echo "  make help       	: show this help message"
endef


define PRINT_HELP_ALL
	@echo "Build the FPGA bitstream (top.svf)"
	@echo "Usage: make or make all"
	@echo "Runs the full flow: Yosys -> NextPNR -> ECPPACK -> generates top.svf"
	@echo ""
	@echo "Optional variables:"
	@echo "  TARGET_DIR    : Directory to search for Verilog sources (default: .)"
	@echo "                  Example: make all TARGET_DIR=./examples/blink"
	@echo "  EXCLUDE_DIRS  : Directories to exclude, comma or space separated (default: ./examples)"
	@echo "                  Example: make all EXCLUDE_DIRS=tests,docs"
endef


define PRINT_HELP_LITEETH
	@echo "Generate LiteEth gateware files using liteeth.yml"
	@echo "Usage: make liteeth_gen"
	@echo "You can specify the YML file with the YML_FILE variable (default: ./liteeth.yml)"
	@echo "Example: make liteeth_gen YML_FILE=./my_liteeth.yml"
endef

define PRINT_HELP_PLL
	@echo "Generate PLL file (pll.v) using ECPPLL"
	@echo "Usage: make pll"
	@echo "You can specify the input and output clock frequencies using the following variables:"
	@echo "  PLL_CLOCK_IN   : Input clock frequency in MHz (default: 25)"
	@echo "  PLL_CLOCK_OUT  : Output clock frequency in MHz (default: 125)"
	@echo ""
	@echo "Example: make pll PLL_CLOCK_IN=50 PLL_CLOCK_OUT=100"
endef

define PRINT_HELP_CLEAN
	@echo "Clean all generated files"
	@echo "Usage: make clean"
	@echo "Removes build artifacts, bitstreams, simulation results, and temporary files"
endef


all: top.svf

help:
	$(PRINT_HELP)

help_all:
	$(PRINT_HELP_ALL)

help_liteeth:
	$(PRINT_HELP_LITEETH)

help_pll:
	$(PRINT_HELP_PLL)

help_clean:
	$(PRINT_HELP_CLEAN)

%.dsn: %.v
	@echo "Compiling testbench $< -> $@"
	@$(IVERILOG) -o $@ $< $(SOURCES)

%.dsn.result: %.dsn
	@echo "Running test $(@:%.dsn.result=%.dsn) -> $@"
	@$(VVP) $(@:%.dsn.result=%.dsn) | tee $@
	@! grep -q NOK $@ || (echo "Test $@ failed"; exit 1)


test: $(TB_DSN) $(TB_DSN_RES)
	@for test in $^; do echo "Running test $$test"; done

liteeth_gen: $(YML_FILE)
	$(LITEETH) --gateware-dir build --no-compile-software $(YML_FILE)

pll:
	$(ECPPLL) -i $(PLL_CLOCK_IN) --clkout0_name clock --clkout0 $(PLL_CLOCK_OUT) -f ./pll.v


YOSYS_SCRIPT := syn.ys

$(YOSYS_SCRIPT):
	echo "" > $@
	@for file in $(SOURCES); do echo "read_verilog $$file" >> $@; done
	echo "synth_ecp5 -top top" >> $@

top.json: $(YOSYS_SCRIPT) $(SOURCES)
	$(YOSYS) -s $< -o $@

top.config: top.json $(LPF)
	$(NEXTPNR) --json $< --lpf $(LPF) --textcfg $@ $(NEXTPNR_FLAGS) --package $(PACKAGE)

top.svf: top.config
	$(ECPPACK) --svf top.svf $<

prog: top.svf
	$(OPENOCD) -f $(OPENOCD_JTAG_CONFIG) -f $(OPENOCD_DEVICE_CONFIG) -c "transport select jtag; init; svf $<; exit"

artifacts: test top.svf
	@echo "Composing artifacts"
	@mkdir -p artifacts
	tar -cvjpf artifacts.tar.bz2 top.svf $(VCD_FILES);

clean:
	@rm -f work-obj08.cf *.bit *.json *.svf *.config syn.ys artifacts $(TB_DSN) $(VCD_FILES) $(TB_DSN_RES)

.PHONY: all clean test prog artifacts liteeth_gen pll help help_pll
.PRECIOUS: top.json
