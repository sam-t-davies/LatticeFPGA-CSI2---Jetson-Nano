module csi2_tx_simulator_ctrl ( 
                    ctrl_tx_reset_i, 
                    ctrl_tx_start_stream_i,
                    ctrl_ref_clk_i,
                    ctrl_tx_byte_clk_i,
                    ctrl_tx_c2d_ready_i,
                    ctrl_tx_d_hs_rdy_i,
                    ctrl_tx_ld_pyld_i,
                    ctrl_tx_pix2byte_rstn_i,
                    ctrl_tx_pll_lock_i,
                    ctrl_tx_tinit_done_i,
					ctrl_tx_pixel_red_i,
					ctrl_tx_pixel_green_red_i,
					ctrl_tx_pixel_green_blue_i,
					ctrl_tx_pixel_blue_i,
                    ctrl_tx_byte_data_o,
                    ctrl_tx_dt_o,
                    ctrl_tx_frame_max_o,
                    ctrl_tx_vc_o,
                    ctrl_tx_wc_o,
                    ctrl_tx_byte_data_en_o,
                    ctrl_tx_clk_hs_en_o,
                    ctrl_tx_d_hs_en_o,
                    ctrl_tx_lp_en_o,
                    ctrl_tx_pd_dphy_o,                    
                    ctrl_tx_sp_en_o,
					ctrl_tx_line_num_o,
					ctrl_tx_byte_en_timer_o,					
                    ctrl_tx_led_o		
					);
					
    input  ctrl_tx_reset_i; 
    input  ctrl_tx_start_stream_i;
    input  ctrl_ref_clk_i;
    input  ctrl_tx_byte_clk_i;
    input  ctrl_tx_c2d_ready_i;
    input  ctrl_tx_d_hs_rdy_i;
    input  ctrl_tx_ld_pyld_i;
    input  ctrl_tx_pix2byte_rstn_i;
    input  ctrl_tx_pll_lock_i;
    input  ctrl_tx_tinit_done_i;
	input  [9:0]ctrl_tx_pixel_red_i;
	input  [9:0]ctrl_tx_pixel_green_red_i;
	input  [9:0]ctrl_tx_pixel_green_blue_i;
	input  [9:0]ctrl_tx_pixel_blue_i;
    output [63:0]ctrl_tx_byte_data_o;
    output [5:0]ctrl_tx_dt_o;
    output [7:0]ctrl_tx_frame_max_o;
    output [1:0]ctrl_tx_vc_o;
    output [15:0]ctrl_tx_wc_o;
    output ctrl_tx_byte_data_en_o;
    output ctrl_tx_clk_hs_en_o;
    output ctrl_tx_d_hs_en_o;
    output ctrl_tx_lp_en_o;
    output ctrl_tx_pd_dphy_o;    
    output ctrl_tx_sp_en_o;
	output [11:0]ctrl_tx_line_num_o;
	output [11:0]ctrl_tx_byte_en_timer_o;
	output reg [3:0] ctrl_tx_led_o;								
    
    reg  [5:0]ctrl_tx_dt_o; 
    reg  [7:0]ctrl_tx_frame_max_o; 
    reg  [1:0]ctrl_tx_vc_o;
    reg  [15:0]ctrl_tx_wc_o;
    reg  ctrl_tx_byte_data_en_o;
    reg  ctrl_tx_clk_hs_en_o;
    reg  ctrl_tx_d_hs_en_o; 
    reg  ctrl_tx_lp_en_o; 
    reg  ctrl_tx_pd_dphy_o;    
    reg  ctrl_tx_sp_en_o;
	
	reg [7:0]ctrl_tx_pixel_data_7_dt_0;
	reg [7:0]ctrl_tx_pixel_data_23_dt_16;
	reg [7:0]ctrl_tx_embedded_data_7_dt_0;
	reg [7:0]ctrl_tx_embedded_data_23_dt_16;
	
	reg[4:0] CurrentState;
	reg[4:0] NextState;
	
	reg[3:0] t_init_wait_timer;
    reg      t_init_wait_start;
    reg      t_init_wait_done;

    reg[2:0] assert_hs_timer;
	reg      assert_hs_start;
	reg      assert_hs_done;
	
	reg[3:0] assert_sp_en_timer; 
    reg      assert_sp_en_start;
	reg      assert_sp_en_done;	
	
	reg[3:0] assert_lp_en_timer; 
    reg      assert_lp_en_start;
	reg      assert_lp_en_done;
	
	reg[11:0] ctrl_tx_byte_en_timer_o;
	reg        assert_byte_en_start;
	reg        assert_byte_en_done;
	
	reg[11:0] assert_byte_embedded_timer;
	reg        assert_byte_embedded_start;
	reg        assert_byte_embedded_done;
	
	reg[11:0] exposure_simulated_timer;
	reg        exposure_simulated_start;
	reg        exposure_simulated_done; 

    reg [11:0]NumOfLines;
	reg NumOfEmbeddedLines;
	
	reg LedPulse;
	reg [5:0]LedPulseCount;
	
	/* 4 pixels = 5 bytes (RAW10) 3264 pixels = 4080 bytes =  2040 bytes/lane has to be multiple of 4  */
	parameter NUM_PIXEL_BYTES      = 12'd4080;
	parameter ASSERT_BYTE_EN_TIMER = 12'd2040;	
    parameter NUM_OF_LINES         = 12'd2464;
	
	/* Send 10bytes of embedded data */
	parameter NUM_EMBEDDED_BYTES = 12'd10;
	parameter ASSERT_BYTE_EMBEDDED_TIMER = 12'd5;  //5 bc 2 lanes
	
	/* byte clk is currently set to 106Mhz */
	parameter EXPOSURE_SIM_TIMER = 12'd3200;   /* ~30us exposure time */
	
	reg LineState;
	localparam  LINESTATE_EVEN                                = 1'd0,
	            LINESTATE_ODD                                 = 1'd1;
				
	reg [2:0]GearByteState;
	localparam  GEARSTATE_BYTE1   = 3'd0,
	            GEARSTATE_BYTE2   = 3'd1,
				GEARSTATE_BYTE3   = 3'd2,
				GEARSTATE_BYTE4   = 3'd3,
				GEARSTATE_BYTE5   = 3'd4;
				
	reg [15:0]FrameCount;
	
	reg LPType;   //Long Packet Type
	localparam  LPTYPE_EMBEDDED                                = 1'd0,
	            LPTYPE_PIXEL                                   = 1'd1;

	
	//SP = short packet, LP = long packet, FS = frame start, FE = Frame end
	localparam  IDLE                                           = 5'd0, 
                PLL_LOCK                                       = 5'd1,
                TINIT_DONE                                     = 5'd2,
				WAIT_TINIT                                     = 5'd3,
				ASSERT_HS_SP_FS                                = 5'd4,
				REMOVE_HS_SP_FS                                = 5'd5,
				WAIT_C2D_SP_FS                                 = 5'd6,
				SIM_EXP_SP_FS                                  = 5'd7,
				WAIT_D_HS_RDY_SP_FS                            = 5'd8,
				WAIT_SP_EN_SP_FS                               = 5'd9,				
				REMOVE_SP_EN_SP_FS                             = 5'd10,				
				WAIT_C2D_RDY_LP_RAW10                           = 5'd11,
				ASSERT_HS_LP_RAW10                              = 5'd12,
				REMOVE_HS_LP_RAW10                              = 5'd13,
				WAIT_D_HS_RDY_LP_RAW10                          = 5'd14,
				WAIT_LP_EN_LP_RAW10                             = 5'd15,
				REMOVE_LP_EN_LP_RAW10                           = 5'd16,
				ASSERT_BYTE_EN_LP_RAW10_DELAY                   = 5'd17, 
				WAIT_LD_PYLD_LP_RAW10                           = 5'd18,
				ASSERT_BYTE_EN_LP_RAW10                         = 5'd19,
				WAIT_BYTE_EN_LP_RAW10                           = 5'd20,
				START_LINE_OR_END_FRAME                        = 5'd21,
				WAIT_C2D_SP_FE                                 = 5'd22,
				ASSERT_HS_SP_FE                                = 5'd23,
				REMOVE_HS_SP_FE                                = 5'd24,
				WAIT_D_HS_RDY_SP_FE                            = 5'd25,
				WAIT_SP_EN_SP_FE                               = 5'd26,				
				REMOVE_SP_EN_SP_FE                             = 5'd27;
				
	initial begin        
        ctrl_tx_dt_o <= 6'b000000; 
        ctrl_tx_frame_max_o <= 8'd0; 
        ctrl_tx_vc_o <= 2'b00;
        ctrl_tx_wc_o <= 16'b0000000000000000;
        ctrl_tx_byte_data_en_o <= 0;
        ctrl_tx_clk_hs_en_o <= 0;
        ctrl_tx_d_hs_en_o <= 0; 
        ctrl_tx_lp_en_o <= 0; 
        ctrl_tx_pd_dphy_o <= 0;         
        ctrl_tx_sp_en_o <= 0;	
		ctrl_tx_led_o <= 4'b0000;
		CurrentState <= IDLE;
		NextState <= IDLE;
        t_init_wait_timer <= 4'd4;
        t_init_wait_start <= 0;
        t_init_wait_done <= 0;
        assert_hs_timer <= 3'd6;
	    assert_hs_start <= 0;
	    assert_hs_done <= 0;
        assert_sp_en_timer <= 4'd7; 
        assert_sp_en_start <= 0;
		assert_sp_en_done <= 0;	
        assert_lp_en_timer <= 4'd7; 
        assert_lp_en_start <= 0;
		assert_lp_en_done <= 0;
		ctrl_tx_byte_en_timer_o <= ASSERT_BYTE_EN_TIMER;
	    assert_byte_en_start <= 0;
	    assert_byte_en_done <= 0;
		assert_byte_embedded_start <= 0;
		assert_byte_embedded_done <= 0;
		assert_byte_embedded_timer <= ASSERT_BYTE_EMBEDDED_TIMER;
        NumOfLines <= NUM_OF_LINES;
		LineState <= LINESTATE_EVEN;
		FrameCount <= 16'd1;
		LPType <= LPTYPE_EMBEDDED;
		LedPulse <= 0;
		LedPulseCount <= 0;
		NumOfEmbeddedLines <= 1;
		ctrl_tx_pixel_data_7_dt_0 <= 8'd0;
	    ctrl_tx_pixel_data_23_dt_16 <= 8'd0;
		ctrl_tx_embedded_data_7_dt_0 <= 8'd0;
	    ctrl_tx_embedded_data_23_dt_16 <= 8'd0;
	    exposure_simulated_timer <= EXPOSURE_SIM_TIMER;
	    exposure_simulated_start <= 0;
	    exposure_simulated_done <= 0;
	end
	
	//Which data bus to output depends on Long Packet type	
	assign ctrl_tx_byte_data_o[7:0] = (LPType==LPTYPE_EMBEDDED) ?  ctrl_tx_embedded_data_7_dt_0 : ctrl_tx_pixel_data_7_dt_0;
	assign ctrl_tx_byte_data_o[23:16] = (LPType==LPTYPE_EMBEDDED) ?  ctrl_tx_embedded_data_23_dt_16 : ctrl_tx_pixel_data_23_dt_16;
	assign ctrl_tx_byte_data_o[63:24] = 0;
	assign ctrl_tx_byte_data_o[15:8] = 0;
	
	assign ctrl_tx_line_num_o = NumOfLines;
	
	always @(ctrl_tx_reset_i or NextState)
	begin
		if(~ctrl_tx_reset_i) begin
			CurrentState = IDLE;			
		end
		else begin
			CurrentState <= NextState;			
		end
	end
	
	always @(posedge ctrl_tx_byte_clk_i)
	begin
		
	    if( CurrentState == IDLE) begin
            t_init_wait_start <= 0;
			assert_hs_start <= 0;
			assert_lp_en_start <= 0;
			assert_sp_en_start <= 0;
			assert_byte_en_start <= 0;
			assert_byte_embedded_start <= 0;
			exposure_simulated_start <= 0;
			NumOfLines <= NUM_OF_LINES;
		    LineState <= LINESTATE_EVEN;
			FrameCount <= 1;
			NumOfEmbeddedLines <= 1;
			LPType <= LPTYPE_EMBEDDED;
			LedPulse <= 0;
			
			//When first boot up the PLL has to lock before doing anything.
			if(ctrl_tx_pll_lock_i == 1)  begin				
				NextState <= PLL_LOCK ;					
			end
            else begin
                NextState <= IDLE ;	
            end				
		end
		
		//After lock there is an initialization
		else if(CurrentState == PLL_LOCK) begin						
            if(ctrl_tx_tinit_done_i == 1)  begin				
				NextState <= TINIT_DONE ;					
			end
			else begin
				NextState <= PLL_LOCK;
			end
        end
		
		//Wait for the I2C write to start streaming
		else if(CurrentState == TINIT_DONE) begin					
			if(ctrl_tx_start_stream_i == 1)  begin
                t_init_wait_start <= 1;				
				NextState <= WAIT_TINIT ;					
			end
            else begin
				NextState <= TINIT_DONE;
			end				
		end
		
		//After tinit complete there is a small delay before we can start streaming.
		else if(CurrentState == WAIT_TINIT) begin					
			if(t_init_wait_done == 1)  begin
                t_init_wait_start <= 0;				
				NextState <= ASSERT_HS_SP_FS ;					
			end
            else begin
				NextState <= WAIT_TINIT;
			end				
		end
		
		//Everytime we complete a frame we come back to this state
		// if i2c stop has been received then we stop -> go to idle
		//otherwise we start a new frame.
		else if(CurrentState == WAIT_C2D_SP_FS) begin
            if(ctrl_tx_start_stream_i == 0) begin
				NextState <= IDLE;
            end				
			else if(ctrl_tx_c2d_ready_i == 1) begin     //c2d from ip block, when its ready for data
				NextState <= SIM_EXP_SP_FS;
				exposure_simulated_start <= 1;          //we start counter to simulate exposure
				if(FrameCount == 65534) begin           //if we maxed out Framecounter which is placed in WordCount(16bits) reset it
					FrameCount <= 1;
				end
				else begin
                    FrameCount <= FrameCount + 1;
                end					
			end
			else begin
				NextState <= WAIT_C2D_SP_FS;
			end
		end
		
		//Wait for the simulated Exposure Time to elapse
		else if(CurrentState == SIM_EXP_SP_FS) begin
			if(exposure_simulated_done == 1) begin
				exposure_simulated_start <= 0;
				NextState <= ASSERT_HS_SP_FS;
			end
            else begin
                NextState <= SIM_EXP_SP_FS;
            end				
		end
		
		//Toggle couple CSI2 input pins to initiate a transmission
		else if(CurrentState == ASSERT_HS_SP_FS) begin			
            ctrl_tx_clk_hs_en_o <= 1;
            ctrl_tx_d_hs_en_o <= 1;
            assert_hs_start <= 1;
            NextState <= REMOVE_HS_SP_FS;
        end
		
		//Must meet timing so delay must complete.
		else if(CurrentState == REMOVE_HS_SP_FS) begin			
			if(assert_hs_done == 1)  begin
				assert_hs_start <= 0;
				ctrl_tx_clk_hs_en_o <= 0;
                ctrl_tx_d_hs_en_o <= 0;
				NextState <= WAIT_D_HS_RDY_SP_FS;
			end
			else begin
				NextState <= REMOVE_HS_SP_FS;
			end
		end		
		
		
		//When tx_d is ready we can start populating data to send short packet.
		//Frame start VC = 0, DT = 0, WC = framecounter
		else if(CurrentState == WAIT_D_HS_RDY_SP_FS) begin		    
			if(ctrl_tx_d_hs_rdy_i == 1) begin
				assert_sp_en_start <= 1;
				ctrl_tx_dt_o <= 6'd0;              //set to FS
				NumOfEmbeddedLines <= 1;           //number of embedded lines is 2
				LPType <= LPTYPE_EMBEDDED;         //first long packets to send are embedded data
				NumOfLines <= NUM_OF_LINES;        //reset number of lines back to parameter setting
                ctrl_tx_frame_max_o <= 8'd0; 
                ctrl_tx_vc_o <= 2'd0;              //Virtual Channel
                ctrl_tx_wc_o <= FrameCount;        //Word count = frame counter which increments every frame       
				NextState <= WAIT_SP_EN_SP_FS;   
			end
			else begin
				NextState <= WAIT_D_HS_RDY_SP_FS;
			end
		end
		
		//delay before sending the short packet
		else if(CurrentState == WAIT_SP_EN_SP_FS) begin            
			if(assert_sp_en_done == 1)  begin
				assert_sp_en_start <= 0;
				ctrl_tx_sp_en_o <= 1;	           //Tell CSI2 to send the short packet
				NextState <= REMOVE_SP_EN_SP_FS;   
			end
			else begin
				NextState <= WAIT_SP_EN_SP_FS;
			end
		end
		
		//Can remove the short packet trigger now. IP is sending short packet
		else if(CurrentState == REMOVE_SP_EN_SP_FS) begin			
			ctrl_tx_sp_en_o <= 0;
			NextState <= WAIT_C2D_RDY_LP_RAW10;
		end
		
		//Wait for short packet completion. Indicated via c2d ready again
		else if(CurrentState == WAIT_C2D_RDY_LP_RAW10) begin			
			if(ctrl_tx_c2d_ready_i == 1) begin
				NextState <= ASSERT_HS_LP_RAW10;  
			end
			else begin
				NextState <= WAIT_C2D_RDY_LP_RAW10;
			end			
		end
		
		//Wait for short packet completion. Indicated via c2d ready again
		else if(CurrentState == ASSERT_HS_LP_RAW10) begin			
			ctrl_tx_clk_hs_en_o <= 1;
            ctrl_tx_d_hs_en_o <= 1;
			assert_hs_start <= 1;
            NextState <= REMOVE_HS_LP_RAW10;
		end
		
		//We can prepare to send long packet now
		else if(CurrentState == REMOVE_HS_LP_RAW10) begin			
			if(assert_hs_done == 1)  begin
				assert_hs_start <= 0;
				ctrl_tx_clk_hs_en_o <= 0;
                ctrl_tx_d_hs_en_o <= 0;
				NextState <= WAIT_D_HS_RDY_LP_RAW10;
			end
			else begin
				NextState <= REMOVE_HS_LP_RAW10;
			end
		end
		
		//First 2 lines are embedded data long packets
		//Followed by many pixel data lines.
		else if(CurrentState == WAIT_D_HS_RDY_LP_RAW10) begin			
		    if(ctrl_tx_d_hs_rdy_i == 1) begin
				LedPulse <= 0;                               
                ctrl_tx_frame_max_o <= 8'd0;
                assert_lp_en_start <= 1; 				
			    ctrl_tx_vc_o <= 2'd0;			    
				if(LPType == LPTYPE_EMBEDDED) begin
					ctrl_tx_dt_o <= 6'd18;                //set to Embedded Data (0x12)				
			        ctrl_tx_wc_o <= NUM_EMBEDDED_BYTES;   //send 10 bytes of embedded data           
				end
				else begin		                          //LP type pixel data			
					ctrl_tx_dt_o <= 6'd43;               //set to RAW10 (0x2B)				
			        ctrl_tx_wc_o <= NUM_PIXEL_BYTES;     //set number of bytes of pixels to send in 1 line
				end
				NextState <= WAIT_LP_EN_LP_RAW10;   
			end
			else begin
				NextState <= WAIT_D_HS_RDY_LP_RAW10;
			end			
		end
		
		//Send the Long packet packet header info
		else if(CurrentState == WAIT_LP_EN_LP_RAW10) begin            
			if(assert_lp_en_done == 1)  begin
				assert_lp_en_start <= 0;                     
				ctrl_tx_lp_en_o <= 1;                        //Tell CSI2 to send the long packet	
				NextState <= REMOVE_LP_EN_LP_RAW10;   
			end
			else begin
				NextState <= WAIT_LP_EN_LP_RAW10;
			end
		end
		
		//Wait for CSI2 IP to latch
		else if(CurrentState == REMOVE_LP_EN_LP_RAW10) begin			
			ctrl_tx_lp_en_o <= 0;			
            if(ctrl_tx_ld_pyld_i == 0) begin
				NextState <= ASSERT_BYTE_EN_LP_RAW10_DELAY;	  //add one clk delay to latch after pyld falls.
			end
			else begin				
                NextState <= REMOVE_LP_EN_LP_RAW10;				
			end			
		end
		
		//Add 1 delay clk
		else if(CurrentState == ASSERT_BYTE_EN_LP_RAW10_DELAY) begin			
            NextState <= ASSERT_BYTE_EN_LP_RAW10;			
		end

		//Key state, we trigger the embedded data or pixel data processes below.
		else if(CurrentState == ASSERT_BYTE_EN_LP_RAW10) begin			
			ctrl_tx_byte_data_en_o <= 1;             //tell the CSI2 IP that data is on the bus
			if(LPType == LPTYPE_EMBEDDED) begin					
                 assert_byte_embedded_start <= 1;	 //trigger the embedded data process				
			end
			else begin					
				assert_byte_en_start <= 1;          //trigger the pixel data process
			end
            NextState <= WAIT_BYTE_EN_LP_RAW10;			
		end
		
		//Wait until the above process has completed.
		else if(CurrentState == WAIT_BYTE_EN_LP_RAW10) begin
			if((assert_byte_en_done == 1) ||  (assert_byte_embedded_done == 1)) begin
				assert_byte_en_start <= 0;
				assert_byte_embedded_start <= 0;
				ctrl_tx_byte_data_en_o <= 0;
				NextState <= START_LINE_OR_END_FRAME;
			end
			else begin
				NextState <= WAIT_BYTE_EN_LP_RAW10;	
			end
		end
		
		//We have to send many lines. 2 lines of embedded data and many lines of pixel data
		//If the number of lines has decremented to zero the frame is over, we send Frame End (FE) and we restart all over again
		// IF we have more lines to send we go back to the start of the long packet state
		else if(CurrentState == START_LINE_OR_END_FRAME) begin
			if(NumOfLines == 1) begin                  //end the frame
				LineState <= LINESTATE_EVEN;
				NextState <= WAIT_C2D_SP_FE;
			end
			else begin
				NextState <= WAIT_C2D_RDY_LP_RAW10;    //start a new line
				if(LPType == LPTYPE_EMBEDDED) begin
					if(NumOfEmbeddedLines == 1) begin  //embedded data has sent 1 line, send 1 more
						NumOfEmbeddedLines <= 0;
					end
					else begin
						LPType = LPTYPE_PIXEL;         //embedded data has sent 2 lines, send pixel data now
					end
				end
				else begin                             //If pixel data, decrement line count
					NumOfLines = NumOfLines - 1;
				    LineState <= ~LineState;          //we flip the line state, in one state we send RED & Green data for image filter					                                  
				end                                    //in the other state we send green blue data
			    
			end
		end
		
		//Wait for long packet to be sent, wait for c2d again
		//Frame has ended get ready to send Frame End Short packet
		else if(CurrentState == WAIT_C2D_SP_FE) begin			
			if(ctrl_tx_c2d_ready_i == 1) begin
				NextState <= ASSERT_HS_SP_FE;   
			end
			else begin
				NextState <= WAIT_C2D_SP_FE;
			end
		end
		
		//Frame end short packet trigger signals
		else if(CurrentState == ASSERT_HS_SP_FE) begin			
            ctrl_tx_clk_hs_en_o <= 1;
            ctrl_tx_d_hs_en_o <= 1;
            assert_hs_start <= 1;
            NextState <= REMOVE_HS_SP_FE;
        end
		
		//Frame end short packet add delay
		else if(CurrentState == REMOVE_HS_SP_FE) begin			
			if(assert_hs_done == 1)  begin
				assert_hs_start <= 0;
				ctrl_tx_clk_hs_en_o <= 0;
                ctrl_tx_d_hs_en_o <= 0;
				NextState <= WAIT_D_HS_RDY_SP_FE;
			end
			else begin
				NextState <= REMOVE_HS_SP_FE;
			end
		end		
		
		//Send frame end short packet
		else if(CurrentState == WAIT_D_HS_RDY_SP_FE) begin			
			if(ctrl_tx_d_hs_rdy_i == 1) begin
				LedPulse <= 1;
				assert_sp_en_start <= 1;
				ctrl_tx_dt_o <= 6'd1;                    //set to FrameEnd                
                ctrl_tx_vc_o <= 2'd0;
                ctrl_tx_wc_o <= FrameCount;              //add framecounter into frame end packet header info
				NextState <= WAIT_SP_EN_SP_FE;   
			end
			else begin
				NextState <= WAIT_D_HS_RDY_SP_FE;
			end
		end		
		
		//wait for FW short packet to be sent
		else if(CurrentState == WAIT_SP_EN_SP_FE) begin
			if(assert_sp_en_done == 1)  begin
				assert_sp_en_start <= 0;
				ctrl_tx_sp_en_o <= 1;	
				NextState <= REMOVE_SP_EN_SP_FE;   
			end
			else begin
				NextState <= WAIT_SP_EN_SP_FE;
			end
        end
		
		//GO back to the top, and start all over again with exposure delay and frame start
		else if(CurrentState == REMOVE_SP_EN_SP_FE) begin			
			ctrl_tx_sp_en_o <= 0;
			NextState <= WAIT_C2D_SP_FS;
        end			
		
	end
	
	//delay between tinit and start of clk and data assert
	always @(posedge ctrl_tx_byte_clk_i)								      
	begin
			if(t_init_wait_start == 0) begin									
				t_init_wait_timer <= 4'd4;
            end				
			else if (t_init_wait_timer != 0 ) begin				
				t_init_wait_timer <= t_init_wait_timer - 1;												
			end 
			
			if(t_init_wait_timer == 0) begin														
				t_init_wait_done <= 1;
            end				
			else begin
				t_init_wait_done <= 0;											
			end 
	end
	
	//delay between assert clk_hs_en/d_hs_en and then deassert them
	always @(posedge ctrl_tx_byte_clk_i)								      
	begin
			if(assert_hs_start == 0) begin									
				assert_hs_timer <= 3'd6;
            end				
			else if (assert_hs_timer != 0 ) begin				
				assert_hs_timer <= assert_hs_timer - 1;												
			end 
			
			if(assert_hs_timer == 0) begin														
				assert_hs_done <= 1;
            end				
			else begin
				assert_hs_done <= 0;											
			end 
	end
	
	//delay between assert d_hs_rdy and then assert sp_en
	always @(posedge ctrl_tx_byte_clk_i)								      
	begin
			if(assert_sp_en_start == 0) begin									
				assert_sp_en_timer <= 3'd7;
            end				
			else if (assert_sp_en_timer != 0 ) begin				
				assert_sp_en_timer <= assert_sp_en_timer - 1;												
			end 
			
			if(assert_sp_en_timer == 0) begin														
				assert_sp_en_done <= 1;
            end				
			else begin
				assert_sp_en_done <= 0;											
			end 
	end
	
	//delay between assert d_hs_rdy and then assert lp_en
	always @(posedge ctrl_tx_byte_clk_i)								      
	begin
			if(assert_lp_en_start == 0) begin									
				assert_lp_en_timer <= 3'd7;
            end				
			else if (assert_lp_en_timer != 0 ) begin				
				assert_lp_en_timer <= assert_lp_en_timer - 1;												
			end 
			
			if(assert_lp_en_timer == 0) begin														
				assert_lp_en_done <= 1;
            end				
			else begin
				assert_lp_en_done <= 0;											
			end 
	end
	
	//duration to assert byte_data_en, equal to number of bytes to transmit in a ((line/2))
	//this is the brains of the pixel data, we get the image/pixel data from the image_generator.v file
	always @(posedge ctrl_tx_byte_clk_i or negedge ctrl_tx_reset_i)								      
	begin  
			if(ctrl_tx_reset_i == 0) begin //reset
				ctrl_tx_byte_en_timer_o <= ASSERT_BYTE_EN_TIMER;
				GearByteState = GEARSTATE_BYTE1;                   //read the gear info in the lattice csi2tx IP
				assert_byte_en_done <= 0;
				ctrl_tx_pixel_data_7_dt_0 <= 8'd0;
	            ctrl_tx_pixel_data_23_dt_16 <= 8'd0;
			end
			else begin
				if(assert_byte_en_start == 0) begin									
			    	ctrl_tx_byte_en_timer_o <= ASSERT_BYTE_EN_TIMER;
                    GearByteState = GEARSTATE_BYTE1;					
                end				
			    else if (ctrl_tx_byte_en_timer_o != 0 ) begin				
			    	ctrl_tx_byte_en_timer_o <= ctrl_tx_byte_en_timer_o - 1;
				end	
				
				if(LineState == LINESTATE_EVEN) begin
			    	if(GearByteState == GEARSTATE_BYTE1) begin
			    		ctrl_tx_pixel_data_7_dt_0[7:0] <= ctrl_tx_pixel_red_i[9:2];               //On even line we send R & Gr pixels
			    		ctrl_tx_pixel_data_23_dt_16[7:0] <= ctrl_tx_pixel_green_red_i[9:2];
						if(assert_byte_en_start == 1) begin
			    		    GearByteState = GEARSTATE_BYTE3;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE3) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_red_i[9:2];
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_green_red_i[9:2];
						if(assert_byte_en_start == 1) begin
			    		    GearByteState = GEARSTATE_BYTE5;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE5) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= {ctrl_tx_pixel_red_i[1:0], ctrl_tx_pixel_green_red_i[1:0], ctrl_tx_pixel_red_i[1:0], ctrl_tx_pixel_green_red_i[1:0]};    
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_red_i[9:2];
                        if(assert_byte_en_start == 1) begin						
			    		    GearByteState = GEARSTATE_BYTE2;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE2) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_green_red_i[9:2];
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_red_i[9:2];
						if(assert_byte_en_start == 1) begin
			    		    GearByteState = GEARSTATE_BYTE4;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE4) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_green_red_i[9:2];
			    		ctrl_tx_pixel_data_23_dt_16 <= {ctrl_tx_pixel_red_i[1:0], ctrl_tx_pixel_green_red_i[1:0], ctrl_tx_pixel_red_i[1:0], ctrl_tx_pixel_green_red_i[1:0]};    //In RAW10 the last 2 bits of the previous 4 bytes are concatenated together.
			    		if(assert_byte_en_start == 1) begin
						    GearByteState = GEARSTATE_BYTE1;
						end
			    	end				
			    end
			    else begin                                                             //Odd pixel line
			    	if(GearByteState == GEARSTATE_BYTE1) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_green_blue_i[9:2];   //We send Gb and B pixels
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_blue_i[9:2];
						if(assert_byte_en_start == 1) begin
			    		    GearByteState = GEARSTATE_BYTE3;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE3) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_green_blue_i[9:2];
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_blue_i[9:2];
						if(assert_byte_en_start == 1) begin
			    		    GearByteState = GEARSTATE_BYTE5;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE5) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= {ctrl_tx_pixel_green_blue_i[1:0], ctrl_tx_pixel_blue_i[1:0], ctrl_tx_pixel_green_blue_i[1:0], ctrl_tx_pixel_blue_i[1:0]};    //In RAW10 the last 2 bits of the previous 4 bytes are concatenated together.
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_green_blue_i[9:2];
                        if(assert_byte_en_start == 1) begin						
			    		    GearByteState = GEARSTATE_BYTE2;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE2) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_blue_i[9:2];
			    		ctrl_tx_pixel_data_23_dt_16 <= ctrl_tx_pixel_green_blue_i[9:2];
						if(assert_byte_en_start == 1) begin
			    		    GearByteState = GEARSTATE_BYTE4;
						end
			    	end
			    	else if(GearByteState == GEARSTATE_BYTE4) begin
			    		ctrl_tx_pixel_data_7_dt_0 <= ctrl_tx_pixel_blue_i[9:2];
			    		ctrl_tx_pixel_data_23_dt_16 <= {ctrl_tx_pixel_green_blue_i[1:0], ctrl_tx_pixel_blue_i[1:0], ctrl_tx_pixel_green_blue_i[1:0], ctrl_tx_pixel_blue_i[1:0]};    //In RAW10 the last 2 bits of the previous 4 bytes are concatenated together.
			    		if(assert_byte_en_start == 1) begin
						    GearByteState = GEARSTATE_BYTE1;
						end
			    	end			
			    end
			    
			    if(ctrl_tx_byte_en_timer_o == 2) begin	//2 on purpose for 2 reasons. So that ASSERT_BYTE_EN_TIMER is exact number, not (num - 1) and we assert done first then 1 clk later start is de-asserted 													
			    	assert_byte_en_done <= 1;          //en_done is delayed 1 extra byte to allow for checksum part. 
                end				
			    else begin
			    	assert_byte_en_done <= 0;											
			    end	
			end
	end
	
	//duration to assert byte_data_en, equal to number of bytes to transmit in a ((line/2))
	//This is the brains of the embedded data info.
	//On each line we send 0A 07 07 07 55
	//0A is embedded data formate code, 07 is data end code, 55 is dummy byte required in RAW10 output
	always @(posedge ctrl_tx_byte_clk_i or negedge ctrl_tx_reset_i)								      
	begin
			if(ctrl_tx_reset_i == 0) begin //reset
				assert_byte_embedded_timer <= ASSERT_BYTE_EMBEDDED_TIMER;				
				assert_byte_embedded_done <= 0;
				ctrl_tx_embedded_data_7_dt_0 <= 8'd0;
	            ctrl_tx_embedded_data_23_dt_16 <= 8'd0;
			end
			else begin
				if(assert_byte_embedded_start == 0) begin									
			    	assert_byte_embedded_timer <= ASSERT_BYTE_EMBEDDED_TIMER;                    				
                end
                else if (assert_byte_embedded_timer != 0 ) begin				
			    	assert_byte_embedded_timer <= assert_byte_embedded_timer - 1;
				end					
				
				if((assert_byte_embedded_timer == 5)) begin
					ctrl_tx_embedded_data_7_dt_0 <= 8'h0A;
			    	ctrl_tx_embedded_data_23_dt_16 <= 8'h07;				    
				end
				else if(assert_byte_embedded_timer == 3) begin
					ctrl_tx_embedded_data_7_dt_0 <= 8'h55;
			    	ctrl_tx_embedded_data_23_dt_16 <= 8'h07;
				end
				else if((assert_byte_embedded_timer == 2) || (assert_byte_embedded_timer == 4)) begin
					ctrl_tx_embedded_data_7_dt_0 <= 8'h07;
			    	ctrl_tx_embedded_data_23_dt_16 <= 8'h07;
				end
                else if(assert_byte_embedded_timer == 1) begin
					ctrl_tx_embedded_data_7_dt_0 <= 8'h07;
			    	ctrl_tx_embedded_data_23_dt_16 <= 8'h55;
				end				
			    
			    if(assert_byte_embedded_timer == 2) begin	//2 on purpose for 2 reasons. So that ASSERT_BYTE_EN_TIMER is exact number, not (num - 1) and we assert done first then 1 clk later start is de-asserted 													
			    	assert_byte_embedded_done <= 1;              //en_done is delayed 1 extra byte to allow for checksum part. 
                end				
			    else begin
			    	assert_byte_embedded_done <= 0;											
			    end	
			end
	end
	
	//Exposure Simulator counter
	always @(posedge ctrl_tx_byte_clk_i)								      
	begin
		if(exposure_simulated_start == 0) begin									
				exposure_simulated_timer <= EXPOSURE_SIM_TIMER;
            end				
			else if (exposure_simulated_timer != 0 ) begin				
				exposure_simulated_timer <= exposure_simulated_timer - 1;												
			end 
			
			if(exposure_simulated_timer == 0) begin														
				exposure_simulated_done <= 1;
            end				
			else begin
				exposure_simulated_done <= 0;											
			end		
	end
	
	//For debug the led blinks every 29 frames.
	always @(posedge LedPulse)
    begin
		if(ctrl_tx_reset_i == 0) begin //reset
			ctrl_tx_led_o <= 4'b0000;
			LedPulseCount <= 0;
		end
		else begin
			if(LedPulseCount == 29) begin
			    LedPulseCount <= 0;
			    ctrl_tx_led_o[3] <= ~ctrl_tx_led_o[3];
			    ctrl_tx_led_o[2] <= ~ctrl_tx_led_o[2];
			    ctrl_tx_led_o[1] <= ~ctrl_tx_led_o[1];
			    ctrl_tx_led_o[0] <= ~ctrl_tx_led_o[0];
		    end
		    else begin
			    LedPulseCount <= LedPulseCount + 1;
		    end
		end
	end
	
	
endmodule