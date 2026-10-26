interface calcmain#(parameter int WIDTH=16)(input logic clk);
  logic reset;
  logic pop;
  logic push;
  logic selA;
  logic selB;
  logic sel;
  logic start;
  logic [3:0] operand;
  logic [WIDTH-1:0] data1;
  logic [WIDTH-1:0] data2;
  logic overflow;
  logic underflow;
  logic [WIDTH-1:0] dataout;
  logic done;
  logic fifo_full;
  logic fifo_empty;
  logic [WIDTH-1:0] fifo_out;
endinterface
class packet;
rand logic [15:0] data1;
rand logic [15:0] data2;
rand logic [3:0] operand;
logic overflow;
logic underflow;
logic [15:0] dataout;
endclass
class fifo_packet;
logic push;
logic pop;
logic sel;
logic selA;
logic selB;
logic fifo_full;
logic fifo_empty;
logic [15:0] data1;
logic [15:0] data2;
logic [15:0] fifo_out;
endclass
class generator;
	mailbox #(packet) mbx;
	function new(mailbox #(packet) m);
	mbx=m;
	endfunction
	task run();
		packet p;
		repeat (65535) begin
		p=new();
		void'(p.randomize());
		mbx.put(p);
		end
	endtask
endclass
class fifo_generator;
    mailbox #(fifo_packet) mbx;
    function new(mailbox #(fifo_packet) m);
    mbx=m;
    endfunction
    task run();
        fifo_packet p;
        int count;
        count=1;
        p=new();
        p.pop='1;
        p.sel='1;
        p.data1=0;
        p.data2='0;
        p.push='0;
        mbx.put(p);
        p=new();
        p.pop='1;
        p.sel='1;
        p.data1=0;
        p.data2='0;
        p.push='1;
        mbx.put(p);
        repeat (8) begin
        p=new();
        p.push='1;
        p.pop='0;
        p.data1=1;
        p.data2='0;
        p.sel='1;
        p.data1=count;
        count=count+1;
        mbx.put(p);
        end
        p=new();
        p.pop='1;
        p.sel='1;
        p.data1=0;
        p.data2='0;
        p.push='1;
        mbx.put(p);
        p=new();
        p.pop='1;
        p.sel='1;
        p.data1=0;
        p.data2='0;
        p.push='0;
        mbx.put(p);
        p=new();
        p.pop='1;
        p.sel='1;
        p.data1=0;
        p.data2='0;
        p.push='1;
        mbx.put(p);
    endtask
endclass
class fifo_driver;
    mailbox #(fifo_packet) mbx;
    virtual calcmain vif;
    function new(mailbox #(fifo_packet) m, virtual calcmain v);
    mbx=m;
    vif=v;
    endfunction
    task run();
    fifo_packet p;
    @(negedge vif.clk);
        vif.reset='1;
        vif.push='0;
        vif.pop='0;
        vif.start='0;
        vif.selA='0;
        vif.selB='0;
    repeat (3) @(negedge vif.clk);
	vif.reset = '0;
    forever begin
    mbx.get(p);
    @(negedge vif.clk);
        vif.push=p.push;
        vif.pop=p.pop;
        vif.sel=p.sel;
        vif.data1=p.data1;
        vif.data2=p.data2;
        if(mbx.num()==0) begin
        @(negedge vif.clk);
        vif.push='0;
        vif.pop='0;
        end
    end
    endtask
endclass
class driver;
    mailbox #(packet) mbx;
	 virtual calcmain vif;
    function new(mailbox #(packet) m, virtual calcmain v);
     mbx=m;
	 vif=v;
	 endfunction
	 task run();
		packet p;
		@(negedge vif.clk);
		vif.reset='1;
		vif.push='0;
		vif.pop='0;
		vif.sel='0;
		vif.start='0;
		repeat (3) @(negedge vif.clk);
		vif.reset = '0;
		forever begin
		mbx.get(p);
		@(negedge vif.clk);
		vif.data1=p.data1;
		vif.data2=p.data2;
		vif.operand=p.operand;
		vif.selA=1;
		vif.selB=1;
		vif.start='1;
		@(negedge vif.clk);
		vif.start='0;
		end
	endtask
endclass
class fifo_monitor;
    mailbox #(fifo_packet) mbx;
    virtual calcmain vif;
    function new(mailbox #(fifo_packet) m, virtual calcmain v);
    mbx=m;
    vif=v;
    endfunction
    task run();
    fifo_packet p;
    forever begin
    @(posedge vif.clk);
    if(vif.reset==='0)begin
    p=new();
    p.push=vif.push;
    p.pop=vif.pop;
    p.data1=vif.data1;
    p.data2=vif.data2;
    p.sel=vif.sel;
    p.fifo_empty=vif.fifo_empty;
    p.fifo_full=vif.fifo_full;
    p.fifo_out=vif.fifo_out;
    mbx.put(p);
    end
    end
    endtask
endclass
class monitor;
	mailbox #(packet) mbx;
	virtual calcmain vif;
	function new(mailbox #(packet) m, virtual calcmain v);
    mbx = m;
    vif = v;
  endfunction
  task run();
  forever begin
	packet p;
	@(posedge vif.clk);
	if(vif.start=='1) begin
	p=new();
	p.data1=vif.data1;
	p.data2=vif.data2;
	p.operand=vif.operand;
	if(vif.done!=='0)begin
	$display("Error at start cycle done!");
	end
	@(posedge vif.clk);
	p.dataout=vif.dataout;
	p.overflow=vif.overflow;
	p.underflow=vif.underflow;
	if (vif.done!=='1)begin
	$display("Error at answer cycle done!");
	end
	mbx.put(p);
	end
	end
endtask
endclass
class fifo_scoreboard;
    mailbox #(fifo_packet) mbx;
	function new(mailbox #(fifo_packet) m);
	mbx=m;
	endfunction
	logic [15:0] q1[$];
	int pass=0;
	int fail=0;
	logic [15:0] fifo_out;
	logic delay;
	task run();
	   forever begin
	       fifo_packet p;
	       logic empty;
	       logic full;
	       mbx.get(p);
	       if(p.fifo_empty===1'bx || p.fifo_full===1'bx)begin
	       end else begin
	       if(delay==='1)begin
	           if(fifo_out===p.fifo_out)begin
	           pass=pass+1;
	           delay='0;
	           end else begin
	           fail=fail+1;
	           delay='0;
	           end
	       end
	       if(q1.size()==0)begin
	           empty='1;
	           full='0;
	       end
	       else if(q1.size()==8)begin
	           full='1;
	           empty='0;
	       end else begin
	           full='0;
	           empty='0;
	       end
            if(full===p.fifo_full && empty===p.fifo_empty)begin
                pass=pass+1;
            end else begin
                fail=fail+1;
            end
            if(p.pop && !empty)begin
                fifo_out=q1.pop_front(); 
                delay='1;
            end
            if(p.push && !full)begin
            if(p.sel=='1)begin
            q1.push_back(p.data1);
            end else begin
            q1.push_back(p.data2);
            end
           end
        end
        end
	endtask
	task report();
    $display("FIFO scoreboard: PASS=%0d FAIL=%0d", pass, fail);
    endtask
endclass
class scoreboard;
	mailbox #(packet) mbx;
	function new(mailbox #(packet) m);
	mbx=m;
	endfunction
	int pass=0;
	int fail=0;
	task run();
		packet p;
		logic [16:0] sum;
		logic [15:0] difference;
		logic [15:0] exp_dataout;
		logic [31:0] product;
		logic exp_overflow;
		logic exp_underflow;
		forever begin
		mbx.get(p);
		exp_overflow  = '0;
		exp_underflow = '0;
		case(p.operand)
		4'b0000: begin
			exp_dataout=p.data1&p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
				fail=fail+1;
			end
			end
		4'b0001: begin
			exp_dataout=p.data1|p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			    fail=fail+1;
			end
			end
		4'b0010: begin
			exp_dataout=p.data1^p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
				fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b0011: begin
			exp_dataout=~p.data1;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b0100: begin
			exp_dataout=~p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b0101: begin
			exp_dataout=~(p.data1&p.data2);
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b0110: begin
			exp_dataout=p.data1<<1;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b0111: begin
			exp_dataout=p.data1>>1;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
				fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b1000: begin
		sum=p.data1+p.data2;
		exp_dataout=sum[15:0];
		exp_overflow=sum[16];
		exp_underflow='0;
		if(p.dataout==exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
			pass=pass+1;
		end else begin
		    fail=fail+1;
			$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
		end
		end
		4'b1001: begin
		difference=p.data1-p.data2;
		exp_dataout=difference;
		exp_overflow='0;
		if(p.data1<p.data2)begin
			exp_underflow='1;
			exp_dataout='0;
			if(p.underflow==exp_underflow && p.dataout==exp_dataout && p.overflow==exp_overflow) begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected_underflow=%b expected overflow=%b expected_dataout=%0d|got underflow=%b got overflow=%b got dataout=%0d",p.data1, p.data2, p.operand, exp_underflow, exp_overflow, exp_dataout, p.underflow, p.overflow, p.dataout);
			end	
		end
		if(p.data1>=p.data2)begin
		exp_underflow='0;
		if(p.dataout==exp_dataout && p.overflow==exp_overflow && p.underflow==exp_underflow)begin
			pass=pass+1;
		end else begin
		    fail=fail+1;
			$display("FAIL: data1=%0d data2=%0d operand=%0d|expected_underflow=%b expected overflow=%b expected_dataout=%0d|got underflow=%b got overflow=%b got dataout=%0d",p.data1, p.data2, p.operand, exp_underflow, exp_overflow, exp_dataout, p.underflow, p.overflow, p.dataout);
		end
		end
		end
		4'b1010: begin
			product=p.data1*p.data2;
			exp_dataout=product[15:0];
			exp_underflow='0;
			exp_overflow=|product[31:16];
			if(p.dataout==exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			fail=fail+1;
			$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
		end
		end
		4'b1011: begin
			exp_dataout=p.data1>p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b1100: begin
			exp_dataout=p.data1<p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b1101: begin
			exp_dataout=p.data1==p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b1110: begin
			exp_dataout=p.data1!=p.data2;
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		4'b1111: begin
			exp_dataout={p.data2[7:0],p.data1[7:0]};
			if(p.dataout == exp_dataout && p.overflow==exp_overflow && exp_underflow==p.underflow)begin
				pass=pass+1;
			end else begin
			    fail=fail+1;
				$display("FAIL: data1=%0d data2=%0d operand=%0d|expected dataout=%0d overflow=%b underflow=%b|got dataout=%0d overflow=%b underflow=%b",p.data1, p.data2, p.operand, exp_dataout, exp_overflow, exp_underflow, p.dataout, p.overflow, p.underflow);
			end
			end
		default: begin
		$display("Error! Packet being skipped!");
		end
		endcase
		end
		endtask
task report();
    $display("ALU scoreboard: PASS=%0d FAIL=%0d", pass, fail);
endtask
endclass
module tb_top;
logic clk='0;
always #1 clk=~clk;
calcmain calculator(clk);
mailbox #(fifo_packet) fifogentodrv = new();
mailbox #(fifo_packet) fifomontoscore = new();
mailbox #(packet) gentodrv= new();
mailbox #(packet) montoscore = new();
fifo_generator fifogen=new(fifogentodrv);
fifo_driver fifodrive=new(fifogentodrv, calculator);
fifo_monitor fifomon=new(fifomontoscore,calculator);
fifo_scoreboard fifoscoreboard=new(fifomontoscore);
generator gen=new(gentodrv);
driver drive=new(gentodrv,calculator);
monitor mon=new(montoscore,calculator);
scoreboard score=new(montoscore);
calculator_main dut(
  .clk(clk),
  .reset(calculator.reset),
  .pop(calculator.pop),
  .push(calculator.push),
  .selA(calculator.selA),
  .selB(calculator.selB),
  .sel(calculator.sel),
  .start(calculator.start),
  .operand(calculator.operand),
  .data1(calculator.data1),
  .data2(calculator.data2),
  .overflow(calculator.overflow),
  .underflow(calculator.underflow),
  .dataout(calculator.dataout),
  .done(calculator.done),
  .fifo_full(calculator.fifo_full),
  .fifo_empty(calculator.fifo_empty),
  .fifo_data_out(calculator.fifo_out)
);
initial begin
  fork
    fifogen.run();
    fifodrive.run();
    fifomon.run();
    fifoscoreboard.run();
  join_none
  #100;
  fifoscoreboard.report();
  disable fork;
fork
    gen.run();
    drive.run();
    mon.run();
    score.run();
  join_none
  #270000;
  score.report();
  $finish;
end
endmodule
