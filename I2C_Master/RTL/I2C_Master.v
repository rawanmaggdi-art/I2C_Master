module I2C_Master ( 
					input clk_i, rst_i , m_w_r_i ,    
					input m_start_i , m_stop_i , m_ack_i,
					input [6:0] m_slv_add_i,
					input [7:0] m_data_i,
					
					output reg [7:0] m_data_o ,
					output reg m_error_o, m_busy_o , m_data_ready_o ,
					
					inout SDA , SCL  
																	  );


  reg [1:0] clk_counter;
  reg initial_low,middle_low, initial_high, middle_high;
  reg divided_clk;
  
  reg [3:0] current_state,next_state;
  localparam idle       = 4'b0000,
             start      = 4'b0001,
			 pre_data   = 4'b0010,
			 check_ack1 = 4'b0011,
			 wr_op      = 4'b0100,
			 check_ack2 = 4'b0101,
			 rd_op      = 4'b0110,
			 send_ack   = 4'b0111,
			 stop       = 4'b1000;
			 
			 
  reg [6:0] slv_add_reg;   
  reg [7:0] data_in_reg;
  reg w_r_reg;
  
  reg [3:0] pre_data_counter;
  reg [3:0] data_counter;
  
  reg SDA_o;
  
  localparam ACK  = 1'b0,
			 NACK = 1'b1;
			 
  localparam WRITE = 1'b0,
			 READ  = 1'b1;
  
  
  
