module calculator_main#(
parameter int WIDTH=16
)(
input logic clk,
output logic overflow,
output logic underflow,
input logic reset,
input logic pop,//requests stored value for alu use
input logic push,//tells fifo to store incoming value
input logic selA,//selects between data1/fifo_out
input logic selB,//selects between data2/fifo_out
input logic sel,//selects between data1/data2
input logic start,//ALU start
input logic [3:0] operand,//goes to the ALU, decided by user
input logic [WIDTH-1:0] data1,//external input1(loads into fifo for reuse)
input logic [WIDTH-1:0] data2,//external input2(fed directly into the ALU)
output logic [WIDTH-1:0] dataout,//alu output
output logic done,
output logic fifo_full,
output logic fifo_empty,
output logic [WIDTH-1:0] fifo_data_out
);

logic underflowcalc;
logic overflowcalc;
logic [WIDTH-1:0] fifo_in;
logic [WIDTH-1:0] fifo_out;//exits fifo, enters alu
logic empty,full;
logic [WIDTH-1:0] alu_a_in;
logic [WIDTH-1:0] alu_b_in;
logic [WIDTH-1:0] alu_result;//store result
logic alu_done;//operation complete or not
assign fifo_in=sel?data1:data2;
assign alu_a_in=selA?data1:fifo_out;
assign alu_b_in=selB?data2:fifo_out;
fifo fifo1(.clk(clk),.reset(reset),.push_fifo(push),.pop_fifo(pop),.FIFO_IN(fifo_in),.FIFO_FULL(full),.FIFO_EMPTY(empty),.FIFO_OUT(fifo_out));
alu alu1(.overflow(overflowcalc),.underflow(underflowcalc),.clk(clk),.reset(reset),.start(start),.operand(operand),.A_in(alu_a_in),.B_in(alu_b_in),.RESULT(alu_result),.done(alu_done));
assign dataout=alu_result;
assign overflow=overflowcalc;
assign underflow=underflowcalc;
assign done = alu_done;
assign fifo_full=full;
assign fifo_empty=empty;
assign fifo_data_out=fifo_out;
endmodule
module fifo#(parameter WIDTH=16)(
input logic clk,
input logic reset,
input logic push_fifo,//stores new value at queue back
input logic pop_fifo,//retrieves oldest value from queue front
input logic [WIDTH-1:0] FIFO_IN,//has data written during push
output logic FIFO_FULL,//fifo has reached capacity
output logic FIFO_EMPTY,//no values remaining to pop
output logic [WIDTH-1:0] FIFO_OUT//return data value during pop operation
);

logic [WIDTH-1:0] reg_ [0:7];//8 registers of 16 bits(stores value for processing)
//Read and Write Pointers
logic [3:0] regA; //read pointer, controls which register to pop and display output?
logic [3:0] regB; //write pointer, controls which register where input will be stored
logic empty, full;
always_comb begin
	if(regA[3]!=regB[3] && regA[2:0]==regB[2:0]) begin
		full='1;
		empty='0;
	end else if(regA==regB) begin
		full='0;
		empty='1;
	end else begin
		full='0;
		empty='0;
	end
end
assign FIFO_FULL  = full;
assign FIFO_EMPTY = empty;
always_ff@(posedge clk) begin
	if(reset) begin
		regA<='0;
		regB<='0;
		FIFO_OUT<='0;
		end else begin
			if(push_fifo && !full)begin
				reg_[regB[2:0]]<=FIFO_IN;
				regB<=regB+1'b1;
			end if(pop_fifo && !empty)begin
				FIFO_OUT<=reg_[regA[2:0]];
				regA<=regA+1'b1;
			end
		end
	end
endmodule
module alu#(parameter WIDTH=16)(
output logic overflow,
output logic underflow,
input clk,
input reset,
input logic start,//alu operation
input logic [3:0] operand,//defines computation type
input logic [WIDTH-1:0] A_in,//first input(from the fifo usually)
input logic [WIDTH-1:0] B_in,//second input(provided from the current input path?)
output logic [WIDTH-1:0] RESULT,//holds computation input
output logic done//calculation done
);
typedef enum logic[1:0]{
	IDLE,
	LOGIC_OP,
	ARITH_OP
	} state_t;
state_t state, next_state;
logic op_group;//operand[3], selects whether arithmetic(1) or binary(0)
logic [2:0] op_code;//operand[2:0],selects exact operation
//Combinational state assignment
assign op_group=operand[3];
logic [WIDTH-1:0] A;
logic [WIDTH-1:0] B;
always_comb begin
RESULT= '0;
overflow= 1'b0;
underflow = 1'b0;
next_state=state;
	unique case(state)
		IDLE: begin
			if(start)
			next_state=(op_group==1'b0)? LOGIC_OP:ARITH_OP;
			else
			next_state=IDLE;
			end
		LOGIC_OP: begin
			unique case(op_code)
				3'b000: RESULT = A & B;
				3'b001: RESULT = A | B;
				3'b010: RESULT = A ^ B;
				3'b011: RESULT = ~A;
				3'b100: RESULT = ~B;
				3'b101: RESULT = ~(A & B);
				3'b110: RESULT = A << 1;
				3'b111: RESULT = A >> 1;
				default: RESULT = '0;
			endcase
			next_state=IDLE;
		end
		ARITH_OP: begin
			unique case(op_code)
				3'b000: begin
					logic[WIDTH:0] sum;
					sum = A + B;
					RESULT = sum[WIDTH-1:0];
					overflow=sum[WIDTH];
					end
				3'b001: begin
					if(A < B)begin
						underflow=1'b1;
					end else begin
						RESULT = A - B;
					end
				end
				3'b010: begin
					logic[2*WIDTH-1:0] prod;
					prod = A * B;
					RESULT = prod[WIDTH-1:0];
					overflow=|prod[2*WIDTH-1:WIDTH];
					end
				3'b011: RESULT = (A > B) ? 16'd1 : 16'd0;
				3'b100: RESULT = (A < B) ? 16'd1 : 16'd0;
				3'b101: RESULT = (A == B) ? 16'd1 : 16'd0;
				3'b110: RESULT = (A != B) ? 16'd1 : 16'd0;
				3'b111: RESULT = { B[7:0], A[7:0] };
				default: RESULT= '0;
			endcase
			next_state=IDLE;
		end
		default: next_state=IDLE;
	endcase
end
always_ff@(posedge clk) begin
	if (reset) begin
		state<=IDLE;
		A<='0;
		B<='0;
		op_code<='0;
	end else begin
		state<=next_state;
		if(state == IDLE && start) begin
		A<=A_in;
		B<=B_in;
		op_code<=operand[2:0];
		end
	end
end
assign done=(state!=IDLE);
endmodule
