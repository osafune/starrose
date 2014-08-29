# TCL File Generated by Component Editor 13.1
# Fri May 30 01:58:40 JST 2014
# DO NOT MODIFY


# 
# gpu_component "gpu_component" v0.9
# S.OSAFUNE / J-7SYSTEM Works 2014.05.30.01:58:40
# STARROSE GPU for PERIDOT with LCD-Module
# 

# 
# request TCL package from ACDS 13.1
# 
package require -exact qsys 13.1


# 
# module gpu_component
# 
set_module_property DESCRIPTION "STARROSE GPU for PERIDOT with LCD-Module"
set_module_property NAME gpu_component
set_module_property VERSION 0.9
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR "S.OSAFUNE / J-7SYSTEM Works"
set_module_property DISPLAY_NAME gpu_component
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property ANALYZE_HDL AUTO
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL gpu_component
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
add_fileset_file gpu_component.vhd VHDL PATH gpu_component.vhd TOP_LEVEL_FILE
add_fileset_file GPU_REGISTER.vhd VHDL PATH GPU_REGISTER.vhd
add_fileset_file lcdc_component_gpu.vhd VHDL PATH lcdc_component_gpu.vhd
add_fileset_file lcdc_dma.vhd VHDL PATH lcdc_dma.vhd
add_fileset_file lcdc_dmafifo.vhd VHDL PATH lcdc_dmafifo.vhd
add_fileset_file lcdc_regs.vhd VHDL PATH lcdc_regs.vhd
add_fileset_file lcdc_wrstate.vhd VHDL PATH lcdc_wrstate.vhd
add_fileset_file multiple_5x5.vhd VHDL PATH multiple_5x5.vhd
add_fileset_file multiple_5x8.vhd VHDL PATH multiple_5x8.vhd
add_fileset_file PROCYON_GPU.vhd VHDL PATH PROCYON_GPU.vhd
add_fileset_file REGISTER_Intensity.vhd VHDL PATH REGISTER_Intensity.vhd
add_fileset_file REGISTER_Render.vhd VHDL PATH REGISTER_Render.vhd
add_fileset_file RENDER_ColorConv.vhd VHDL PATH RENDER_ColorConv.vhd
add_fileset_file RENDER_CORE.vhd VHDL PATH RENDER_CORE.vhd
add_fileset_file RENDER_Texture.vhd VHDL PATH RENDER_Texture.vhd
add_fileset_file SDRAM_IF.vhd VHDL PATH SDRAM_IF.vhd
add_fileset_file SEQUENCER_CommandCtrl.vhd VHDL PATH SEQUENCER_CommandCtrl.vhd
add_fileset_file SEQUENCER_CommandRom.vhd VHDL PATH SEQUENCER_CommandRom.vhd
add_fileset_file SEQUENCER_UNIT.vhd VHDL PATH SEQUENCER_UNIT.vhd
add_fileset_file SuperJ7_package.vhd VHDL PATH SuperJ7_package.vhd


# 
# parameters
# 


# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock csi_clk clk Input 1


# 
# connection point clock_reset
# 
add_interface clock_reset reset end
set_interface_property clock_reset associatedClock clock
set_interface_property clock_reset synchronousEdges DEASSERT
set_interface_property clock_reset ENABLED true
set_interface_property clock_reset EXPORT_OF ""
set_interface_property clock_reset PORT_NAME_MAP ""
set_interface_property clock_reset CMSIS_SVD_VARIABLES ""
set_interface_property clock_reset SVD_ADDRESS_GROUP ""

add_interface_port clock_reset csi_reset reset Input 1


# 
# connection point s1
# 
add_interface s1 avalon end
set_interface_property s1 addressUnits WORDS
set_interface_property s1 associatedClock clock
set_interface_property s1 associatedReset clock_reset
set_interface_property s1 bitsPerSymbol 8
set_interface_property s1 burstOnBurstBoundariesOnly false
set_interface_property s1 burstcountUnits WORDS
set_interface_property s1 explicitAddressSpan 0
set_interface_property s1 holdTime 0
set_interface_property s1 linewrapBursts false
set_interface_property s1 maximumPendingReadTransactions 0
set_interface_property s1 readLatency 0
set_interface_property s1 readWaitStates 2
set_interface_property s1 readWaitTime 2
set_interface_property s1 setupTime 0
set_interface_property s1 timingUnits Cycles
set_interface_property s1 writeWaitTime 0
set_interface_property s1 ENABLED true
set_interface_property s1 EXPORT_OF ""
set_interface_property s1 PORT_NAME_MAP ""
set_interface_property s1 CMSIS_SVD_VARIABLES ""
set_interface_property s1 SVD_ADDRESS_GROUP ""

add_interface_port s1 avs_s1_address address Input 5
add_interface_port s1 avs_s1_read read Input 1
add_interface_port s1 avs_s1_readdata readdata Output 32
add_interface_port s1 avs_s1_write write Input 1
add_interface_port s1 avs_s1_writedata writedata Input 32
set_interface_assignment s1 embeddedsw.configuration.isFlash 0
set_interface_assignment s1 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s1 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s1 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point interrupt_s1
# 
add_interface interrupt_s1 interrupt end
set_interface_property interrupt_s1 associatedAddressablePoint s1
set_interface_property interrupt_s1 associatedClock clock
set_interface_property interrupt_s1 associatedReset clock_reset
set_interface_property interrupt_s1 ENABLED true
set_interface_property interrupt_s1 EXPORT_OF ""
set_interface_property interrupt_s1 PORT_NAME_MAP ""
set_interface_property interrupt_s1 CMSIS_SVD_VARIABLES ""
set_interface_property interrupt_s1 SVD_ADDRESS_GROUP ""

add_interface_port interrupt_s1 ins_s1_irq irq Output 1


