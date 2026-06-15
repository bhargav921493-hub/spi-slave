/**
 * Testbench for SPI Slave with Memory
 * 
 * Tests:
 *  - All 4 SPI modes (0, 1, 2, 3)
 *  - Write pattern to slave memory
 *  - Read pattern back from slave
 *  - Verify data integrity
 *
 * Author: SPI Slave Team
 * Date: 2026-06-15
 */

`timescale 1ns / 1ps

module tb_spi_slave_mem;

    // Testbench parameters
    localparam CLK_PERIOD = 10;      // 10ns = 100MHz
    localparam SPI_PERIOD = 40;      // 40ns = 25MHz SPI clock
    localparam ADDR_WIDTH = 8;
    localparam MEM_DEPTH = 256;
    
    // Test data
    localparam [7:0] WRITE_ADDR = 8'h00;  // Start address (R/W bit = 0)
    localparam [7:0] READ_ADDR  = 8'h80;  // Start address (R/W bit = 1)
    localparam TEST_BYTES = 16;            // Number of bytes to test
    
    // Signals
    reg clk;
    reg rst_n;
    reg sclk;
    reg copi;
    wire cipo;
    reg ncs;
    reg [1:0] spi_mode;
    wire xfer_done;
    wire [7:0] mem_addr;
    wire mem_wr_en;
    wire [7:0] mem_wr_data;
    
    // Test data array
    reg [7:0] write_data [0:TEST_BYTES-1];
    reg [7:0] read_data [0:TEST_BYTES-1];
    integer i, j;
    integer errors = 0;
    
    // Instantiate DUT
    spi_slave_mem #(
        .DWIDTH(8),
        .ADDR_WIDTH(8),
        .MEM_DEPTH(256)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .copi(copi),
        .cipo(cipo),
        .ncs(ncs),
        .spi_mode(spi_mode),
        .xfer_done(xfer_done),
        .mem_addr(mem_addr),
        .mem_wr_en(mem_wr_en),
        .mem_wr_data(mem_wr_data)
    );
    
    // Generate system clock
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end
    
    // SPI clock generator (manual, not automated)
    task spi_clock_pulse;
        begin
            #SPI_PERIOD;
            sclk = ~sclk;
        end
    endtask
    
    // Send one SPI bit
    task spi_send_bit(input bit_val);
        begin
            copi = bit_val;
            spi_clock_pulse();  // Clock pulse
        end
    endtask
    
    // Send one SPI byte
    task spi_send_byte(input [7:0] byte_val);
        integer bit_idx;
        begin
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                spi_send_bit(byte_val[bit_idx]);
            end
        end
    endtask
    
    // Receive one SPI byte
    task spi_recv_byte(output [7:0] byte_val);
        integer bit_idx;
        reg bit_val;
        begin
            byte_val = 8'b0;
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                spi_clock_pulse();  // Clock pulse
                #(SPI_PERIOD/2);    // Wait for data to stabilize
                byte_val[bit_idx] = cipo;
            end
        end
    endtask
    
    // Write pattern to slave
    task write_pattern;
        input [7:0] start_addr;
        integer idx;
        begin
            $display("\n=== WRITE PATTERN (Mode %d) ===", spi_mode);
            ncs = 1'b0;  // Chip select active
            #(SPI_PERIOD);
            
            // Send address byte (R/W=0, addr[6:0])
            spi_send_byte(start_addr);
            #(SPI_PERIOD);
            
            // Send data bytes
            for (idx = 0; idx < TEST_BYTES; idx = idx + 1) begin
                spi_send_byte(write_data[idx]);
                $display("  Write [0x%02X]: 0x%02X", start_addr + idx, write_data[idx]);
                #(SPI_PERIOD);
            end
            
            ncs = 1'b1;  // Chip select inactive
            #(SPI_PERIOD);
            $display("  Write complete\n");
        end
    endtask
    
    // Read pattern from slave
    task read_pattern;
        input [7:0] start_addr;
        integer idx;
        reg [7:0] rx_byte;
        begin
            $display("\n=== READ PATTERN (Mode %d) ===", spi_mode);
            ncs = 1'b0;  // Chip select active
            #(SPI_PERIOD);
            
            // Send address byte (R/W=1, addr[6:0])
            spi_send_byte(start_addr | 8'h80);  // Set R/W bit
            #(SPI_PERIOD);
            
            // Read data bytes
            for (idx = 0; idx < TEST_BYTES; idx = idx + 1) begin
                spi_recv_byte(rx_byte);
                read_data[idx] = rx_byte;
                $display("  Read [0x%02X]: 0x%02X", start_addr + idx, rx_byte);
                #(SPI_PERIOD);
            end
            
            ncs = 1'b1;  // Chip select inactive
            #(SPI_PERIOD);
            $display("  Read complete\n");
        end
    endtask
    
    // Compare read and write data
    task verify_data;
        integer idx;
        begin
            $display("\n=== VERIFY DATA ===");
            errors = 0;
            
            for (idx = 0; idx < TEST_BYTES; idx = idx + 1) begin
                if (read_data[idx] !== write_data[idx]) begin
                    $display("  ERROR [0x%02X]: Expected 0x%02X, Got 0x%02X", 
                             WRITE_ADDR + idx, write_data[idx], read_data[idx]);
                    errors = errors + 1;
                end else begin
                    $display("  PASS [0x%02X]: 0x%02X", WRITE_ADDR + idx, read_data[idx]);
                end
            end
            
            if (errors == 0)
                $display("\n*** ALL TESTS PASSED ***\n");
            else
                $display("\n*** %d ERRORS DETECTED ***\n", errors);
        end
    endtask
    
    // Initialize test data
    task init_test_data;
        integer idx;
        begin
            for (idx = 0; idx < TEST_BYTES; idx = idx + 1) begin
                write_data[idx] = 8'hA5 + idx;  // Pattern: 0xA5, 0xA6, ..., 0xB4
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("  SPI Slave Memory Testbench");
        $display("========================================\n");
        
        // Initialize
        clk = 1'b0;
        rst_n = 1'b0;
        sclk = 1'b0;
        copi = 1'b0;
        ncs = 1'b1;
        spi_mode = 2'b00;
        
        init_test_data();
        
        // Reset sequence
        #(5 * CLK_PERIOD);
        rst_n = 1'b1;
        #(5 * CLK_PERIOD);
        
        // Test all 4 SPI modes
        for (i = 0; i < 4; i = i + 1) begin
            spi_mode = i;
            sclk = (i[1] == 0) ? 1'b0 : 1'b1;  // Set SCLK to CPOL value
            
            $display("\n========================================");
            $display("  Testing SPI Mode %d (CPOL=%d, CPHA=%d)", 
                     i, i[1], i[0]);
            $display("========================================");
            
            #(10 * CLK_PERIOD);
            
            // Write pattern
            write_pattern(WRITE_ADDR);
            
            #(100 * CLK_PERIOD);
            
            // Read pattern back
            read_pattern(READ_ADDR);
            
            #(100 * CLK_PERIOD);
            
            // Verify
            verify_data();
            
            #(100 * CLK_PERIOD);
        end
        
        $display("\n========================================");
        $display("  Testbench Complete");
        $display("========================================\n");
        
        $finish;
    end
    
    // Monitor signals
    initial begin
        $monitor("Time=%0t | SCLK=%b COPI=%b CIPO=%b NCS=%b | State=%d BitCnt=%d", 
                 $time, sclk, copi, cipo, ncs, dut.state, dut.bit_count);
    end

endmodule