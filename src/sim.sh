#!/bin/bash

SRC="i2c_master.vhd \
cpu_to_i2c_master.vhd \
i2c_controller.vhd \
i2c_mem_sim.vhd \
i2c_slave.vhd \
tb_i2c.vhd \
rtc_reader.vhd \
rtc.vhd \
rtc_i2c.vhd \
tb_rtc.vhd \
../qnice_arbit.vhd \
tb_rtc_reader.vhd"


#ghdl compile --std=08 $SRC -r tb_i2c --stop-time=1000us --wave=i2c.ghw
#gtkwave i2c.ghw i2c.gtkw

#ghdl compile --std=08 $SRC -r tb_rtc_reader --stop-time=200us --wave=rtc_reader.ghw
#gtkwave rtc_reader.ghw rtc_reader.gtkw

ghdl compile --std=08 $SRC -r tb_rtc --stop-time=200us --wave=rtc.ghw
#gtkwave rtc.ghw rtc.gtkw