//clk divider

  always @(posedge clk_i or negedge rst_i)
    begin
	  if(!rst_i)
	    clk_counter <= 2'b0;
		
	  else clk_counter <= clk_counter + 1'b1;
	end

  always @(*)
    begin 
	  initial_low= 1'b0; middle_low= 1'b0; initial_high=1'b0; middle_high=1'b0;
	  case (clk_counter)
	    2'b00 : initial_low  = 1'b1;
		2'b01 : middle_low   = 1'b1;
		2'b10 : initial_high = 1'b1;
		2'b11 : middle_high  = 1'b1;
	  endcase
	end
  
  ///// Generating Divided Clock ////
  always @(*)
    begin
	  if ( initial_low || middle_low )
	    divided_clk = 1'b0;
		
	  else divided_clk = 1'b1;	
	end
  
  
  /////////driving SCL /////////
  assign SCL = (divided_clk == 0) ? 1'b0 : 1'bz ; 


  //////////current state logic for FSM /////////
  
  always @(posedge clk_i or negedge rst_i)
    begin
	  if(!rst_i)
	    current_state <= idle;
      else 
	    current_state <= next_state;
	end
  
  //////////next state logic for FSM /////////
  always@(*)
    begin
	  next_state = current_state;
	  
	  case(current_state)
	    idle       : begin 
					   if (m_start_i)
					     if(middle_low) 
						   next_state = start;		
		             end
					 					 
		start      : begin
					   if (middle_high)
					     next_state = pre_data;  
					 end
					 
		pre_data   : begin 
					   if (pre_data_counter == 4'd8 && middle_high)
		                 next_state = check_ack1;
						 
					   else next_state = pre_data;
					 end
		
		check_ack1 : begin
					   if(middle_high) 
					     begin
					       if (SDA == ACK)        //////ACK//////
					         begin
						       if (w_r_reg == WRITE) ////////write operation////////
						         next_state = wr_op ;
							 
						       else next_state = rd_op;
						     end
							 
						   else next_state = stop ;
						 end    
					 end
					 
		wr_op      : begin
					   if(data_counter == 4'd8 && middle_low)
					     begin 
						     next_state = check_ack2;
						 end
						 
					   else next_state = wr_op ;
					   
					 end
		
		check_ack2 : begin
					   if(middle_high)
					     begin
					       if (SDA == ACK)  /////////ACK//////
					         begin 
						       if (!m_stop_i)
						         next_state = wr_op ;
						       else next_state = stop;
						     end  
						 end
						 
					       else   ///////NACK///////
					         begin
						       next_state = stop;
						     end
					 end  
		
		rd_op      : begin 
					   if(data_counter == 4'd7 && middle_low)
					     begin 
						     next_state = send_ack ;
						  end
						 
					   else next_state = rd_op;
					     
					 end
		
		send_ack   : begin
					   if (middle_high) 
					     begin
						   if(m_stop_i)
						     next_state = stop;
						   else 
						     next_state = rd_op;
						 end
					 end
		
		stop       : begin 
					   if (middle_high)
					     next_state = idle ;
					   else 
					     next_state = stop ;
				     end
		default    : next_state = idle;
		
	  endcase
	end
  
  
  /////////////output Logic////////////
  always@(posedge clk_i or negedge rst_i)
    if(!rst_i)
	  begin
		
		m_busy_o <= 1'b0;
		m_error_o <= 1'b0;
		SDA_o <= 1'b1;
		m_data_ready_o <= 1'b0;
		m_data_o <= 8'b0;
		
		data_in_reg <= 8'b0;
		slv_add_reg <= 7'b0;
		w_r_reg <= 1'b0;
		
		pre_data_counter <= 3'b0;
		data_counter <= 3'b0;
		
	  end
	  
	else 
	  begin
	    case(current_state)
		  idle       : begin
					     m_busy_o <= 1'b0;
						 SDA_o <= 1'b1;
					   end
					   
		  start      : begin
						 m_busy_o    <= 1'b1;
						 if (initial_high)  
						   SDA_o       <= 1'b0; 

						 w_r_reg     <= m_w_r_i;
						 slv_add_reg <= m_slv_add_i;
						 data_in_reg <= m_data_i;
						 pre_data_counter <= 1'b0;
						 data_counter <= 1'b0;
						  
		               end
					   
		  pre_data   : begin    //////////sending slave Address + w/r operation 
					    m_busy_o <= 1;
						if(initial_low) 
						  begin
						    if (pre_data_counter == 4'd7)
							  begin
							    SDA_o <= w_r_reg ;
							    pre_data_counter <= pre_data_counter + 1'b1 ;
							  end
							  
							else 
							  begin
							    SDA_o <= slv_add_reg [6 - pre_data_counter] ;
								pre_data_counter <= pre_data_counter + 1'b1 ;
							  end
						  end
						
					   end
					   
		  check_ack1 :  begin 
						  pre_data_counter <= 4'b000;
						  m_busy_o <= 1;
						  if(initial_low)
						    SDA_o <= 1'b1;
						  if(initial_high)
						    begin
							  if( SDA == NACK)
							    m_error_o <= 1'b1;
								
							  else m_error_o <= 1'b0;
							end
						end	
		  
		  wr_op      :  begin
						  m_busy_o <= 1;
		                  if(initial_low)
						    begin
							      SDA_o <= data_in_reg [7 - data_counter];
								  data_counter <= data_counter + 1'b1 ;
							end
					    end
		  
		  check_ack2 : begin
						 data_counter <= 4'b000;
					     m_busy_o <= 1;
						 if (initial_low)
						   SDA_o <= 1'b1;
						   
						 if (initial_high)
						   begin
						     if(SDA == NACK)
							   m_error_o <= 1'b1;
							   
							 else m_error_o <= 1'b0;
						   end
					   end
		  
		  rd_op      : begin
					     m_busy_o <= 1'b1;
						 m_data_ready_o <= 1'b0;
						 SDA_o <= 1'b1;
						 
						 if(initial_high)
						   begin
						     if (data_counter == 3'd7)
						       begin
						         m_data_o[7-data_counter] <= SDA;
								 m_data_ready_o <= 1'b1;
							     data_counter <= 3'b000;
						       end
						     else 
						       begin
						         m_data_o[7-data_counter] <= SDA ;
								 data_counter <= data_counter + 1'b1 ;
						       end
						   end 
					   end
		  
		  send_ack   : begin
						 m_busy_o <= 1'b1;
						 if(initial_low)
						   begin
					         if (m_ack_i) 
							   SDA_o <= ACK ;
				
						     else 
						       SDA_o <= NACK ;
						    
						   end
					   end
		  
		  stop       : begin 
					     if (initial_low)
						   SDA_o <= 1'b0;
						 else if (initial_high)
						   SDA_o <= 1'b1;
					   end
		
		endcase
	  end

	
  
  assign SDA = (SDA_o == 1) ? 1'bz : 1'b0 ;
  
endmodule 


