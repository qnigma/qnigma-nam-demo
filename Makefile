ifneq ($(words $(CURDIR)),1)
 $(error Unsupported: GNU Make cannot build in directories containing spaces, build elsewhere: '$(CURDIR)')
endif

PROJECT = c10lp_eval_kit
MAIN_RTL_SUBMODULE = qnigma-rtl

# Other modules
SRC := $(shell find $(MAIN_RTL_SUBMODULE)/src -name '*.sv')

TOP_FILE      = hw/hdl.sv

REFCLK_HZ     = 125000000
    
SRC_V         = $(shell find -name '*.v' | sed 's|^\./||')

SETTINGS_FILE = hw/settings.qsf

REFCLK_FILE   = src/network/refclk.sv

# Hardware sources for Intel FPGA
SRC_HW = $(SRC) $(SRC_V) $(SETTINGS_FILE) $(TOP_FILE)


TOP_LEVEL_ENTITY = top
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf 

FAMILY = "Cyclone 10 LP"
PART = 10CL025YU256I7G

all: smart.log $(PROJECT).asm.rpt $(PROJECT).sta.rpt 

map: smart.log $(PROJECT).map.rpt
fit: smart.log $(PROJECT).fit.rpt
asm: smart.log $(PROJECT).asm.rpt
sta: smart.log $(PROJECT).sta.rpt

smart: smart.log

QUARTUS_PATH = ~/intelFPGA_lite/22.1std/quartus/bin/

QUARTUS_MAP  = $(QUARTUS_PATH)quartus_map
QUARTUS_FIT  = $(QUARTUS_PATH)quartus_fit
QUARTUS_ASM  = $(QUARTUS_PATH)quartus_asm
QUARTUS_STA  = $(QUARTUS_PATH)quartus_sta
QUARTUS_SH   = $(QUARTUS_PATH)quartus_sh
QUARTUS_PGM  = $(QUARTUS_PATH)quartus_pgm
QUARTUS_CPF  = $(QUARTUS_PATH)quartus_cpf

MAP_ARGS = --64bit --read_settings_files=on $(addprefix --source=,$(SRC_HW))
FIT_ARGS = --64bit --part=$(PART) --read_settings_files=on 
ASM_ARGS = --64bit
STA_ARGS = --64bit
SH_ARGS  = --64bit
# PGM_ARGS = --64bit --no_banner --mode=jtag
PGM_ARGS = --64bit --mode=jtag

STAMP = echo done >

############################
## Target implementations ##
############################

$(REFCLK_FILE):
	@printf "localparam REFCLK_HZ = %d;" $(REFCLK_HZ) > $(REFCLK_FILE)

$(PROJECT).map.rpt: map.chg $(SOURCE_FILES) $(REFCLK_FILE)
	$(QUARTUS_MAP) $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

$(PROJECT).fit.rpt: fit.chg $(PROJECT).map.rpt
	$(QUARTUS_FIT) $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT).asm.rpt: asm.chg $(PROJECT).fit.rpt
	$(QUARTUS_ASM) $(ASM_ARGS) $(PROJECT)

$(PROJECT).sta.rpt: sta.chg $(PROJECT).fit.rpt
	$(QUARTUS_STA) $(STA_ARGS) $(PROJECT) 

smart.log: $(ASSIGNMENT_FILES)
	$(QUARTUS_SH) $(SH_ARGS) --determine_smart_action $(PROJECT) > smart.log
	-cat $(SETTINGS_FILE) >> $(PROJECT).qsf

############################
## Project initialization ##
############################

$(ASSIGNMENT_FILES):
	$(QUARTUS_SH) $(SH_ARGS) --prepare -f $(FAMILY) -t $(TOP_LEVEL_ENTITY) $(PROJECT)
map.chg:
	$(STAMP) map.chg
fit.chg:
	$(STAMP) fit.chg
sta.chg:
	$(STAMP) sta.chg
asm.chg:
	$(STAMP) asm.chg

#############
## Program ##
#############

program: $(PROJECT).sof
	$(QUARTUS_PGM) $(PGM_ARGS) -o "P;$(PROJECT).sof"

$(PROJECT).jic: $(PROJECT).sof
	$(QUARTUS_CPF) -c jic.cof

program-jic: $(PROJECT).jic
	$(QUARTUS_PGM) $(PGM_ARGS) -o "IPV;$(PROJECT).jic"

clean:
	$(RM) -rf *.log *.pcap *.txt *.vcd obj_dir  *.rpt *.chg smart.log *.map *.done *.cdf *.htm *.eqn *.pin *.sof *.pof db incremental_db *.summary *.smsg *.jdi *.sld *.qws *.bak $(ASSIGNMENT_FILES)

