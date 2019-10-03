

`timescale 1ns/100ps
`default_nettype none

module experiment5 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches
		
		//PS2 CODE
		input logic PS2_DATA_I,                   // PS2 data
		input logic PS2_CLOCK_I,                  // PS2 clock

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs
		output logic[17:0] LED_RED_O,             // 18 red LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O              // VGA blue
);

`include "VGA_Param.h"

logic system_resetn;

logic Clock_50, Clock_25, Clock_25_locked;

// For Push button
logic [3:0] PB_pushed;


//clock variables
logic [24:0] clock_div_count;
logic one_sec_clock, one_sec_clock_buf;

logic count_enable;
logic [7:0] counter;
logic [7:0] counter2;
logic [3:0] onesCounter2;
logic [3:0] tensCounter2;
logic clearFlag;




logic [7:0] start_time;
logic [7:0] curr_time;

//PS2 CODE
logic [7:0] PS2_code;
logic PS2_code_ready, PS2_code_ready_buf;
logic PS2_make_code;
logic caseFlag; 

// PS2 unit
PS2_controller PS2_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(system_resetn),
	
	.PS2_clock(PS2_CLOCK_I),
	.PS2_data(PS2_DATA_I),
	
	.PS2_code(PS2_code),
	.PS2_code_ready(PS2_code_ready),
	.PS2_make_code(PS2_make_code),
	.caseFlag(caseFlag)
);



// For VGA
logic [9:0] VGA_red, VGA_green, VGA_blue;
logic [9:0] pixel_X_pos;
logic [9:0] Npixel_X_pos;
logic [9:0] pixel_Y_pos;
logic VGA_vsync_buf;
logic welcomeFlag;

// For Character ROM
logic [5:0] character_address;
logic rom_mux_output;

logic [5:0] lives_character_address;
logic [5:0] ones_score_character_address;
logic [5:0] tens_score_character_address;

logic [5:0] onesHighGameID_address;
logic [5:0] tensHighGameID_address;
logic [5:0] onesHighS_address;
logic [5:0] tensHighS_address;

logic [5:0] onesCounter2_address;
logic [5:0] tensCounter2_address;



// For the Pong game
parameter OBJECT_SIZE = 10,
		  BAR_X_SIZE = 60,
		  BAR_Y_SIZE = 5,
		  BAR_SPEED = 5,
		  SCREEN_BOTTOM = 50;

typedef struct {
	logic [9:0] X_pos;
	logic [9:0] Y_pos;	
} coordinate_struct;

coordinate_struct object_coordinate, bar_coordinate;

logic object_X_direction, object_Y_direction;

logic object_on, bar_on, screen_bottom_on;

logic [1:0] lives;
logic [3:0] onesScore;
logic [3:0] tensScore;
logic game_over;
logic highScoreFlag;
logic flagCheck;
logic flagnew;
logic flagnew1; 





logic [3:0] onesGameID;
logic [3:0] tensGameID;

logic [3:0] highOnesGameID;
logic [3:0] highTensGameID;

logic [3:0] onesHighS;
logic [3:0] tensHighS;

logic [9:0] object_speed;

// For 7 segment displays
logic [6:0] value_7_segment [4:0];

assign system_resetn = ~(SWITCH_I[17] || ~Clock_25_locked);

// PLL for clock generation
CLOCK_25_PLL CLOCK_25_PLL_inst (
	.areset(SWITCH_I[17]),
	.inclk0(CLOCK_50_I),
	.c0(Clock_50),
	.c1(Clock_25),
	.locked(Clock_25_locked)
);

// Push Button unit
PB_Controller PB_unit (
	.Clock_25(Clock_25),
	.Resetn(system_resetn),
	.PB_signal(PUSH_BUTTON_I),	
	.PB_pushed(PB_pushed)
);

// VGA unit
logic [9:0] VGA_RED_O_long, VGA_GREEN_O_long, VGA_BLUE_O_long;
VGA_Controller VGA_unit(
	.Clock(Clock_25),
	.Resetn(system_resetn),

	.iRed(VGA_red),
	.iGreen(VGA_green),
	.iBlue(VGA_blue),
	.oCoord_X(pixel_X_pos),
	.oCoord_Y(pixel_Y_pos),
	
	//	VGA Side
	.oVGA_R(VGA_RED_O_long),
	.oVGA_G(VGA_GREEN_O_long),
	.oVGA_B(VGA_BLUE_O_long),
	.oVGA_H_SYNC(VGA_HSYNC_O),
	.oVGA_V_SYNC(VGA_VSYNC_O),
	.oVGA_SYNC(VGA_SYNC_O),
	.oVGA_BLANK(VGA_BLANK_O),
	.oVGA_CLOCK(VGA_CLOCK_O)
);

assign VGA_RED_O = VGA_RED_O_long[9:2];
assign VGA_GREEN_O = VGA_GREEN_O_long[9:2];
assign VGA_BLUE_O = VGA_BLUE_O_long[9:2];


//clock stuff start----------------------------------------------------------

always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		clock_div_count <= 25'h0000000;
	end else begin
		if (clock_div_count < 'd24999999) begin
			clock_div_count <= clock_div_count + 25'd1;
		end else 
			clock_div_count <= 25'h0000000;		
	end
end

// The value of one_sec_clock flip-flop is inverted every time the counter is reset to zero
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		one_sec_clock <= 1'b1;
	end else begin
		if (clock_div_count == 'd0) one_sec_clock <= ~one_sec_clock;
	end
end

// A buffer on one_sec_clock for edge detection
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		one_sec_clock_buf <= 1'b1;	
	end else begin
		one_sec_clock_buf <= one_sec_clock;
	end
end

// Pulse generation, that generates one pulse every time a posedge is detected on one_sec_clock
assign count_enable = (one_sec_clock_buf == 1'b0 && one_sec_clock == 1'b1);

// A counter that increments every second
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		counter <= 8'd0;
		counter2 <= 8'd15;
		onesCounter2 <= 4'd5;
		tensCounter2 <= 4'd1;
		flagCheck = 1'b0; 
	end else begin
		if (count_enable == 1'b1) begin
			counter <= counter + 8'd1;
			if (game_over == 1'b1)
				counter2 <= counter2 - 8'd1;
				
				if(onesCounter2 == 4'd0) begin
					tensCounter2 <= tensCounter2 - 4'd1;
					onesCounter2 <= 4'd9;
				end
				else
					onesCounter2 <= onesCounter2-4'd1;
				
				
				
				if (counter2 == 8'd2)begin 
					flagCheck <= 1'b1;
				end
			if(game_over == 1'b0)begin
				flagCheck <= 1'b0;
				counter2 <= 8'd15;
				onesCounter2 <= 4'd5;
				tensCounter2 <= 4'd1;
			end
		end
	end
end

//clock stuff end -------------------------------------------------------

// Character ROM
char_rom char_rom_unit (
	.Clock(VGA_CLOCK_O),
	.Character_address(character_address),
	.Font_row(pixel_Y_pos[2:0]),
	.Font_col(pixel_X_pos[2:0]),	
	.Rom_mux_output(rom_mux_output)
);

// Convert hex to character address
convert_hex_to_char_rom_address convert_lives_to_char_rom_address (
	.hex_value(lives),
	.char_rom_address(lives_character_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address (
	.hex_value(onesScore),
	.char_rom_address(ones_score_character_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address1 (
	.hex_value(tensScore),
	.char_rom_address(tens_score_character_address)
);






convert_hex_to_char_rom_address convert_score_to_char_rom_address2 (
	.hex_value(highOnesGameID),
	.char_rom_address(onesHighGameID_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address3 (
	.hex_value(highTensGameID),
	.char_rom_address(tensHighGameID_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address4 (
	.hex_value(onesHighS),
	.char_rom_address(onesHighS_address)
);


convert_hex_to_char_rom_address convert_score_to_char_rom_address5 (
	.hex_value(tensHighS),
	.char_rom_address(tensHighS_address)
);


convert_hex_to_char_rom_address convert_score_to_char_rom_address6 (
	.hex_value(onesCounter2),
	.char_rom_address(onesCounter2_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address7 (
	.hex_value(tensCounter2),
	.char_rom_address(tensCounter2_address)
);







assign object_speed = {7'd0, SWITCH_I[2:0]};
// RGB signals
always_comb begin
		VGA_red = 10'd0;
		VGA_green = 10'd0;
		VGA_blue = 10'd0;
		
		if(game_over == 1'b1) begin
			VGA_red = 10'h0;
			VGA_blue = 10'h0;
			VGA_green = 10'h0;
		end
		
		if (welcomeFlag == 1'b1 && caseFlag == 1'b0) begin
			if(counter%2 == 0) begin
				if(pixel_X_pos>= 10'd0 && pixel_X_pos<10'd80) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h3FF;
					
				end
				
				if(pixel_X_pos>= 10'd80 && pixel_X_pos<10'd160) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h0;
					VGA_green = 10'h3FF;
				end
				
				if(pixel_X_pos>= 10'd160 && pixel_X_pos<10'd240) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h0;
				end
				
				if(pixel_X_pos>= 10'd240 && pixel_X_pos<10'd320) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h0;
					VGA_green = 10'h0;
				end
				if(pixel_X_pos>= 10'd320 && pixel_X_pos<10'd400) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h3FF;
				end
				
				if(pixel_X_pos>= 10'd400 && pixel_X_pos<10'd480) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h0;
					VGA_green = 10'h3FF;
				end
				
				if(pixel_X_pos>= 10'd480 && pixel_X_pos<10'd560) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h0;
				end
				
				if(pixel_X_pos>= 10'd560 && pixel_X_pos<10'd640) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h0;
					VGA_green = 10'h0;
				end
				
				
			end else begin
				if(pixel_Y_pos>= 10'd0 && pixel_Y_pos<10'd60) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h3FF;
					
				end
				
				if(pixel_Y_pos>= 10'd60 && pixel_Y_pos<10'd120) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h0;
					VGA_green = 10'h3FF;
				end
				
				if(pixel_Y_pos>= 10'd120 && pixel_Y_pos<10'd180) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h0;
				end
				
				if(pixel_Y_pos>= 10'd180 && pixel_Y_pos<10'd240) begin
					VGA_red = 10'h3FF;
					VGA_blue = 10'h0;
					VGA_green = 10'h0;
				end
				if(pixel_Y_pos>= 10'd240 && pixel_Y_pos<10'd300) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h3FF;
				end
				
				if(pixel_Y_pos>= 10'd300 && pixel_Y_pos<10'd360) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h0;
					VGA_green = 10'h3FF;
				end
				
				if(pixel_Y_pos>= 10'd360 && pixel_Y_pos<10'd420) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h3FF;
					VGA_green = 10'h0;
				end
				
				if(pixel_Y_pos>= 10'd420 && pixel_Y_pos<10'd480) begin
					VGA_red = 10'h0;
					VGA_blue = 10'h0;
					VGA_green = 10'h0;
				end
			end
			
		end else begin
			if (object_on) begin
				// Yellow object
				VGA_red = 10'h3FF;
				VGA_green = 10'h3FF;
			end
			
			if (bar_on) begin
				// Blue bar
				VGA_blue = 10'h3FF;
			end
			
			if (screen_bottom_on) begin
				// Red border
				VGA_red = 10'h3FF;
			end
			
			if (rom_mux_output) begin
				// Display text
				VGA_blue = 10'h3FF;
				VGA_green = 10'h3FF;
			end
		end
		
end

always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		VGA_vsync_buf <= 1'b0;
	end else begin
		VGA_vsync_buf <= VGA_VSYNC_O;
	end
end

// Updating location of the object (Ball)
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		object_coordinate.X_pos <= 10'd200;
		object_coordinate.Y_pos <= 10'd50;
		
		object_X_direction <= 1'b1;	
		object_Y_direction <= 1'b1;	

		onesScore <= 4'd0;	
		tensScore <= 4'd0;	
		lives <= 2'd3;
		game_over <= 1'b0;
		
		welcomeFlag <= 1'b1;
		
		onesGameID <= 4'b1;
		tensGameID <= 4'b0;
		flagnew <= 1'b0;


		onesHighS <= 4'b0;
		tensHighS <= 4'b0;
		
		highOnesGameID <= 4'b0;
		highTensGameID <= 4'b0;
		
		
	end else begin
		// Update movement during vertical blanking
		if (VGA_vsync_buf && ~VGA_VSYNC_O  && caseFlag == 1'b1 ) begin
			if (object_X_direction == 1'b1) begin
				// Moving right
				if (object_coordinate.X_pos < H_SYNC_ACT - OBJECT_SIZE - object_speed) 
					object_coordinate.X_pos <= object_coordinate.X_pos + object_speed;
				else
					object_X_direction <= 1'b0;
			end else begin
				// Moving left
				if (object_coordinate.X_pos >= object_speed) 		
					object_coordinate.X_pos <= object_coordinate.X_pos - object_speed;		
				else
					object_X_direction <= 1'b1;
			end
			
			if (object_Y_direction == 1'b1) begin
				// Moving down
				if (object_coordinate.Y_pos <= bar_coordinate.Y_pos - OBJECT_SIZE - object_speed)
					object_coordinate.Y_pos <= object_coordinate.Y_pos + object_speed;
				else begin
					if (object_coordinate.X_pos >= bar_coordinate.X_pos 							// Left edge of object is within bar
					 && object_coordinate.X_pos + OBJECT_SIZE <= bar_coordinate.X_pos + BAR_X_SIZE 	// Right edge of object is within bar
					) begin
						// Hit the bar
						object_Y_direction <= 1'b0;
						
						
						if(flagnew == 1'b0)begin
							if(onesScore == 4'd9) begin
								if(onesScore == 4'd9 && tensScore == 4'd9) begin
									onesScore <= 4'd0;
									tensScore <= 4'd0;
								end
								tensScore <= tensScore + 4'd1;
								onesScore <= 0;
							end
							else
								onesScore <= onesScore + 4'd1;	
						end
									
					end else begin
						// Hit the bottom of screen
						if (lives > 2'd0) begin
							lives <= lives - 2'd1;
						end

						if (lives > 2'd1) begin
							// Restart the object
							object_X_direction <= SWITCH_I[16];	
							object_Y_direction <= SWITCH_I[15];
							
							object_coordinate.X_pos <= 10'd200;
							object_coordinate.Y_pos <= 10'd50;
						end else begin
							// Game over
	
							if(flagCheck)begin
								game_over <= 1'b0;
								object_coordinate.X_pos <= 10'd200;
								object_coordinate.Y_pos <= 10'd50;
								
								object_X_direction <= 1'b1;	
								object_Y_direction <= 1'b1;	

								onesScore <= 4'd0;	
								tensScore <= 4'd0;	
								lives <= 2'd3;
								flagnew <= 1'b0;
								
							end else begin
								game_over <= 1'b1;
								if(flagnew == 1'b0)begin
									if(onesGameID == 4'd9) begin
										if(onesGameID == 4'd9 && tensGameID == 4'd9) begin
											onesGameID <= 4'd0;
											tensGameID <= 4'd0;
										end		
										onesGameID <= onesGameID + 4'd1;
										onesGameID <= 0;
									end
									else begin
										onesGameID <= onesGameID + 4'd1;
										if(onesGameID == 4'd1 && tensGameID == 4'd0) begin
											onesHighS <= onesScore;
											tensHighS <= tensScore;
											
											highOnesGameID <= onesGameID;
											highTensGameID <= tensGameID;
											
										end
									end
										
										

									if(onesScore>=onesHighS && tensScore>=tensHighS) begin
										onesHighS <= onesScore;
										tensHighS <= tensScore;
										
										highOnesGameID <= onesGameID;
										highTensGameID <= tensGameID;
										
										highScoreFlag <= 1'b1; 
									end
								end
								flagnew <= 1'b1; 
							end
						end				
					end
				end
			end else begin
				// Moving up
				if (object_coordinate.Y_pos >= object_speed) 				
					object_coordinate.Y_pos <= object_coordinate.Y_pos - object_speed;		
				else
					object_Y_direction <= 1'b1;
			end		
		end
	end
end

// Update the location of bar
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		bar_coordinate.X_pos <= 10'd200;
		bar_coordinate.Y_pos <= 10'd0;
	end else begin
		bar_coordinate.Y_pos <= V_SYNC_ACT-BAR_Y_SIZE-SCREEN_BOTTOM;
		
		// Update the movement during vertical blanking
		if (VGA_vsync_buf && ~VGA_VSYNC_O) begin
			if (PB_pushed[0] == 1'b1 || (PS2_code == 8'h1B && PS2_make_code)) begin
				// Move bar right
				if (bar_coordinate.X_pos < H_SYNC_ACT - BAR_X_SIZE - BAR_SPEED) 		
					bar_coordinate.X_pos <= bar_coordinate.X_pos + BAR_SPEED;
			end else begin
				if (PB_pushed[1] == 1'b1 || (PS2_code == 8'h1C && PS2_make_code)) begin
					// Move bar left
					if (bar_coordinate.X_pos > BAR_SPEED) 		
						bar_coordinate.X_pos <= bar_coordinate.X_pos - BAR_SPEED;
				end 	
			end
		end
	end
end

// Check if the ball should be displayed or not
always_comb begin	
	if (pixel_X_pos >= object_coordinate.X_pos && pixel_X_pos < object_coordinate.X_pos + OBJECT_SIZE
	 && pixel_Y_pos >= object_coordinate.Y_pos && pixel_Y_pos < object_coordinate.Y_pos + OBJECT_SIZE)
		object_on = 1'b1;
	else 
		object_on = 1'b0;
		
	if(game_over == 1'b1)
		object_on = 1'b0;
end

// Check if the bar should be displayed or not
always_comb begin
	if (pixel_X_pos >= bar_coordinate.X_pos && pixel_X_pos < bar_coordinate.X_pos + BAR_X_SIZE
	 && pixel_Y_pos >= bar_coordinate.Y_pos && pixel_Y_pos < bar_coordinate.Y_pos + BAR_Y_SIZE) 
		bar_on = 1'b1;
	else 
		bar_on = 1'b0;
	
	if(game_over == 1'b1)
		bar_on = 1'b0;
end

// Check if the line on the bottom of the screen should be displayed or not
always_comb begin
	if (pixel_Y_pos == V_SYNC_ACT - SCREEN_BOTTOM + 1) 
		screen_bottom_on = 1'b1;
	else 
		screen_bottom_on = 1'b0;
		
	if(game_over == 1'b1)
		screen_bottom_on = 1'b0;
end


// Display text
always_comb begin
	character_address = 6'o40; // Show space by default
	Npixel_X_pos[9:0] = pixel_X_pos[9:0] + 1'b1;
	// 8 x 8
	if (pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM + 20) >> 3) && game_over == 1'b0) begin
		// Reach the section where the text is displayed
		case (Npixel_X_pos[9:3])
			7'd1: character_address = 6'o14; // L
			7'd2: character_address = 6'o11; // I
			7'd3: character_address = 6'o26; // V
			7'd4: character_address = 6'o05; // E
			7'd5: character_address = 6'o23; // S
			7'd6: character_address = 6'o40; // space
			7'd7: character_address = lives_character_address;
			
			7'd72: character_address = 6'o23; // S
			7'd73: character_address = 6'o03; // C
			7'd74: character_address = 6'o17; // O
			7'd75: character_address = 6'o22; // R
			7'd76: character_address = 6'o05; // E
			7'd77: character_address = 6'o40; // space
			7'd78: character_address = tens_score_character_address;
			7'd79: character_address = ones_score_character_address; 												
		endcase
	end
	
	if(game_over == 1'b1) begin
		if (pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM - 40) >> 3) && game_over == 1'b1) begin
			case (Npixel_X_pos[9:3])
				7'd1: character_address = 6'o14; // L
				7'd2: character_address = 6'o01; // A
				7'd3: character_address = 6'o23; // S
				7'd4: character_address = 6'o24; // T
				7'd5: character_address = 6'o40; // space
				7'd6: character_address = 6'o07; // G
				7'd7: character_address = 6'o01; // A
				7'd8: character_address = 6'o15; // M
				7'd9: character_address = 6'o05; // E
				7'd10: character_address = 6'o47; // '
				7'd11: character_address = 6'o23; // S
				7'd12: character_address = 6'o40; // space

				7'd13: character_address = 6'o23; // S
				7'd14: character_address = 6'o03; // C
				7'd15: character_address = 6'o17; // O
				7'd16: character_address = 6'o22; // R
				7'd17: character_address = 6'o05; // E
				7'd18: character_address = 6'o40; // space
				7'd19: character_address = 6'o27; // W
				7'd20: character_address = 6'o01; // A
				7'd21: character_address = 6'o23; // S
				7'd22: character_address = 6'o40; // space
				7'd23: character_address = tens_score_character_address; 
				7'd24: character_address = ones_score_character_address; 
				
			endcase
		end
		if (pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM ) >> 3) && game_over == 1'b1) begin
			case (Npixel_X_pos[9:3])

				7'd1: character_address = 6'o07; // G
				7'd2: character_address = 6'o01; // A
				7'd3: character_address = 6'o15; // M
				7'd4: character_address = 6'o05; // E
				7'd5: character_address = 6'o40; // space
				7'd6: character_address = tensHighGameID_address; 
				7'd7: character_address = onesHighGameID_address; 												

				7'd8: character_address = 6'o40; // space

				
				7'd9: character_address = 6'o23; // S
				7'd10: character_address = 6'o03; // C
				7'd11: character_address = 6'o17; // O
				7'd12: character_address = 6'o22; // R
				7'd13: character_address = 6'o05; // E
				7'd14: character_address = 6'o40; // space
				7'd15: character_address = tensHighS_address; 
				7'd16: character_address = onesHighS_address; 												
				
			endcase
		end
		
		if (pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM + 20) >> 3) && game_over == 1'b1) begin
			case (Npixel_X_pos[9:3])

				7'd1: character_address = 6'o24; // T
				7'd2: character_address = 6'o11; // I
				7'd3: character_address = 6'o15; // M
				7'd4: character_address = 6'o05; // E
				7'd5: character_address = 6'o40; // space
												
				7'd6: character_address = 6'o14; // L
				7'd7: character_address = 6'o05; // E
				7'd8: character_address = 6'o06; // F
				7'd9: character_address = 6'o24; // T
				7'd10: character_address = 6'o40; // space
				7'd11: character_address = tensCounter2_address; 
				7'd12: character_address = onesCounter2_address; 												
				
			endcase
		end
		
	end
end


convert_hex_to_seven_segment unit2 (
	.hex_value(game_over), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(counter2), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(flagCheck), 
	.converted_value(value_7_segment[0])
);


assign	SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
		SEVEN_SEGMENT_N_O[1] = value_7_segment[2],
		SEVEN_SEGMENT_N_O[2] = value_7_segment[1],
		SEVEN_SEGMENT_N_O[3] = 7'h7f,
		SEVEN_SEGMENT_N_O[4] = 7'h7f,
		SEVEN_SEGMENT_N_O[5] = 7'h7f,
		SEVEN_SEGMENT_N_O[6] = 7'h7f,
		SEVEN_SEGMENT_N_O[7] = 7'h7f;

assign LED_RED_O = {system_resetn, 15'd0, object_X_direction, object_Y_direction};
assign LED_GREEN_O = {game_over, 4'd0, PB_pushed};

endmodule
