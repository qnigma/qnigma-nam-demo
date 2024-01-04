####################
# Reference clocks #
####################
create_clock -name clk_125m          -period 8.0  -waveform {0 4}  [get_ports {gen_clk_125m}]
create_clock -name clk_100m          -period 10.0 -waveform {0 5}  [get_ports {gen_clk_100m}]
create_clock -name clk_50m           -period 20.0 -waveform {0 10} [get_ports {gen_clk_50m}]
create_clock -name clk_rx            -period 8.0  -waveform {2 6}  [get_ports {rgmii_rx_clk}]
create_clock -name virt_rgmii_rx_clk -period 8.0  -waveform {0 4}


##############
# PLL clocks #
##############
# create_generated_clock -name rx_data_clk \
# -source       [get_pins {rgmii_adapter_inst|rgmii_rx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
# -master_clock           {clk_rx} \
# [get_pins               {rgmii_adapter_inst|rgmii_rx_pll_inst|altpll_component|auto_generated|pll1|clk[0]}]\
# -add \
# -phase 90  \
# -duty_cycle   50.00

#create_generated_clock -name tx_data_clk \
#-source        [get_pins {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
#-master_clock            {clk_125m} \
#[get_pins                {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|clk[1]}]\
#-add \
#-phase 90  \
#-duty_cycle   50.00 \

create_generated_clock -name int_data_clk \
-source        [get_pins {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
-master_clock            {clk_125m} \
[get_pins                {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|clk[0]}]\
-add \
-phase 90  \
-duty_cycle   50.00 \

create_generated_clock -name out_data_clk \
-source        [get_pins {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
-master_clock            {clk_125m} \
[get_pins                {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|clk[1]}]\
-add \
-duty_cycle   50.00 \

##############
# I/O clocks #
##############
create_generated_clock -name gtx_clk \
-source [get_pins {rgmii_adapter_inst|altddio_out_clk_inst|auto_generated|ddio_outa[0]|dataout}] \
-master_clock {out_data_clk} \
[get_ports {rgmii_gtx_clk}]
#################
# I/O clocks #
#################

# rgmii rx virtual clock

#-group {clk_100m} \
#-group {clk_50m}

#####################
# Input constraints #
#####################

set_input_delay -clock virt_rgmii_rx_clk -min  -1.5 [get_ports {rgmii_rx_dat[*] rgmii_rx_ctl}]
set_input_delay -clock virt_rgmii_rx_clk -max  0.5 [get_ports {rgmii_rx_dat[*] rgmii_rx_ctl}]
set_input_delay -clock virt_rgmii_rx_clk -min  -1.5 [get_ports {rgmii_rx_dat[*] rgmii_rx_ctl}] -clock_fall -add_delay
set_input_delay -clock virt_rgmii_rx_clk -max  0.5 [get_ports {rgmii_rx_dat[*] rgmii_rx_ctl}] -clock_fall -add_delay

# Don't analyze virt_rgmii_rx_clk -> rx_data_clk
set_false_path -setup -rise_from   [get_clocks virt_rgmii_rx_clk] -fall_to  [get_clocks clk_rx]
set_false_path -setup -fall_from   [get_clocks virt_rgmii_rx_clk] -rise_to  [get_clocks clk_rx]
set_false_path -hold  -rise_from   [get_clocks virt_rgmii_rx_clk] -rise_to  [get_clocks clk_rx]
set_false_path -hold  -fall_from   [get_clocks virt_rgmii_rx_clk] -fall_to  [get_clocks clk_rx]

######################
# Output constraints #
######################

# set_multicycle_path 0 -setup -end -rise_from  [get_clocks rgmii_tx_clk_pll] -rise_to [get_clocks gtx_clk] 
# set_multicycle_path 0 -setup -end -fall_from  [get_clocks rgmii_tx_clk_pll] -fall_to [get_clocks gtx_clk] 

set_output_delay -min -1 -clock [get_clocks gtx_clk] [get_ports {rgmii_tx_dat[*] rgmii_tx_ctl}]
set_output_delay -max  1 -clock [get_clocks gtx_clk] [get_ports {rgmii_tx_dat[*] rgmii_tx_ctl}]
set_output_delay -min -1 -clock [get_clocks gtx_clk] [get_ports {rgmii_tx_dat[*] rgmii_tx_ctl}] -clock_fall -add_delay
set_output_delay -max  1 -clock [get_clocks gtx_clk] [get_ports {rgmii_tx_dat[*] rgmii_tx_ctl}] -clock_fall -add_delay

set_false_path -rise_from [get_clocks int_data_clk] -fall_to [get_clocks gtx_clk] -setup
set_false_path -fall_from [get_clocks int_data_clk] -rise_to [get_clocks gtx_clk] -setup
set_false_path -rise_from [get_clocks int_data_clk] -rise_to [get_clocks gtx_clk] -hold
set_false_path -fall_from [get_clocks int_data_clk] -fall_to [get_clocks gtx_clk] -hold

set_false_path -from [get_pins {rgmii_adapter_inst|rgmii_tx_pll_inst|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {gtx_clk}]

set_clock_groups \
    -exclusive \
    -group [get_clocks clk_rx] \
    -group [get_clocks int_data_clk]


derive_clock_uncertainty
# -1.0 1.5 
#  1.0 2.5 
# -1.0 1.5 
#  1.0 2.5 
