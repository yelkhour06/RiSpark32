//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: V1.9.9 Beta-5
//Created Time: 2023-11-05 12:01:42
//90M 
create_clock -name clk -period 11.11 -waveform {0 5.55} [get_ports {clk}]
//create_clock -name clk -period 100 -waveform {0 50} [get_ports {clk}]
//create_clock -name clk -period 37.04 -waveform {0 18.52} [get_ports {clk}] -add