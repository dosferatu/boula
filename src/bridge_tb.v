`include "bridge.v"

module bridge_tb();
reg clk;

bridge U0(
);

initial begin
  clk <= 0;

  forever begin
    #10 clk <= ~clk;
  end
end
endmodule