# 
# connection point s2
# 
add_interface s2 avalon end
set_interface_property s2 addressUnits WORDS
set_interface_property s2 associatedClock clock
set_interface_property s2 associatedReset clock_reset
set_interface_property s2 bitsPerSymbol 8
set_interface_property s2 burstOnBurstBoundariesOnly false
set_interface_property s2 burstcountUnits WORDS
set_interface_property s2 explicitAddressSpan 0
set_interface_property s2 holdTime 0
set_interface_property s2 linewrapBursts false
set_interface_property s2 maximumPendingReadTransactions 0
set_interface_property s2 readLatency 0
set_interface_property s2 readWaitTime 1
set_interface_property s2 setupTime 0
set_interface_property s2 timingUnits Cycles
set_interface_property s2 writeWaitTime 0
set_interface_property s2 ENABLED true
set_interface_property s2 EXPORT_OF ""
set_interface_property s2 PORT_NAME_MAP ""
set_interface_property s2 CMSIS_SVD_VARIABLES ""
set_interface_property s2 SVD_ADDRESS_GROUP ""

add_interface_port s2 avs_s2_address address Input 2
add_interface_port s2 avs_s2_read read Input 1
add_interface_port s2 avs_s2_readdata readdata Output 32
add_interface_port s2 avs_s2_write write Input 1
add_interface_port s2 avs_s2_writedata writedata Input 32
set_interface_assignment s2 embeddedsw.configuration.isFlash 0
set_interface_assignment s2 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s2 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s2 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point interrupt_s2
# 
add_interface interrupt_s2 interrupt end
set_interface_property interrupt_s2 associatedAddressablePoint s2
set_interface_property interrupt_s2 associatedClock clock
set_interface_property interrupt_s2 associatedReset clock_reset
set_interface_property interrupt_s2 ENABLED true
set_interface_property interrupt_s2 EXPORT_OF ""
set_interface_property interrupt_s2 PORT_NAME_MAP ""
set_interface_property interrupt_s2 CMSIS_SVD_VARIABLES ""
set_interface_property interrupt_s2 SVD_ADDRESS_GROUP ""

add_interface_port interrupt_s2 ins_s2_irq irq Output 1


# 
# connection point s3
# 
add_interface s3 avalon end
set_interface_property s3 addressUnits SYMBOLS
set_interface_property s3 associatedClock clock
set_interface_property s3 associatedReset clock_reset
set_interface_property s3 bitsPerSymbol 8
set_interface_property s3 burstOnBurstBoundariesOnly false
set_interface_property s3 burstcountUnits WORDS
set_interface_property s3 explicitAddressSpan 0
set_interface_property s3 holdTime 0
set_interface_property s3 linewrapBursts false
set_interface_property s3 maximumPendingReadTransactions 0
set_interface_property s3 readLatency 0
set_interface_property s3 readWaitTime 1
set_interface_property s3 setupTime 0
set_interface_property s3 timingUnits Cycles
set_interface_property s3 writeWaitTime 0
set_interface_property s3 ENABLED true
set_interface_property s3 EXPORT_OF ""
set_interface_property s3 PORT_NAME_MAP ""
set_interface_property s3 CMSIS_SVD_VARIABLES ""
set_interface_property s3 SVD_ADDRESS_GROUP ""

add_interface_port s3 avs_s3_chipselect chipselect Input 1
add_interface_port s3 avs_s3_address address Input 25
add_interface_port s3 avs_s3_read read Input 1
add_interface_port s3 avs_s3_readdata readdata Output 32
add_interface_port s3 avs_s3_write write Input 1
add_interface_port s3 avs_s3_writedata writedata Input 32
add_interface_port s3 avs_s3_byteenable byteenable Input 4
add_interface_port s3 avs_s3_waitrequest waitrequest Output 1
set_interface_assignment s3 embeddedsw.configuration.isFlash 0
set_interface_assignment s3 embeddedsw.configuration.isMemoryDevice 1
set_interface_assignment s3 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s3 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point sdr
# 
add_interface sdr conduit end
set_interface_property sdr associatedClock clock
set_interface_property sdr associatedReset clock_reset
set_interface_property sdr ENABLED true
set_interface_property sdr EXPORT_OF ""
set_interface_property sdr PORT_NAME_MAP ""
set_interface_property sdr CMSIS_SVD_VARIABLES ""
set_interface_property sdr SVD_ADDRESS_GROUP ""

add_interface_port sdr coe_sdr_cke export Output 1
add_interface_port sdr coe_sdr_cs_n export Output 1
add_interface_port sdr coe_sdr_ras_n export Output 1
add_interface_port sdr coe_sdr_cas_n export Output 1
add_interface_port sdr coe_sdr_we_n export Output 1
add_interface_port sdr coe_sdr_ba export Output 2
add_interface_port sdr coe_sdr_a export Output 13
add_interface_port sdr coe_sdr_dq export Bidir 16
add_interface_port sdr coe_sdr_dqm export Output 2


# 
# connection point lcd
# 
add_interface lcd conduit end
set_interface_property lcd associatedClock clock
set_interface_property lcd associatedReset clock_reset
set_interface_property lcd ENABLED true
set_interface_property lcd EXPORT_OF ""
set_interface_property lcd PORT_NAME_MAP ""
set_interface_property lcd CMSIS_SVD_VARIABLES ""
set_interface_property lcd SVD_ADDRESS_GROUP ""

add_interface_port lcd coe_lcd_rst_n export Output 1
add_interface_port lcd coe_lcd_cs_n export Output 1
add_interface_port lcd coe_lcd_rs export Output 1
add_interface_port lcd coe_lcd_wr_n export Output 1
add_interface_port lcd coe_lcd_d export Bidir 8
