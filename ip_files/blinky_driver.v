/*

   file name:blinky_driver.v
   date of ceated:26-12-2025
   specifications:control the brightness of led 
   

*/
`timescale 1ns/1ps

module blinky_driver(
	input  wire	  clk,
	input  wire	  reset,
	input  wire	  enable,
	input  wire [7:0] brightness,  //signal from the python 
	output reg 	  pwm_out     //signal to control the brightness of the led
	);
   reg [7:0]count_temp;  //temperarory varible for counter
   always @(posedge clk)
    begin
   	if(reset)
   	   begin
   	      count_temp<=8'b0;
   	      pwm_out   <=0;
   	   end
   	   
	else if(enable)
	 begin
	   count_temp<=count_temp+1'b1;
	   
	   if(count_temp<brightness)
	      pwm_out<=1;
	   else
	      pwm_out<=0;
	 end
	else
	 begin
	     count_temp<=8'b0;
   	      pwm_out   <=0;
	 end
	 
    end
	
endmodule
