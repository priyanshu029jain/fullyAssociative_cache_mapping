`timescale 1ns / 1ps
//`include "fullyAssociative_mapping.v" 


module testbench;
    reg clk;
    reg rst;
    reg [6:0] address;
    reg [7:0] data_in;
    reg write_enable;
    reg read_enable;
    wire [7:0] data_out;
    wire hit;
    wire [1:0] hit_line;

    fullyAssociative_mapping dut (
        .clk(clk),
        .rst(rst),
        .address(address),
        .data_in(data_in),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .data_out(data_out),
        .hit(hit),
        .hit_line(hit_line)
    );
      // Clock generation
    always #5 clk = ~clk; // 10 time units period

    initial begin
        // Initialize inputs
        clk = 1'b0;
        rst = 1'b1;
        address = 7'b000_0000; 
        data_in = 8'b0000_0000; 
        write_enable = 1'b0;
        read_enable = 1'b0; 

        //dumpfile and dumpvars for waveform generation
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);

        // Monitor the outputs
        $display("Starting simulation...");
        $monitor("Time: %0t | Address: %b | Data In: %b | Write Enable: %b | Read Enable: %b | Data Out: %b | Hit: %b | Hit Line: %b", 
                 $time, address, data_in, write_enable, read_enable, data_out, hit, hit_line);

        // Reset the system
        #12 rst = 1'b0; // Deassert reset after 10 time units\

        // Wait for a few time units and then change the address
        #10 read_enable = 1'b1; // Enable reading
        #10 address = 7'b000_0001; 
        #10 address = 7'b000_0010; 
        #10 address = 7'b000_0011; 
        #10 read_enable = 1'b0; // Disable reading

        // Now enable writing to the cache
        #10 write_enable = 1'b1; // Enable writing
        #10 data_in = 8'b1010_1010; 
            address = 7'b000_1001; 
        #10 data_in = 8'b1100_1100; 
            address = 7'b000_0110; 
        #10 write_enable = 1'b0; // Disable writing

        // Read from the same address again to check for a hit
        #10 read_enable = 1'b1; // Enable reading again

        $display("Simulation finished.");
        // Finish simulation after some time
        #15 $finish;
    end
endmodule