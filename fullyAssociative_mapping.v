//word = 1 byte
//block = 4 word
//cache = 4 lines
//RAN  = 32 block
`define BYTE 8

module fullyAssociative_mapping(
    input wire clk,
    input wire rst,
    input wire [6:0] address,
    input wire [7:0] data_in,
    input wire write_enable,
    input wire read_enable,
    output reg [7:0] data_out,
    output reg hit,
    output reg [1:0] hit_line
  );

  // memory and cache declaration
  reg [4*`BYTE-1:0] cache [0:3];
  reg [32*`BYTE-1:0] memory [0:31];
  reg [4:0] tag [0:3]; // 5-bit tag for each cache line

  //valid array to keep track of valid cache lines
  reg [3:0] valid;

  // Initialize memory and cache
  integer i;
  initial
  begin : init_memory_cache
    $readmemh("external_storage.mem", memory); // Load memory from external file

    for (i = 0; i < 4; i = i + 1)
    begin : init_cache
      cache[i] <= {4*`BYTE{1'b0}}; // Initialize cache to zero
      tag[i] <= 5'b0;   // Initialize tags to zero
      valid[i] <= 1'b0; // Initialize valid bits to zero
    end

  end

  // Address breakdown
  wire [4:0] block_address = address[6:2]; // Block address (5 bits)
  wire [1:0] word_offset = address[1:0];   // Word offset (2 bits)


  // Cache operation logic
  // This always block handles both read and write operations based on the control signals.
  // On reset, it initializes the cache and memory. During normal operation, it checks for hits and updates the cache and memory accordingly.
  // The block uses nested loops to check for cache hits and to find empty lines for cache misses.
  // It also implements a simple replacement policy where the first line is replaced if all lines are valid.
  always @(posedge clk or posedge rst)
  begin : cache_operations
    if (rst)
    begin : reset_cache
      for (i = 0; i < 4; i = i + 1)
      begin : reset_cache_lines
        cache[i] <= {4*`BYTE{1'b0}}; // Reset cache to zero
        tag[i] <= 5'b0;   // Reset tags to zero
        valid[i] <= 1'b0; // Reset valid bits to zero
      end
      data_out <= 8'bz; // High impedance on reset
      hit <= 1'b0;
      hit_line <= 2'b0;
    end

    else
    begin : normal_operation
      // Cache hit detection and data output logic
      hit <= 1'b0;
      hit_line <= 2'b0;

      if(read_enable && !write_enable)
      begin : read_operation

        for (i = 0; i < 4; i = i + 1)
        begin : for_loop
          if (valid[i] && tag[i] == block_address)
          begin : cache_hit
            hit <= 1'b1;
            hit_line <= i[1:0];
            data_out <= cache[i][word_offset*`BYTE +: `BYTE]; // Output the correct word based on the offset
            disable for_loop; // Exit the loop on hit
          end
        end
        if(!hit)
        begin : cache_miss
          // Cache miss: Load data from memory into cache
          data_out <= memory[block_address][word_offset*`BYTE +: `BYTE];
          // Find an empty line or replace the first line (simple replacement policy)
          for (i = 0; i < 4; i = i + 1)
          begin : for_loop
            if (!valid[i])
            begin : empty_line
              cache[i] <= memory[block_address];
              tag[i] <= block_address;
              valid[i] <= 1'b1;
              disable for_loop; // Exit the loop after loading
            end
          end

          // If all lines are valid, replace the first line (simple replacement policy)
          if (~|valid)
          begin : replace_line
            cache[0] <= memory[block_address];
            tag[0] <= block_address;
            valid[0] <= 1'b1;
          end
        end
      end

      else if(write_enable && !read_enable)
      begin : write_operation
        // Write data to memory and update cache if it's a hit
        memory[block_address][word_offset*`BYTE +: `BYTE] <= data_in;

        for (i = 0; i < 4; i = i + 1)
        begin : for_loop
          if (valid[i] && tag[i] == block_address)
          begin : cache_hit
            cache[i][word_offset*`BYTE +: `BYTE] <= data_in;
            hit <= 1'b1;
            hit_line <= i[1:0];
            disable for_loop; // Exit the loop on hit
          end
        end
        if(!hit)
        begin : cache_miss
          // Cache miss: Load data from memory into cache
          // Find an empty line or replace the first line (simple replacement policy)
          for (i = 0; i < 4; i = i + 1)
          begin : for_loop
            if (!valid[i])
            begin : empty_line
              cache[i] <= memory[block_address];
              tag[i] <= block_address;
              valid[i] <= 1'b1;
              disable for_loop; // Exit the loop after loading
            end
          end

          // If all lines are valid, replace the first line (simple replacement policy)
          if (~|valid)
          begin : replace_line
            cache[0] <= memory[block_address];
            tag[0] <= block_address;
            valid[0] <= 1'b1;
          end
        end
      end

      else
      begin : no_operation
        data_out <= 8'bz; // Default output when neither read nor write is enabled
      end
    end
  end
endmodule
