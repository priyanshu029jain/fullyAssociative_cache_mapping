//word = 1 byte
//block = 1 word
//cache = 4 lines
//RAN  = 32 block

module fullyAssociative_mapping(
    input wire [4:0] address,
    input wire [7:0] data_in,
    input wire write_enable,
    input wire read_enable,
    output reg [7:0] data_out,
    output reg hit,
    output reg [1:0] hit_line
  );

  // memory and cache declaration
  reg [7:0] cache [0:3];
  reg [7:0] memory [0:31];
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
      cache[i] = 8'b0; // Initialize cache to zero
      tag[i] = 5'b0;   // Initialize tags to zero
      valid[i] = 1'b0; // Initialize valid bits to zero
    end

  end

  always @(*)
  begin : cache_operations
    // Cache hit detection and data output logic
    hit = 1'b0;
    hit_line = 2'b0;

    if(read_enable && !write_enable)
    begin : read_operation

      for (i = 0; i < 4; i = i + 1)
      begin : for_loop
        if (valid[i] && tag[i] == address[4:0])
        begin : cache_hit
          hit = 1'b1;
          hit_line = i[1:0];
          data_out = cache[i];
          disable for_loop; // Exit the loop on hit
        end
      end
      if(!hit)
      begin : cache_miss
        // Cache miss: Load data from memory into cache
        data_out = memory[address[4:0]];
        // Find an empty line or replace the first line (simple replacement policy)
        for (i = 0; i < 4; i = i + 1)
        begin : for_loop
          if (!valid[i])
          begin : empty_line
            cache[i] = memory[address[4:0]];
            tag[i] = address[4:0];
            valid[i] = 1'b1;
            disable for_loop; // Exit the loop after loading
          end
        end

        // If all lines are valid, replace the first line (simple replacement policy)
        if (~|valid)
        begin : replace_line
          cache[0] = memory[address[4:0]];
          tag[0] = address[4:0];
          valid[0] = 1'b1;
        end
      end
    end

    else if(write_enable && !read_enable)
    begin : write_operation
      // Write data to memory and update cache if it's a hit
      memory[address[4:0]] = data_in;

      for (i = 0; i < 4; i = i + 1)
      begin : for_loop
        if (valid[i] && tag[i] == address[4:0])
        begin : cache_hit
          cache[i] = data_in;
          hit = 1'b1;
          hit_line = i[1:0];
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
            cache[i] = data_in;
            tag[i] = address[4:0];
            valid[i] = 1'b1;
            disable for_loop; // Exit the loop after loading
          end
        end

        // If all lines are valid, replace the first line (simple replacement policy)
        if (~|valid)
        begin : replace_line
          cache[0] = data_in;
          tag[0] = address[4:0];
          valid[0] = 1'b1;
        end
      end
    end

    else
    begin : no_operation
      data_out = 8'bz; // Default output when neither read nor write is enabled
    end
  end
endmodule
