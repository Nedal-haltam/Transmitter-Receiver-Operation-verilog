module err(din,dout,clk);
  input clk;
  input din;
  output reg dout;
  
      always@( negedge clk ) begin
      dout = $urandom%2;
      end
endmodule

module source_memory(data,addr);
  input [11:0] addr;
  output reg [15:0] data;
  reg [15:0] rom [4095:0];
  integer i;
  
  
  initial begin
      for(i = 0; i < 4096; i = i + 1)
      rom[i] = i;
    rom[1010] = 16'hFFFF;
    //to add the special pattern
  end
  
  always @(addr)
    begin
      data = rom[addr];
    end
endmodule

module destination_memory(wr,memread,datain,addr);
  
  
  input wr;
  input [11:0] addr;
  input [15:0] datain;
  output reg [15:0] memread;
  reg [15:0] mem [4095:0];
  integer i;
  
  
  always@( addr or wr )
    begin
      if(wr == 0)
        mem[addr] = datain;
      
      memread = mem[addr];
    end
endmodule




module system(parityin,req,ack,full,sdata,ddata,saddr,daddr,den,clk);
  inout parityin,req,ack,full;
  wire wr,d15;
  input den,clk;
  output [15:0] ddata;
  inout [15:0] sdata;
  input  [11:0] saddr,daddr;
  wire [11:0] saddrc,daddrc;
  wire [15:0] sdatac,sdatacc;
  transmitter tx(den,clk,saddr,saddrc,parityin,req,ack,full,sdata,sdatac);
  source_memory srcmem(sdata,saddrc);
  
  err errormodule(sdatac[15],d15,clk);
  
  receiver rx(wr,clk,daddr,daddrc,parityin,req,ack,full,{d15,sdatac[14:0]},sdatacc);
  destination_memory destmem(wr,ddata,sdatacc,daddrc);
  
endmodule


module testbench;
  reg [11:0] saddr,daddr;
  reg den;
  reg clk = 0;
  wire [15:0] sdata,ddata;
  wire parity;
  wire req;
  wire ack;
  wire full;
  integer i,j,k;
  reg [11:0] caddr;
  
  
  system sys(parity,req,ack,full,sdata,ddata,saddr,daddr,den,clk);
  always #10 clk <= ~clk;
  initial begin
    caddr = 1010;//current address
    saddr = caddr;
    daddr = caddr;
    #200;
    den = 1;
    #2500;
	den = 0;

    for(i = caddr-10; i < caddr+20; i = i + 1)
      begin
        saddr = i;
        daddr = i;
        #20 $display("source[%1d] = %1d, dest[%1d] = %1d",saddr,sdata,daddr,ddata);
      end
    $finish;
  end
endmodule


module transmitter(den,clk,saddr,curraddr,parity,req,ack,full,currdata,currdatao);
  input clk, ack, full, den;
  input [11:0] saddr;
  output reg [11:0] curraddr;
  output reg parity, req;
  input [15:0] currdata;
  output reg [15:0] currdatao;
  reg [12:0] prevaddr;
  reg [15:0] prevdata;
  reg pp;
  initial begin #20;parity=0; 
  req=1;pp=0;
  curraddr=saddr;
  prevaddr=saddr;
  currdatao=currdata;
  prevdata=0;end
  always@( negedge clk ) begin
  if(den && !full) begin
    if (prevdata == 65535 && ack) req = 0;// if we did send the special pattern we stop sending data
  else begin
  if(ack) begin
  if(prevaddr-1 != 4095 ) begin // if we did not reach the last address we send more data
  prevdata = currdata;// save a copy of the data sent
  curraddr <= prevaddr+1; // update the address to the next one to prepare the next data to send
  currdatao <= currdata; // send the current data
  
  req = 1; // set req equal to logic 1 to send data
  parity = (!(^currdata)) ? 0 : 1; // here we know the eveb parity bit of the data
  prevaddr = prevaddr+1; // update the address (counter) to the next one
  pp = parity; // save the parity bit to use it later if the data was invalid
  end
  else req = 0; // else we stop because we reached the last address of the memory
  end
  else begin 
  // if the data was not acknowledge we send it again regardless of the previous address
  currdatao = prevdata; // restore the previous data sent earlier
  parity = pp; // restore the saved parity bit
  req = 1; // set req equal to logic 1 to send data
  end
  end // for the big else
  end else begin // if(den && !full)
  req = 0; // reset req to logic 0 because we done want to send data
  curraddr = saddr; // update the current address to read the data from the memory 
  end end endmodule


module receiver(wr,clk,daddr,daddrc,parity,req,ack,full,sdata,sdatacc);
  input clk, parity, req;
  input [11:0] daddr;
  output reg [11:0] daddrc;
  input [15:0] sdata;
  output reg [15:0] sdatacc;
  output reg wr;
  output reg ack, full;
  reg [11:0] curraddr;
  initial begin
  #10;
  ack = 1;
  full = 0;
  wr=1; curraddr = daddr; 
  end
  always@( posedge clk ) begin
  daddrc = curraddr; // update the current destination address to write on it
  sdatacc = sdata; // update the data that we want to write
  if(req) begin // if req is 1 we want to receive the transmitted data
  if((!(^sdata) && !parity)||((^sdata) && parity)) begin
  // change the value of wr so we can activate the destination memory
  wr = 1;
  #5;
  wr = 0;
  #5;
  wr = 1;
  ack = 1; // set ack to logic 1 because we received the valid data correctly
  // check if the current address is the last address
  if(curraddr == 4095) full = 1;
  else                 full = 0;
  #5;
  curraddr = curraddr + 1; // update to the next destination address
  end else 
  // if req = 0 we done receive data  
  ack = 0; end else
  ack = 1; // if req = 0 we set ack = 1
  daddrc = daddr; // update the destination address so we can read data from the memory
  end endmodule



