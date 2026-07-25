`timescale 1ns / 1ps

module I2C_Master_tb;

  reg clk_i, rst_i , m_w_r_i ;
  reg m_start_i , m_stop_i , m_ack_i;
  reg [6:0] m_slv_add_i;
  reg [7:0] m_data_i;
					
  wire [7:0] m_data_o ;
  wire m_error_o, m_busy_o , m_data_ready_o ;
					
  wire SDA , SCL ; 
  
  pullup (SDA) ;
  pullup (SCL) ;
  
  reg slv_ack;
  
  I2C_Master DUT (
				  .clk_i         (clk_i), 
				  .rst_i         (rst_i), 
				  .m_w_r_i       (m_w_r_i), 
				  .m_start_i     (m_start_i), 
				  .m_stop_i      (m_stop_i), 
				  .m_ack_i       (m_ack_i), 
				  .m_slv_add_i   (m_slv_add_i),
				  .m_data_i      (m_data_i), 
				  .m_data_o      (m_data_o), 
				  .m_error_o     (m_error_o), 
				  .m_busy_o      (m_busy_o), 
				  .m_data_ready_o(m_data_ready_o), 
				  .SDA           (SDA), 
				  .SCL           (SCL) 
													);
  
  initial clk_i = 1'b0;
  
  always #5 clk_i = ~clk_i ;
  
  initial begin

    // initialize all inputs for scenario #1 "write operation without ack" 
    rst_i = 0;
    m_start_i = 0;
    m_stop_i = 0;
    m_ack_i = 0;
    m_w_r_i = 0; 
    slv_ack= 1;
    m_slv_add_i = 7'b1110001;
    m_data_i = 8'b1011_0011;
    #40;

    // deactivate reset
    rst_i = 1;

    // start the process
    #40;
    m_start_i = 1;
    #100; // wait to make sure we moved from idle state
    wait (DUT.current_state == 4'b0000) // wait until the next idle state "operation done"
    m_start_i = 0;


   // initialize all inputs for scenario #2 "read operation without ack" + "write then read"
    m_start_i = 0;
    m_stop_i = 0;
    m_ack_i = 0;
    m_w_r_i = 1;
    m_slv_add_i = 7'b1110001;
    #40;

    // start the process
    m_start_i = 1;
    #100; // wait to make sure we moved from idle state
    wait (DUT.current_state == 4'b0000) // wait until the next idle state "operation done"
    m_start_i = 0;


   // initialize all inputs for scenario #3 "read operation with ack" + "read after read with diff add"
    m_start_i = 0;
    m_stop_i = 1;    //  <===========================================
    m_ack_i = 0;
    m_w_r_i = 1;
    m_slv_add_i = 7'b11000011;
    #40;

    // start the process
    m_start_i = 1;

    #100; // wait to make sure we moved from idle state
    wait (DUT.current_state == 4'b0011)
    wait(DUT.initial_low) 
    slv_ack = 1'b0;
    wait (DUT.current_state != 4'b0011); 
    slv_ack = 1'b1;
    wait (DUT.current_state == 4'b0000) // wait until the next idle state "operation done"
    m_start_i = 0;

   // initialize all inputs for scenario #4 "write operation with ack" + "read then write"
    m_start_i = 0;
    m_stop_i = 1;
    m_ack_i = 0;
    m_w_r_i = 0;
    m_slv_add_i = 7'b1110001;
    m_data_i = 8'b1011_0011;
    #40;

    // start the process
    m_start_i = 1;
    #100; // wait to make sure we moved from idle state
    wait (DUT.current_state == 4'b0011)
    wait(DUT.initial_low) 
    slv_ack = 1'b0;
    wait (DUT.current_state != 4'b0011); 
    slv_ack = 1'b1;
    wait (DUT.current_state == 4'b0000) // wait until the next idle state "operation done"
    m_start_i = 0;


   // initialize all inputs for scenario #5 "write then write with diff add"
    m_start_i = 0;
    m_stop_i = 1;
    m_ack_i = 0;
    m_w_r_i = 0;
    m_slv_add_i = 7'b11000011;
    m_data_i = 8'b1011_0011;
    #40;

    // start the process
    m_start_i = 1;
    #100; // wait to make sure we moved from idle state
    wait (DUT.current_state == 4'b0011)
    wait(DUT.initial_low) 
    slv_ack = 1'b0;
    wait (DUT.current_state != 4'b0011); 
    slv_ack = 1'b1;
    wait (DUT.current_state == 4'b0000) // wait until the next idle state "operation done"
    m_start_i = 0;

    

    // ------------------------ all scenarios hve been done ------------------
    #100;
    $stop;

end

assign SDA = (slv_ack == 1'b0) ? 1'b0 : 1'bz;


endmodule