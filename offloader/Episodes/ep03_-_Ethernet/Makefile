XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SRCS  = top.vhd cdc.vhd
SRCS += eth/eth_rx.vhd eth/eth_tx.vhd eth/eth.vhd
SRCS += vga/vga.vhd vga/pix.vhd vga/rom.vhd 

top.bit: top.tcl $(SRCS) top.xdc Makefile
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

top.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(SRCS)  }" >> $@
	echo "read_xdc top.xdc" >> $@
	echo "set_property XPM_LIBRARIES {XPM_FIFO} [current_project]" >> $@
	echo "synth_design -top top -part xc7a100tcsg324-1 -flatten_hierarchy none" >> $@
	echo "place_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force top.dcp" >> $@
	echo "write_bitstream -force top.bit" >> $@
	echo "exit" >> $@

fpga: top.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf top.tcl
	rm -rf top.bit
	rm -rf top.dcp
	rm -rf .Xil
	rm -rf .cache

