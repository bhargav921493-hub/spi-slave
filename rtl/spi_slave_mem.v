/**
 * SPI Slave with Integrated 256-Byte Memory
 * 
 * Features:
 *  - All 4 SPI modes (CPOL/CPHA configurable)
 *  - Full-duplex SPI communication
 *  - 256-byte dual-port RAM with address-based read/write
 *  - Protocol: First byte = {R/W_bit, addr[6:0]}
 *  - Supports MSB-first data order
 *  - Synthesizable on FPGA
 *
 * Author: SPI Slave Team
 * Date: 2026-06-15
 */

module spi_slave_mem #(
    parameter DWIDTH = 8,           // Data width (8-255 bits)
    parameter ADDR_WIDTH = 8,       // Address width for memory (8 = 256 bytes)
    parameter MEM_DEPTH = 256       // Memory depth
)(
    // Clock and Reset
    input wire clk,                 // System clock
    input wire rst_n,               // Active-low reset
    
    // SPI Interface
    input wire sclk,                // SPI Serial Clock
    input wire copi,                // Controller Out, Peripheral In (MOSI)
    output wire cipo,               // Controller In, Peripheral Out (MISO)
    input wire ncs,                 // Chip Select (active low)
    
    // Configuration
    input wire [1:0] spi_mode,      // {CPOL, CPHA}
    
    // Status/Control
    output reg xfer_done,           // Pulse when transaction complete
    output reg [ADDR_WIDTH-1:0] mem_addr,  // Current memory address
    output reg mem_wr_en,           // Memory write enable
    output reg [7:0] mem_wr_data    // Data written to memory
);

    // Internal parameters
    localparam BITS_PER_BYTE = 8;
    
    // State machine
    localparam IDLE = 2'b00;
    localparam ADDR_RX = 2'b01;
    localparam DATA_XFER = 2'b10;
    
    // Registers
    reg [1:0] state;
    reg [15:0] bit_count;
    reg [7:0] shift_reg_rx;
    reg [7:0] shift_reg_tx;
    reg rw_bit;                     // 1 = Read, 0 = Write
    reg cpol, cpha;
    reg prev_sclk;
    reg [ADDR_WIDTH-1:0] current_addr;
    
    // Memory array - 256 bytes
    reg [7:0] memory [0:MEM_DEPTH-1];
    
    // CIPO output
    assign cipo = (state != IDLE && !ncs) ? shift_reg_tx[7] : 1'bz;
    
    // Extract CPOL and CPHA from mode
    always @(*) begin
        cpol = spi_mode[1];
        cpha = spi_mode[0];
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_count <= 16'b0;
            shift_reg_rx <= 8'b0;
            shift_reg_tx <= 8'b0;
            prev_sclk <= 1'b0;
            rw_bit <= 1'b0;
            current_addr <= {ADDR_WIDTH{1'b0}};
            xfer_done <= 1'b0;
            mem_wr_en <= 1'b0;
            mem_wr_data <= 8'b0;
            mem_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            xfer_done <= 1'b0;  // Default: no transfer done
            mem_wr_en <= 1'b0;  // Default: no write
            
            if (ncs) begin
                // Chip select inactive - reset to idle
                state <= IDLE;
                bit_count <= 16'b0;
                shift_reg_rx <= 8'b0;
                shift_reg_tx <= 8'b0;
                prev_sclk <= cpol;
                xfer_done <= 1'b0;
            end else begin
                // Chip select active - process SPI data
                case (state)
                    IDLE: begin
                        // Wait for first clock edge to start address byte
                        if (is_sample_edge()) begin
                            shift_reg_rx <= {copi, 7'b0};
                            shift_reg_tx <= 8'b0;
                            bit_count <= 16'b1;
                            state <= ADDR_RX;
                        end
                    end
                    
                    ADDR_RX: begin
                        // Receive address byte (8 bits)
                        if (is_sample_edge()) begin
                            shift_reg_rx <= {shift_reg_rx[6:0], copi};
                            bit_count <= bit_count + 1;
                        end
                        if (is_shift_edge()) begin
                            shift_reg_tx <= {shift_reg_tx[6:0], 1'b0};
                        end
                        
                        if (bit_count == BITS_PER_BYTE) begin
                            // Address byte complete
                            rw_bit <= shift_reg_rx[7];  // MSB = R/W bit
                            current_addr <= shift_reg_rx[ADDR_WIDTH-1:0];
                            bit_count <= 16'b0;
                            
                            // Pre-load TX data for read operation
                            if (shift_reg_rx[7]) begin  // Read operation
                                shift_reg_tx <= memory[shift_reg_rx[ADDR_WIDTH-1:0]];
                            end else begin
                                shift_reg_tx <= 8'b0;
                            end
                            
                            state <= DATA_XFER;
                        end
                    end
                    
                    DATA_XFER: begin
                        // Exchange data bytes
                        if (is_sample_edge()) begin
                            shift_reg_rx <= {shift_reg_rx[6:0], copi};
                            bit_count <= bit_count + 1;
                        end
                        if (is_shift_edge()) begin
                            shift_reg_tx <= {shift_reg_tx[6:0], 1'b0};
                        end
                        
                        // Process complete bytes
                        if (bit_count == BITS_PER_BYTE && bit_count > 0) begin
                            if (!rw_bit) begin  // Write operation
                                // Store received byte in memory
                                memory[current_addr] <= shift_reg_rx;
                                mem_addr <= current_addr;
                                mem_wr_data <= shift_reg_rx;
                                mem_wr_en <= 1'b1;
                            end else begin  // Read operation
                                // Pre-load next byte for read
                                if (current_addr + 1 < MEM_DEPTH) begin
                                    shift_reg_tx <= memory[current_addr + 1];
                                end
                            end
                            
                            current_addr <= current_addr + 1;
                            bit_count <= 16'b0;
                            shift_reg_rx <= 8'b0;
                        end
                    end
                endcase
                
                prev_sclk <= sclk;
            end
        end
    end
    
    // Helper function: Detect sample edge based on SPI mode
    function is_sample_edge;
        begin
            case (spi_mode)
                2'b00: is_sample_edge = (!prev_sclk && sclk);        // Mode 0: rising
                2'b01: is_sample_edge = (prev_sclk && !sclk);        // Mode 1: falling
                2'b10: is_sample_edge = (prev_sclk && !sclk);        // Mode 2: falling
                2'b11: is_sample_edge = (!prev_sclk && sclk);        // Mode 3: rising
                default: is_sample_edge = 1'b0;
            endcase
        end
    endfunction
    
    // Helper function: Detect shift edge based on SPI mode
    function is_shift_edge;
        begin
            case (spi_mode)
                2'b00: is_shift_edge = (prev_sclk && !sclk);        // Mode 0: falling
                2'b01: is_shift_edge = (!prev_sclk && sclk);        // Mode 1: rising
                2'b10: is_shift_edge = (!prev_sclk && sclk);        // Mode 2: rising
                2'b11: is_shift_edge = (prev_sclk && !sclk);        // Mode 3: falling
                default: is_shift_edge = 1'b0;
            endcase
        end
    endfunction

endmodule