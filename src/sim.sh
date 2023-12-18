#!/bin/bash

SRC="i2c_master.vhd \
cpu_to_i2c_master.vhd \
i2c_controller.vhd \
i2c_mem_sim.vhd \
i2c_slave.vhd \
tb_i2c_controller.vhd"

SRC="$SRC \
rtc_master.vhd \
rtc_sim.vhd \
tb_rtc_master.vhd"

SRC="$SRC \
qnice_arbit.vhd \
rtc_controller.vhd \
tb_rtc_controller.vhd"

SRC="$SRC \
rtc_wrapper.vhd \
tb_rtc_wrapper.vhd"


#ghdl compile --std=08 $SRC -r tb_i2c_controller --stop-time=1000us --wave=i2c_controller.ghw
#gtkwave i2c_controller.ghw i2c_controller.gtkw

#ghdl compile --std=08 $SRC -r tb_rtc_master -gG_BOARD=MEGA65_R3 --stop-time=1000us --wave=rtc_master.ghw
#gtkwave rtc_master.ghw rtc_master.gtkw

ghdl compile --std=08 $SRC -r tb_rtc_controller -gG_BOARD=MEGA65_R5 --stop-time=4000us --wave=rtc_controller.ghw
gtkwave rtc_controller.ghw rtc_controller.gtkw

#ghdl compile --std=08 $SRC -r tb_rtc_wrapper -gG_BOARD=MEGA65_R5 --stop-time=200us --wave=rtc_wrapper.ghw
#gtkwave rtc_wrapper.ghw rtc_wrapper.gtkw

