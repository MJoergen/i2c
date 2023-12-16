#!/bin/bash

SRC="i2c_master.vhd \
cpu_to_i2c_master.vhd \
i2c_controller.vhd \
i2c_mem_sim.vhd \
i2c_slave.vhd \
tb_i2c_controller.vhd \
rtc_controller.vhd \
rtc.vhd \
rtc_i2c.vhd \
tb_rtc.vhd \
qnice_arbit.vhd \
tb_rtc_controller.vhd"


#ghdl compile --std=08 $SRC -r tb_i2c_controller --stop-time=1000us --wave=i2c_controller.ghw
#gtkwave i2c_controller.ghw i2c_controller.gtkw

ghdl compile --std=08 $SRC -r tb_rtc_controller --stop-time=200us --wave=rtc_controller.ghw
gtkwave rtc_controller.ghw rtc_controller.gtkw

#ghdl compile --std=08 $SRC -r tb_rtc --stop-time=200us --wave=rtc.ghw
#gtkwave rtc.ghw rtc.gtkw
