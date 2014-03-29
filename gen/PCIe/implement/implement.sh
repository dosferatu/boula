#!/bin/sh

# Clean up the results directory
rm -rf results
mkdir results

#Synthesize the Wrapper Files
echo 'Synthesizing example design with XST';
xst -ifn xilinx_pcie_2_0_ep_v6.xst -ofn xilinx_pcie_2_0_ep_v6.log
cp xilinx_pcie_2_0_ep_v6.ngc ./results/

cp xilinx_pcie_2_0_ep_v6.log xst.srp

cd results

echo 'Running ngdbuild'
ngdbuild -verbose -uc ../../example_design/xilinx_pcie_2_0_ep_v6_01_lane_gen1_xc6vlx75t-ff484-3-PCIE_X0Y0.ucf xilinx_pcie_2_0_ep_v6.ngc -sd .


echo 'Running map'
map -w \
  -o mapped.ncd \
  xilinx_pcie_2_0_ep_v6.ngd \
  mapped.pcf

echo 'Running par'
par \
  -w mapped.ncd \
  routed.ncd \
  mapped.pcf

echo 'Running trce'
trce -u -e 100 \
  routed.ncd \
  mapped.pcf

#echo 'Running design through netgen'
netgen -sim -ofmt verilog -ne -w -tm xilinx_pcie_2_0_ep_v6 -sdf_path . routed.ncd

echo 'Running design through bitgen'
bitgen -w routed.ncd

