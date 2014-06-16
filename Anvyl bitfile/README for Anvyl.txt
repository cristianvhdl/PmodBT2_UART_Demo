Troubleshooting the PmodBT2 on the Anvyl board

Confirm the PmodBT2 is connected correctly to your PC.  
1. power the Pmod from the 3v3 and ground header on your board (to remove any communication with the board)
2. Attach a jumper to JP4 to force the PmodBT2 into 9600 baud rate
3. pair with PC using pin 1234 
4. my enumerated two com ports for when I paired the device take note of both 
5. open your favorite hyperterminal ( I like tera term) 
6. connect to one of the com ports with the settings: 
    - baud rate: 9600 
    - data bits: 8 bits 
    - parity: none 
    - stop: 1 bit 
    - flow control: none 
7. wait until hyperterminal connects 
    - if it does not connect then try a different com port 
8. remove power from the pmod 
9. add power to the pmod and immediately: 
    - dissconnect the hyperterminal 
    - reconnect the hyperterminal 
    - type "$$$" (without quote) into the hyperterminal 
10. the Pmod should print CMD to the terminal 
11. type "h" and the command help menu should print.  

This confirms that the Pmod is functioning.  If you do not get the command menu, then please try the remaining com ports on your computer. 

To run the demo
1. Attach the PmodBT2 to the Pmod header JG
2. Program the FPGA with the file named "PmodBT2_UART_Demo_for_Anvyl.bit" using Digilent Adept or Xilinx impact.
3. LD0 will flash quickly.
4. When button BTN0 is pressed, "button press detected" will appear in the hyperterminal
