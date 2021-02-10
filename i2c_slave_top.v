//read i2c doc from lattice on how to control the i2c_slave_logic.v module
//https://www.latticesemi.com/products/designsoftwareandip/intellectualproperty/referencedesigns/referencedesigns02/i2cslaveperipheral
module i2c_slave_top (i2c_slave_top_ref_clk_i, i2c_slave_top_reset_i, i2c_slave_scl_i, i2c_slave_sda_io, led_o, csi2_stream_run_o) ;

input i2c_slave_top_ref_clk_i;
input i2c_slave_top_reset_i;
input i2c_slave_scl_i;
inout i2c_slave_sda_io;
output [3:0]led_o;
output csi2_stream_run_o;

wire top_i2c_slave_sda_oe_w;
wire top_i2c_slave_start_w;
wire top_i2c_slave_stop_w;
wire [7:0]top_i2c_slave_data_out_w;
wire top_i2c_slave_rw_w;
wire top_i2c_slave_data_vld_w;
wire top_i2c_slave_sda_w;
wire i2c_slave_top_ref_clk_i;

reg i2c_slave_scl_sample;
reg i2c_slave_sda_sample;
reg [15:0]reg_addr;
reg [7:0]top_i2c_slave_data_in_w;
reg csi2_stream_run_o;
reg sample_write_input;

reg [4:0]state;
reg lastSCL;
reg lastSDA;
reg [15:0]i2cStall;
reg sys_reset;
parameter I2CTIMEOUT = 3000;

localparam  
       IDLE                                           = 5'd0, 
       START                                          = 5'd1,
	   START_WAIT                                     = 5'd2,
       ADDR_2                                         = 5'd3,
	   ADDR_2_WAIT                                    = 5'd4,
	   MODE                                           = 5'd5,
	   MODE_WAIT_WR_BYTES                             = 5'd6,
	   MODE_WAIT_RD_BYTES                             = 5'd7,
	   RD_BYTES                                       = 5'd8,
	   WR_BYTES                                       = 5'd9;

initial begin
	i2c_slave_scl_sample <= 0;
    i2c_slave_sda_sample <= 0;
	reg_addr <= 16'd0;
	state <= IDLE;
	csi2_stream_run_o <= 0;
	sample_write_input <= 0;
	lastSCL <= 0;
    lastSDA <= 0;
	i2cStall <= 16'd0;
	sys_reset <= 0;
end

assign i2c_slave_sda_io = top_i2c_slave_sda_oe_w ? 1'b0 : 1'bz;

always @(posedge i2c_slave_top_ref_clk_i, negedge i2c_slave_top_ref_clk_i) begin
	i2c_slave_scl_sample <= i2c_slave_scl_i;
	i2c_slave_sda_sample <= i2c_slave_sda_io;	
end

// The important block detect a read of the below registers and respond with the corresponding data that an IMX219 would send
always @(posedge i2c_slave_top_ref_clk_i, negedge i2c_slave_top_ref_clk_i) begin
	case(reg_addr)
		16'h0000    :  top_i2c_slave_data_in_w <= 8'h2;
		16'h0001    :  top_i2c_slave_data_in_w <= 8'h19;
		16'h0002    :  top_i2c_slave_data_in_w <= 8'h10;
		16'h0388    :  top_i2c_slave_data_in_w <= 8'h01; 
		default     :  top_i2c_slave_data_in_w <= 8'h00;
	endcase
end

// The important block detect a write to the mode select register to start or stop streaming.
// csi2_stream_run_o is propagated to the csi2_ctrl module
always @(posedge sample_write_input, negedge i2c_slave_top_reset_i) begin
	if(i2c_slave_top_reset_i == 0) begin
		csi2_stream_run_o <= 0;
	end
	else begin
	    case(reg_addr)
		    16'h0100    :  csi2_stream_run_o <= top_i2c_slave_data_out_w[0];
	    endcase
	end
end


//detect i2c stall out. If state is not IDLE and no activity on I2C -> reset
always @(posedge i2c_slave_top_ref_clk_i, negedge i2c_slave_top_ref_clk_i, negedge i2c_slave_top_reset_i) begin
    if(i2c_slave_top_reset_i == 0) begin
		i2cStall <= 16'd0;
		sys_reset <= 0;
	end
	else begin
		if(i2cStall == I2CTIMEOUT) begin
			i2cStall <= 16'd0;
			sys_reset <= 1;
		end
		else begin
			if((i2c_slave_scl_sample != lastSCL) || (i2c_slave_sda_sample != lastSDA)) begin
				i2cStall <= 16'd0;
				lastSCL <= i2c_slave_scl_sample;
				lastSDA <= i2c_slave_sda_sample;
				sys_reset <= 0;
			end
			else begin
				if(state != IDLE) begin
					i2cStall = i2cStall + 1;
					sys_reset <= 0;
				end
				else begin //state == IDLE
					sys_reset <= 0;
				end
					
			end
		end		
	end    	
end
assign led_o[0] = i2c_slave_sda_io;
assign led_o[1] = i2c_slave_scl_i;
assign led_o[3] = csi2_stream_run_o;

