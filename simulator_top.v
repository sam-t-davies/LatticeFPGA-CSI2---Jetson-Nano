module simulator_top (
           top_clarity_tx_clk_n_o, top_clarity_tx_clk_p_o, top_clarity_tx_d0_n_io, top_clarity_tx_d0_p_io, 
           top_clarity_tx_d1_n_o, top_clarity_tx_d1_p_o, top_clarity_tx_reset_n_i, top_clarity_tx_i2c_slave_scl_i,
		   top_clarity_tx_i2c_slave_sda_io, top_clarity_led_o) ;   
    inout  top_clarity_tx_clk_n_o;
    inout  top_clarity_tx_clk_p_o;
    inout  top_clarity_tx_d0_n_io;
    inout  top_clarity_tx_d0_p_io;
    inout  top_clarity_tx_d1_n_o;
    inout  top_clarity_tx_d1_p_o;
	input  top_clarity_tx_reset_n_i;
    input  top_clarity_tx_i2c_slave_scl_i;
    inout  top_clarity_tx_i2c_slave_sda_io;	
	output [3:0]top_clarity_led_o;
		
	wire [63:0]top_clarity_tx_byte_data_w;
	wire [5:0]top_clarity_tx_dt_w;
	wire [7:0]top_clarity_tx_frame_max_w;
	wire [1:0]top_clarity_tx_vc_w;
	wire [15:0]top_clarity_tx_wc_w;
	wire top_clarity_tx_byte_clk_w;
	wire top_clarity_tx_byte_data_en_w;
	wire top_clarity_tx_c2d_ready_w;
	wire top_clarity_tx_clk_hs_en_w;
	wire top_clarity_tx_d_hs_en_w;
	wire top_clarity_tx_d_hs_rdy_w;
	wire top_clarity_tx_ld_pyld_w;
	wire top_clarity_tx_lp_en_w;
	wire top_clarity_tx_pd_dphy_w;
	wire top_clarity_tx_pix2byte_rstn_w;
	wire top_clarity_tx_pll_lock_w;
	wire top_clarity_tx_sp_en_w;
	wire top_clarity_tx_tinit_done_w;	
	wire top_clarity_tx_ref_clk_w;
	wire top_clarity_tx_start_stream_w;
	wire top_clarity_tx_reset_n_w;
	
	wire [9:0]top_clarity_tx_pixel_red_w;
	wire [9:0]top_clarity_tx_pixel_green_red_w;
	wire [9:0]top_clarity_tx_pixel_green_blue_w;
	wire [9:0]top_clarity_tx_pixel_blue_w;
	
	wire [11:0]top_clarity_tx_num_lines_w;
	wire [11:0]top_clarity_tx_hori_pixel_w;

	
	//On-chip Clock. Freq = 48Mhz/HFCLKDIV
	defparam I1.HFCLKDIV = 1; 
    OSCI I1 (
        .HFOUTEN(1),
        .HFCLKOUT(top_clarity_tx_ref_clk_w),
        .LFCLKOUT(LFCLKOUT));
		
	//Some debug LEDs for the board. 
	// I2C: LED[0-1] are LEDS D6&D7 on the board (SCL & SDA)
	//LED[2] is D8 on board and flashes when streaming.
	//LED[3] is D9 on board and is value of top_clarity_tx_start_stream_w which is on=stream
	assign top_clarity_led_o[0] = i2c_slave_led_w[0];
	assign top_clarity_led_o[1] = i2c_slave_led_w[1];
	assign top_clarity_led_o[2] = csi2_tx_led_w[2];
	assign top_clarity_led_o[3] = i2c_slave_led_w[3];
	
	csi2_output clarity_tx2_inst (.csi2_raw10_output_byte_data_i(top_clarity_tx_byte_data_w), .csi2_raw10_output_dt_i(top_clarity_tx_dt_w), 
            .csi2_raw10_output_frame_max_i(top_clarity_tx_frame_max_w), .csi2_raw10_output_vc_i(top_clarity_tx_vc_w), 
            .csi2_raw10_output_wc_i(top_clarity_tx_wc_w), .csi2_raw10_output_byte_clk_o(top_clarity_tx_byte_clk_w), 
            .csi2_raw10_output_byte_data_en_i(top_clarity_tx_byte_data_en_w), .csi2_raw10_output_c2d_ready_o(top_clarity_tx_c2d_ready_w), 
            .csi2_raw10_output_clk_hs_en_i(top_clarity_tx_clk_hs_en_w), .csi2_raw10_output_clk_n_o(top_clarity_tx_clk_n_o), 
            .csi2_raw10_output_clk_p_o(top_clarity_tx_clk_p_o), .csi2_raw10_output_d0_n_io(top_clarity_tx_d0_n_io), 
            .csi2_raw10_output_d0_p_io(top_clarity_tx_d0_p_io), .csi2_raw10_output_d1_n_o(top_clarity_tx_d1_n_o), .csi2_raw10_output_d1_p_o(top_clarity_tx_d1_p_o), 
            .csi2_raw10_output_d_hs_en_i(top_clarity_tx_d_hs_en_w), .csi2_raw10_output_d_hs_rdy_o(top_clarity_tx_d_hs_rdy_w), 
            .csi2_raw10_output_ld_pyld_o(top_clarity_tx_ld_pyld_w), .csi2_raw10_output_lp_en_i(top_clarity_tx_lp_en_w), 
            .csi2_raw10_output_pd_dphy_i(top_clarity_tx_pd_dphy_w), .csi2_raw10_output_pix2byte_rstn_o(top_clarity_tx_pix2byte_rstn_w), 
            .csi2_raw10_output_pll_lock_o(top_clarity_tx_pll_lock_w), .csi2_raw10_output_ref_clk_i(top_clarity_tx_ref_clk_w), 
            .csi2_raw10_output_reset_n_i(top_clarity_tx_reset_n_w), .csi2_raw10_output_sp_en_i(top_clarity_tx_sp_en_w), 
            .csi2_raw10_output_tinit_done_o(top_clarity_tx_tinit_done_w));
			
	wire [3:0]csi2_tx_led_w;
	csi2_tx_simulator_ctrl ctrl_inst(
	        .ctrl_tx_reset_i(top_clarity_tx_reset_n_w), 
			.ctrl_tx_start_stream_i(top_clarity_tx_start_stream_w),
			//.ctrl_tx_start_stream_i(1),                                 //to simulate the waveforms comment out above line and add this in
	        .ctrl_ref_clk_i(top_clarity_tx_ref_clk_w),
	        .ctrl_tx_byte_clk_i(top_clarity_tx_byte_clk_w),
	        .ctrl_tx_c2d_ready_i(top_clarity_tx_c2d_ready_w),
	        .ctrl_tx_d_hs_rdy_i(top_clarity_tx_d_hs_rdy_w),
	        .ctrl_tx_ld_pyld_i(top_clarity_tx_ld_pyld_w),
	        .ctrl_tx_pix2byte_rstn_i(top_clarity_tx_pix2byte_rstn_w),
	        .ctrl_tx_pll_lock_i(top_clarity_tx_pll_lock_w),
	        .ctrl_tx_tinit_done_i(top_clarity_tx_tinit_done_w),
			.ctrl_tx_pixel_red_i(top_clarity_tx_pixel_red_w),
			.ctrl_tx_pixel_green_red_i(top_clarity_tx_pixel_green_red_w),
			.ctrl_tx_pixel_green_blue_i(top_clarity_tx_pixel_green_blue_w),
			.ctrl_tx_pixel_blue_i(top_clarity_tx_pixel_blue_w),
	        .ctrl_tx_byte_data_o(top_clarity_tx_byte_data_w),
	        .ctrl_tx_dt_o(top_clarity_tx_dt_w),
	        .ctrl_tx_frame_max_o(top_clarity_tx_frame_max_w),
	        .ctrl_tx_vc_o(top_clarity_tx_vc_w),
	        .ctrl_tx_wc_o(top_clarity_tx_wc_w),
	        .ctrl_tx_byte_data_en_o(top_clarity_tx_byte_data_en_w),
	        .ctrl_tx_clk_hs_en_o(top_clarity_tx_clk_hs_en_w),
	        .ctrl_tx_d_hs_en_o(top_clarity_tx_d_hs_en_w),
	        .ctrl_tx_lp_en_o(top_clarity_tx_lp_en_w),
	        .ctrl_tx_pd_dphy_o(top_clarity_tx_pd_dphy_w),	        
	        .ctrl_tx_sp_en_o(top_clarity_tx_sp_en_w),
			.ctrl_tx_line_num_o(top_clarity_tx_num_lines_w),
            .ctrl_tx_byte_en_timer_o(top_clarity_tx_hori_pixel_w),	
            .ctrl_tx_led_o(	csi2_tx_led_w)	
	); 
	
	wire [3:0]i2c_slave_led_w;    i2c_slave_top i2c_module(
	        .i2c_slave_top_ref_clk_i(top_clarity_tx_ref_clk_w),
	        .i2c_slave_top_reset_i(top_clarity_tx_reset_n_w), 
			.i2c_slave_scl_i(top_clarity_tx_i2c_slave_scl_i), 
			.i2c_slave_sda_io(top_clarity_tx_i2c_slave_sda_io), 
			.led_o(i2c_slave_led_w), 
			.csi2_stream_run_o(top_clarity_tx_start_stream_w)
	);
	
	image_generator img_gen(
	         .reset_i(top_clarity_tx_reset_n_w),
			 .byte_clk_i(top_clarity_tx_byte_clk_w),
			 .line_number_i(top_clarity_tx_num_lines_w),
			 .hori_pixel_count_i(top_clarity_tx_hori_pixel_w),
			 .pixel_red_o(top_clarity_tx_pixel_red_w),
			 .pixel_green_red_o(top_clarity_tx_pixel_green_red_w),
			 .pixel_green_blue_o(top_clarity_tx_pixel_green_blue_w),
			 .pixel_blue_o(top_clarity_tx_pixel_blue_w)			 
	);

    
	reg initializeComplete;
	reg resetOverride;
        initial begin        
            initializeComplete <= 0;
	    resetOverride <= 0;
        end
	
	always @(posedge top_clarity_tx_ref_clk_w) begin
		if(initializeComplete == 0) begin
			if(resetOverride == 0) begin
			    resetOverride <= 1;			    
			end 
			else begin
				initializeComplete <= 1;
				resetOverride <= 0;
			end				
		end
	end
	
	assign top_clarity_tx_reset_n_w = (resetOverride == 0) ? top_clarity_tx_reset_n_i : 0;


	
endmodule
