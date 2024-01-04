module oled_ssd1306 (
  input  logic clk,
  input  logic rst,
  output logic sdo,
  output logic sdt,
  input  logic sdi,
  output logic sck
);

  parameter int REFCLK_HZ = 125000000;


// Fundamental Connamd Table
parameter [7:0] COMMAND_SET_CONTRAST_CONTROL = 8'hA8;

parameter [7:0] COMMAND_ENTIRE_DISPLAY_OFF = 8'hA4;
parameter [7:0] COMMAND_ENTIRE_DISPLAY_ON  = 8'hA5;

parameter [7:0] COMMAND_DISPLAY_NORMAL     = 8'hA4;
parameter [7:0] COMMAND_DISPLAY_INVERSE    = 8'hA5;

parameter [7:0] COMMAND_ENTIRE_DISPLAY_OFF = 8'hA4;
parameter [7:0] COMMAND_ENTIRE_DISPLAY_ON  = 8'hA5;



parameter [7:0] COMMAND_SET_DISPLAY_OFFSET = 8'hD3;
parameter [7:0] COMMAND_SET_START_LINE     = 8'h40;

//

parameter [7:0] COMMAND_SET_COLUMN_ADDRESS = 8'h21;
parameter [7:0] COMMAND_SET_PAGE_ADDRESS   = 8'h22;

enum logic {
    RESET
    SET_MUX_RATIO
    SET_DISPLAY_OFFSET
    SET_START_LINE
    SET_SEGMENT_REMAP
    SET_COM_OUT_SCAN_DIRECTION
    SET_COM_OUT_HARDWARE_CONFIG
    SET_CONTRAST
    RESUME_DISPLAY
    SET_OSCILLATOR_FREQ
    ENABLE_CHARGE_PUMP
    TURN_DISPLAY_ON
    
ra
} state;


always_ff @ (posedge clk) begin
  if (rst) begin

  end
  else begin
    case (state)
      SET_MUX_RATIO               : begin i2c_din <= {}, i2c_len <= ; end
      SET_DISPLAY_OFFSET          : begin i2c_din <= {}, i2c_len <= ; end
      SET_START_LINE              : begin i2c_din <= {}, i2c_len <= ; end
      SET_SEGMENT_REMAP           : begin i2c_din <= {}, i2c_len <= ; end
      SET_COM_OUT_SCAN_DIRECTION  : begin i2c_din <= {}, i2c_len <= ; end
      SET_COM_OUT_HARDWARE_CONFIG : begin i2c_din <= {}, i2c_len <= ; end
      SET_CONTRAST                : begin i2c_din <= {}, i2c_len <= ; end
      RESUME_DISPLAY              : begin i2c_din <= {}, i2c_len <= ; end
      SET_OSCILLATOR_FREQ         : begin i2c_din <= {}, i2c_len <= ; end
      ENABLE_CHARGE_PUMP          : begin i2c_din <= {}, i2c_len <= ; end
      TURN_DISPLAY_ON             : begin i2c_din <= {}, i2c_len <= ; end
    endcase
  end
end

i2c #(
  .PRESCALER (REFCLK_HZ/100000), 
  .BYTES_W   (3), 
  .BYTES_R   (2)  
) i2c_inst (
  .clk     (clk),
  .rst     (rst),

  .sda_i   (sdi),
  .sda_t   (sdt),
  .sda_o   (sdo),
  .scl     (sck),

  .din     (),  // input data
  .ain     (7'h3C),  // 7-bit slave address
  .rnw     (0), // 1 = read, 0 = write
  .ptr_set (), // 1 to set pointer only
  .vin     (),
  .dout    (),
  .vout    (),
  .busy    ()
);

endmodule

module i2c #(
  parameter integer PRESCALER = 10, 
  parameter integer BYTES_W  = 3,  // expected byte count for write operation
  parameter integer BYTES_R  = 2   // expected byte count to read 
)
(
  input  logic clk,
  input  logic rst,

  input  logic sda_i,
  output logic sda_t,
  output logic sda_o,
  output logic scl,

  input  logic [BYTES_W-1:0][7:0] din,  // input data
  input  logic [6:0]              ain,  // 7-bit slave address
  input  logic                    rnw, // 1 = read, 0 = write
  input  logic                    ptr_set, // 1 to set pointer only
  input  logic                    vin,
  output logic [BYTES_R-1:0][7:0] dout,
  output logic                    vout,
  output logic                    busy
);

