# qnigma-hw-c10lp-ek
This is a TCP/IP and Modular Multiplication Unit demo for a [Intel Cyclone 10 LP Evaluation Kit](https://www.intel.com/content/www/us/en/products/details/fpga/development-kits/cyclone/10-lp-evaluation-kit.html).
## What it does?
The repo allows to quickly generate FPGA firmware bitstream built based on [qnigma-rtl](https://github.com/qnigma/qnigma-rtl.git). This is a proof-of-concept design a TCP/IP network-attached multiplier (NAM) modulo curve25519 prime (2^255-19). Networking together with modular arithmetic unit are key modules that compose a hardware SSH implementation. Documentation on main RTL can be found in the project [wiki](https://github.com/qnigma/qnigma-nam-demo/wiki). **Under Development**

## Quick Start

### 1. Install Intel Quartus
Target hardware is Intel Cyclone 10 LP. Latest Intel Quartus Lite version is recommended to use. The default path is `QUARTUS_PATH = ~/intelFPGA_lite/22.1std/quartus/bin/`. If you do not want to alter the Makefile, install Quartus in home directory as shown.

### 2. Install make
Make allows efficient control over the project via cli

### 3. Clone the repository
Run 
```
$ git clone git@github.com:qnigma/qnigma-nam-demo.git --recurse-submodules
```

### 3. Simulating
Go to the main RTL submodule:

```
$ cd qnigma-rtl
```

Run:
```
$ make build-docker # to build Docker image. This might take a while...
$ make tb-nw # simulate network stack
$ make tb-alu # simulate ALU
```

Making `tb-alu` will also generate `ecp_ram_ini.txt` that is necessary for compilation with Quartus in the next step.

### 3. Building
Compile the project from main `qnigma-nam-demo` folder by running:
```
make all
```
Upon successful creation and compilation of the project, .sof programming file is produced.
- To program FPGA (volatile) run `make program`
- To program flash, overwriting previous firmware, run `make program-jic` 

### 4. Connect the board to an IPv6-enabled router
Make sure it is a gigabit connection so is the Ethernet cable. **10Mbps or 100Mbps are currently not supported**.

### 5. Observe the LEDs
All LED off means there is no router detected on the local network
- LED 1 (closer to center of PCB) means TCP connection is established
- LED 2 means the logic waits for DNS server rely 
- LED 3 means the TCP three way hanshake is in progress
- LED 4 means TCP logic is currently disconnecting

### 6. Set up a server with the domain name as in [hdl.sv](https://github.com/qnigma/qnigma-hw-c10lp-ek/blob/main/hw/hdl.sv) 
- Make sure AAAA entries are correctly set
- Start a TCP server on the server at the port specified in hdl.sv (2023)

Troubleshooting:
  - Try to connect to the server via tools like ncat first
  - Use tcpdump or Wireshark to analyze the packets
  - Try pinging the device locally (using link-local address)

## Repository content

### [Makefile](https://github.com/qnigma/qnigma-hw-c10lp-ek/blob/main/Makefile) 
The Makefile allows to build the project, generate configuration files (sof and jic) and program the FPGA or onboard flash.

### Hardware project files
The additional source files necessary to deloy qnigma-rtl to hardware are located in [hw](https://github.com/qnigma/qnigma-hw-c10lp-ek/tree/main/hw) folder. 

#### ip
Intel Quartus PLL IP core instances

#### [Constraints file](https://github.com/qnigma/qnigma-hw-c10lp-ek/blob/main/hw/constraints.sdc) 
Describes clocks and RGMII receive/transmit timing.

#### [Top-level file](https://github.com/qnigma/qnigma-hw-c10lp-ek/blob/main/hw/hdl.sv) 
Instantiates qnigma, RGMII adapted and clock module. Implements simple connection control and data request/reply logic. 

#### [Project settings file](https://github.com/qnigma/qnigma-hw-c10lp-ek/blob/main/hw/settings.qsf) 
Intel Quartus Project settings, including pin assignments and additional files.

## Details

## How to operate
Using the NAM multiplier requires setting up an IPv6-enabled TCP server. In the example scenario, TCP server is running on a remote VPS. Prior running the TCP server and NAM, a DNS AAAA entry has been set up to associate a custom hostname with the VPS Global IPv6 address. In this example, FPGA does not know the IPv6 address of the target server, but only it's hostname. Once set up, make sure that the server is responsive and DNS has updated the entries by pinging it.

User can access the CLI of the remote VPS to start the server:
```
$ ncat -l -p 2023 -6
```
Once FPGA is connected via TCP, (see LED description below), enter x and y values as follows:

First operand:
```
x0000000000000000000000000000000000000000000000000000000000000002
```

Second operand:
```
y3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6
```

Run the multiplication by typing `m`, after which FPGA performs the modular multiplication and returns a 256-bit result. In this case, result is the prime itself minus 1:

```
7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc
```

### Under the hood
Detailed sequence of events is as follows:

1. FPGA boots
2. ICMP logic runs SLAAC to assign itself a link-local IPv6 address, including Duplicate Address Detection. Default IP is generated using EUI-64;
3. Device joins the relevant multicast group and reports it with MLDv2 packet;
4. FPGA requests router information and assigns DNS server IPv6 address from Router Advertisements. Assign default address if router does not provide any. Processes prefix information option and assigns itself a global IPv6 address;
5. Logic attempts to connect to a host via raw TCP. Hostname resolution is performed using DNS servers from previous step;
6. After successfull connection, the FPGA acts as a network-attached calculator.

While connected, logic will perform necessary operations:
1. Periodically send Keepalives
2. Maintain ICMPv6 functionality while connected
3. If connection failed, periodically attempt to reconnect

Note: The demonstrated features set is related to network operation: IPv6, ICMPv6, TCP, DNS. This example **does not include encryption**.

### Timing

### Receive Timing

RGMII is expected to be centre-aligned at receiver. PHY provides centre-aligned interface, so generally, no phase shift is required at receive side so received RGMII data `rgmii_rx_dat` and `rgmii_rx_ctl` are registred directly using `rgmii_rx_clk`.

```
                                                      ┊┌───────┬───────┬───────┬───────┬───────┬───     ───────┬───────┬───────┬───────┐
                                    rgmii_rx_dat     ──┤ [7:4] │ [3:0] │ [7:4] │ [3:0] │ [7:4] │    ***  [7:4] │ [3:0] │ [7:4] │ [3:0] ├───────
                                                      ┊└───────┴───────┴───────┴───────┴───────┴───     ───────┴───────┴───────┴───────┘       
                                                      ┊┌───────────────────────────────────────────────────────────────────────────────┐       
                                    rgmii_rx_ctl     ──┘   ┊                                                                           └───────
                                                      ┊    ┌───────┐       ┌──2────┐       ┌─────── ***    ┌───────┐       ┌───────┐       ┌───
                                    rgmii_rx_clk     ──────┘       └───────┘       └───────┘            ───┘       └───────┘       └───────┘   
                                                           ┌───────────────┬───────────────┬────────────     ──────────────┬────────────────┐  
                                    gmii_rx_dat      ──────┤     [7:0]     │     [7:0]     │     [7:0]   ***    [7:0]      │     [7:0]      ├──
                                                           └───────────────┴───────────────┴────────────     ──────────────┴────────────────┘  
                                                           ┌────────────────────────────────────────────────────────────────────────────────┐  
                                    rgmii_rx_ctl     ──────┘                                                                                └──
```

#### Transmit timing

At transmit side, clock skew is too low for to meet timing for the PHY. A PLL is introduced that that generates 2 125MHz clocks with 90deg phase difference. The clock having 90deg phase shift is used as the physical clock for PHYm thus creating centre-aligned interface.  

```
                                                       ┌────────────────────────────────────────────────────────────────────────────────┐
                                         rgmii_tx_ctl──┘                                                                                └──
                                                       ┌───────────────┬───────────────┬────────────     ──────────────┬────────────────┐  
                                         gmii_tx_dat ──┤     [7:0]     │     [7:0]     │     [7:0]   ***     [7:0]     │     [7:0]      ├──
  ╔ XTAL ╗       ╔══ tx PLL ═╗                         └───────────────┴───────────────┴────────────     ──────────────┴────────────────┘  
  ║      ╠╗      ║           ╠╗                        ┌───────┐       ┌───────┐       ┌───────┐         ──────┐       ┌───────┐           
  ║   clk╟──────►║refclk  clk╟──────► data clk       ──┘       └───────┘       └───────┘       └──── ***       └───────┘       └───────────
  ║      ║║      ║           ║║                                                                                                            
  ║      ║║      ║      clk90╟───╮                    ┊┌───────┬───────┬───────┬───────┬───────┬───     ───────┬───────┬───────┬───────┐   
  ║      ║║      ║           ║║  │    rgmii_tx_dat   ──┤ [7:4] │ [3:0] │ [7:4] │ [3:0] │ [7:4] │    ***  [7:4] │ [3:0] │ [7:4] │ [3:0] ├───
  ╚╦═════╝║      ╚╦══════════╝║  │                    ┊└───────┴───────┴───────┴───────┴───────┴───     ───────┴───────┴───────┴───────┘   
   ╚══════╝       ╚═══════════╝  │                    ┊┌───────────────────────────────────────────────────────────────────────────────┐   
                                 │    rgmii_tx_ctl   ──┘   ┊                                                                           └───
                                 │                    ┊    ┌───────┐       ┌───────┐       ┌─────── ***    ┌───────┐       ┌───────┐       
                                 ╰──► rgmii_tx_clk   ──────┘       └───────┘       └───────┘            ───┘       └───────┘       └───────
```