always @(posedge i2c_slave_top_ref_clk_i, negedge i2c_slave_top_ref_clk_i, negedge i2c_slave_top_reset_i, posedge sys_reset) begin
    if((i2c_slave_top_reset_i == 0) || (sys_reset == 1)) begin
		state <= IDLE;
		reg_addr <= 16'd0;	    
	    sample_write_input <= 0;
	end
	else begin
		if(state == IDLE) begin
			if(top_i2c_slave_start_w == 1) begin
				state <= START;
			end
			else begin
				state <= IDLE;
			end
		end
		else if(state == START) begin
			if(top_i2c_slave_stop_w == 1) begin
				state <= IDLE;
			end
			else if((top_i2c_slave_data_vld_w == 1) && (top_i2c_slave_rw_w == 0)) begin    //we have a write to address1 to start					
				state <= START_WAIT;					
			end
			else if((top_i2c_slave_data_vld_w == 1) && (top_i2c_slave_rw_w == 1)) begin    //we have a read from current address					
				state <= RD_BYTES;					
            end	
            else begin			
			    state <= START;
			end
		end
		else if(state == START_WAIT) begin
			if(top_i2c_slave_stop_w == 1) begin
				state <= IDLE;
			end
			else if(top_i2c_slave_data_vld_w == 0) begin
				state <= ADDR_2;
				reg_addr[15:8]  <= top_i2c_slave_data_out_w;
			end
			else begin
               state <= START_WAIT;
            end			   
		end
		else if(state == ADDR_2) begin
			if(top_i2c_slave_stop_w == 1) begin
				state <= IDLE;
			end
			else if((top_i2c_slave_data_vld_w == 1) && (top_i2c_slave_rw_w == 0)) begin    //we have a write to address2					
				state <= ADDR_2_WAIT;
			end
			else begin
			    state <= ADDR_2;
            end				
		end
		else if(state == ADDR_2_WAIT) begin
			if(top_i2c_slave_stop_w == 1) begin
				state <= IDLE;
			end
			else if(top_i2c_slave_data_vld_w == 0) begin
				state <= MODE;
				reg_addr[7:0]  <= top_i2c_slave_data_out_w;
			end
			else begin
               state <= ADDR_2_WAIT;
            end	
		end
		else if(state == MODE) begin
			if(top_i2c_slave_start_w == 1) begin   //this means we had a write address, then a SR, now reads either 1 or many sequential bytes. First reg addr has already been set.
				state <=  MODE_WAIT_RD_BYTES;
			end
			else if(top_i2c_slave_data_vld_w == 1) begin  //we have a write to reg_addr
				state <= MODE_WAIT_WR_BYTES;   //WR_BYTES
			end
			else if(top_i2c_slave_stop_w == 1) begin   //end transaction
				state <= IDLE;
			end
            else begin
				state <= MODE;
            end				
		end
		else if(state == MODE_WAIT_WR_BYTES) begin
			if(top_i2c_slave_stop_w == 1) begin   //end transaction
				state <= IDLE;
			end
			else if(top_i2c_slave_data_vld_w == 0) begin				   
				state <= WR_BYTES;
				sample_write_input <= 1;//sample the input
			end
			else begin
				state <= MODE_WAIT_WR_BYTES;
			end			
		end
		else if(state == MODE_WAIT_RD_BYTES) begin
			if(top_i2c_slave_stop_w == 1) begin   //end transaction
				state <= IDLE;
			end
			else if(top_i2c_slave_data_vld_w == 0) begin				   
				state <= RD_BYTES;
			end
			else begin
				state <= MODE_WAIT_RD_BYTES;
			end			
		end
		else if(state == RD_BYTES) begin
			if(top_i2c_slave_stop_w == 1) begin   //end transaction
			   state <= IDLE;
			 end
			 else if(top_i2c_slave_data_vld_w == 1) begin				   
			   state <= MODE_WAIT_RD_BYTES;
			 end
			 else begin
				state <= RD_BYTES;
			 end	
		end
		else if(state == WR_BYTES) begin
			if(top_i2c_slave_stop_w == 1) begin   //end transaction
			   state <= IDLE;
			 end
			 else if(top_i2c_slave_data_vld_w == 1) begin				   
			   state <= MODE_WAIT_WR_BYTES;
			 end
			 else begin
				state <= WR_BYTES;
				sample_write_input <= 0;
			 end	
		end
	end	
end
	
i2c_slave slave_logic( .XRESET((~i2c_slave_top_reset_i) | (sys_reset)), .ready(1), .start(top_i2c_slave_start_w), .stop(top_i2c_slave_stop_w), 
		.data_in(top_i2c_slave_data_in_w), .data_out(top_i2c_slave_data_out_w), .r_w(top_i2c_slave_rw_w), .data_vld(top_i2c_slave_data_vld_w), 
		.scl_in(i2c_slave_scl_sample), .scl_oe(), .sda_in(i2c_slave_sda_sample), .sda_oe(top_i2c_slave_sda_oe_w)
		);


endmodule