parameter integer PRESCALER_HALF = integer'(PRESCALER/2);

typedef enum logic [2:0] {
  IDLE,
  START,
  TX,
  ACK_S,
  ACK_M,
  RX,
  STOP
} fsm;

logic scl_r; // scl reg
logic sda_r; // sda reg
logic sda_t; // sda output enable
logic scl_oe; // scl output enable
logic scl_pos; // scl pos edge
logic scl_neg; // scl neg edge
logic [7:0] dts; // data to send (1 byte)
logic [7:0] rd; // byte being read
logic [3:0] bit_ctr;
logic [3:0] byte_ctr;

logic [$clog2(PRESCALER)-1:0] ctr;

assign scl_pos = (ctr == PRESCALER-1);
assign scl_neg = (ctr == PRESCALER_HALF-1);

assign scl = (scl_oe) ? scl_r : 1'bz; 
assign sda = (sda_t) ? sda_r : 1'bz;

assign busy = (fsm != IDLE);

always @ (posedge clk) begin
  if (rst) begin
    fsm      <= IDLE;
    dts      <= 0;
    vout     <= 0;
    dout     <= 0;
    rd       <= 0;
    bit_ctr  <= 0;
    byte_ctr <= 0;
    ctr      <= 0;
    sda_t   <= 0;
    scl_r    <= 1;
    sda_r    <= 0;
    scl_oe   <= 0;
  end
  else begin
    ctr <= (ctr == PRESCALER-1 || vin) ? 0 : ctr + 1;
    if (ctr == PRESCALER-1 && fsm != START) scl_r <= 1;
    if (ctr == PRESCALER_HALF-1) scl_r <= 0;
    case (fsm)
      IDLE : begin
        scl_oe   <= 0;
        sda_t   <= 0;
        byte_ctr <= 0;
        bit_ctr  <= 0;
        if (vin) begin
          dts <= {ain[6:0], rnw};
          fsm <= START;
        end
      end
      START : begin
        if (scl_neg) begin
          sda_t <= 1;
          sda_r  <= 0;
        end
        if (scl_pos) begin
          fsm    <= TX;
          scl_oe <= 1;
        end
      end
      TX : begin
        if (scl_neg) begin
          dts[7:1] <= dts[6:0];
          sda_r    <= dts[7];
          bit_ctr  <= bit_ctr + 1;
        end
        if (bit_ctr == 9) begin
          byte_ctr <= byte_ctr + 1;
          fsm      <= ACK_S;
          sda_t   <= 0;
        end
        else sda_t <= 1;
      end
      ACK_S : begin // Slave ack
        bit_ctr <= (rnw) ? 0 : 1;
        if (scl_pos) begin 
          dts <= din[BYTES_W-byte_ctr];
        end
        if (scl_neg) begin
          sda_r  <= (byte_ctr == BYTES_W + 1) ? 0 : dts[7];
          dts[7:1] <= dts[6:0];
          fsm    <= (rnw) ? RX : (byte_ctr == BYTES_W + 1 || (byte_ctr == 2 && ptr_set )) ? STOP : TX;
          sda_t <= (rnw) ? 0 : 1;
        end
      end
      RX : begin
        vout   <= 0;
        sda_t <= 0;
        if (scl_pos) begin
          rd[0]   <= sda;
          rd[7:1] <= rd[6:0];
          bit_ctr <= bit_ctr + 1;
        end
        if (bit_ctr == 8 && scl_neg) begin
          sda_t           <= 1;
          sda_r            <= (byte_ctr == BYTES_R) ? 1 : 0;
          fsm              <= ACK_M;
          dout[BYTES_R-byte_ctr] <= rd;
        end
      end
      ACK_M : begin 
        bit_ctr <= 0;
        if (scl_neg) begin
          if (byte_ctr == BYTES_R) vout <= 1;
          byte_ctr <= byte_ctr + 1;
          fsm <= (byte_ctr == BYTES_R) ? STOP : RX;
        end
      end
      STOP : begin
        vout <= 0;
        if (scl_neg) begin
          scl_oe <= 0;
          sda_r  <= 0;
          fsm <= IDLE;
        end
      end
    endcase
  end
end

endmodule
