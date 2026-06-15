//word = 1 byte
//block = 4 word
//cache = 4 lines
//RAN  = 32 block
`define BYTE 8
`define FILE "external_storage.mem"

module fullyAssociative_mapping #(
    parameter   WORD_SIZE = 1,  // Size of a word in bytes
    parameter   BLOCK_SIZE = 4, // Number of words per block
    parameter   CACHE_LINES = 4,   // Number of lines in the cache
    parameter   RAM_BLOCKS = 32  // Number of blocks in memory
  )(
    input wire clk,
    input wire rst,
    input wire [address_bites-1:0] address,
    input wire [data_bites-1:0] data_in,
    input wire write_enable,
    input wire read_enable,
    output reg [data_bites-1:0] data_out,
    output reg hit,
    output reg [hit_line_bites-1:0] hit_line // Line number of the cache hit (if any)
  );

  // Calculate the number of bits for various components based on the parameters
  localparam word_bites = WORD_SIZE * `BYTE; // Number of bits in a word
  localparam block_bites = BLOCK_SIZE * word_bites; // Number of bits in a block
  localparam address_bites = $clog2(RAM_BLOCKS * BLOCK_SIZE); // Number of bits in the address
  localparam data_bites = word_bites; // Number of bits in the data bus
  localparam line_bites = block_bites; // Number of bits in a cache line
  localparam hit_line_bites = $clog2(CACHE_LINES); // Number of bits to represent the cache line index

  // Calculate the number of bits for the tag and offset based on the address breakdown
  localparam offset_bites = $clog2(BLOCK_SIZE); // Number of bits for the word offset within a block
  localparam tag_bites = address_bites - offset_bites; // Number of bits for the tag

  // memory and cache declaration
  reg [line_bites-1:0] cache [0:CACHE_LINES-1]; // Cache lines
  reg [block_bites-1:0] memory [0:RAM_BLOCKS-1]; // Main memory blocks
  reg [tag_bites-1:0] tag [0:CACHE_LINES-1]; // tag for each cache line

  //valid array to keep track of valid cache lines
  reg [CACHE_LINES-1:0] valid;

  // Initialize memory and cache
  integer i;
  initial
  begin : init_memory_cache
    $readmemh(`FILE, memory); // Load memory from external file

    for (i = 0; i < CACHE_LINES; i = i + 1)
    begin : init_cache
      cache[i] <= {line_bites{1'b0}}; // Initialize cache to zero
      tag[i] <= {tag_bites{1'b0}};   // Initialize tags to zero
      valid[i] <= 1'b0; // Initialize valid bits to zero
    end

  end

  // Address breakdown
  wire [tag_bites-1:0] block_address = address[address_bites -1:offset_bites]; // Block address
  wire [offset_bites-1:0] word_offset = address[offset_bites -1:0];   // Word offset


  // Cache operation logic
  // This always block handles both read and write operations based on the control signals.
  // On reset, it initializes the cache and memory. During normal operation, it checks for hits and updates the cache and memory accordingly.
  // The block uses nested loops to check for cache hits and to find empty lines for cache misses.
  // It also implements a simple replacement policy where the first line is replaced if all lines are valid.
  always @(posedge clk or posedge rst)
  begin : cache_operations
    if (rst)
    begin : reset_cache
      for (i = 0; i < CACHE_LINES; i = i + 1)
      begin : reset_cache_lines
        cache[i] <= {line_bites{1'b0}}; // Reset cache to zero
        tag[i] <= {tag_bites{1'b0}};   // Reset tags to zero
        valid[i] <= 1'b0; // Reset valid bits to zero
      end
      data_out <= {data_bites{1'b0}}; // High impedance on reset
      hit <= 1'b0;
      hit_line <= {hit_line_bites{1'b0}};
    end

    else
    begin : normal_operation
      // Cache hit detection and data output logic
      hit <= 1'b0;
      hit_line <= {hit_line_bites{1'b0}};

      if(read_enable && !write_enable)
      begin : read_operation

        for (i = 0; i < CACHE_LINES; i = i + 1)
        begin : for_loop
          if (valid[i] && tag[i] == block_address)
          begin : cache_hit
            hit <= 1'b1;
            hit_line <= i[hit_line_bites-1:0];
            data_out <= cache[i][word_offset * word_bites +: word_bites]; // Output the correct word based on the offset
            disable for_loop; // Exit the loop on hit
          end
        end
        if(!hit)
        begin : cache_miss
          // Cache miss: Load data from memory into cache
          data_out <= memory[block_address][word_offset * word_bites +: word_bites];
          // Find an empty line or replace the first line (simple replacement policy)
          for (i = 0; i < CACHE_LINES; i = i + 1)
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
        memory[block_address][word_offset*word_bites +: word_bites] <= data_in;

        for (i = 0; i < CACHE_LINES; i = i + 1)
        begin : for_loop
          if (valid[i] && tag[i] == block_address)
          begin : cache_hit
            cache[i][word_offset*word_bites +: word_bites] <= data_in;
            hit <= 1'b1;
            hit_line <= i[hit_line_bites-1:0];
            disable for_loop; // Exit the loop on hit
          end
        end
        if(!hit)
        begin : cache_miss
          // Cache miss: Load data from memory into cache
          // Find an empty line or replace the first line (simple replacement policy)
          for (i = 0; i < CACHE_LINES; i = i + 1)
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
        data_out <= {data_bites{1'b0}}; // Default output when neither read nor write is enabled
      end
    end
  end
endmodule
