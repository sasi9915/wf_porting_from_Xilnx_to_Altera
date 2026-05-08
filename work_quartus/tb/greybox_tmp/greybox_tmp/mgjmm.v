//lpm_mult CBX_SINGLE_OUTPUT_FILE="ON" LPM_HINT="DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=9" LPM_PIPELINE=4 LPM_REPRESENTATION="SIGNED" LPM_TYPE="LPM_MULT" LPM_WIDTHA=33 LPM_WIDTHB=16 LPM_WIDTHP=0 LPM_WIDTHS=1 clock dataa datab result
//VERSION_BEGIN 25.1 cbx_mgl 2025:10:22:10:38:57:SC cbx_stratixii 2025:10:22:10:31:18:SC cbx_util_mgl 2025:10:22:10:31:18:SC  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2025  Altera Corporation. All rights reserved.
//  Your use of Altera Corporation's design tools, logic functions 
//  and other software and tools, and any partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Altera Program License 
//  Subscription Agreement, the Altera Quartus Prime License Agreement,
//  the Altera IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Altera and sold by Altera or its authorized distributors.  Please
//  refer to the Altera Software License Subscription Agreements 
//  on the Quartus Prime software download page.



//synthesis_resources = lpm_mult 1 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  mgjmm
	( 
	clock,
	dataa,
	datab,
	result) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   [32:0]  dataa;
	input   [15:0]  datab;
	output   result;

	wire  wire_mgl_prim1_result;

	lpm_mult   mgl_prim1
	( 
	.clock(clock),
	.dataa(dataa),
	.datab(datab),
	.result(wire_mgl_prim1_result));
	defparam
		mgl_prim1.lpm_pipeline = 4,
		mgl_prim1.lpm_representation = "SIGNED",
		mgl_prim1.lpm_type = "LPM_MULT",
		mgl_prim1.lpm_widtha = 33,
		mgl_prim1.lpm_widthb = 16,
		mgl_prim1.lpm_widthp = 0,
		mgl_prim1.lpm_widths = 1,
		mgl_prim1.lpm_hint = "DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=9";
	assign
		result = wire_mgl_prim1_result;
endmodule //mgjmm
//VALID FILE
