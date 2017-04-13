# Overview
This is an attempt to mimic the 8-bit breadboard computer by Ben Eater:
https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU

Suggestions and contributions are welcome.

# Optimizations
A number of optimizations has been implemented. So where the original design
uses six clock cycles for each instruction, the current design uses only
two clock cycles for most instructions.

# Implementation
Everything is implemented in VHDL, taylored for the BASYS2 FPGA board
http://store.digilentinc.com/basys-2-spartan-3e-fpga-trainer-board-limited-time-see-basys-3/ , see picture below:
![alt text](https://github.com/MJoergen/bcomp/blob/master/img/Basys2.png "")

The FPGA board is based on a Spartan-3E FPGA chip from Xilinx.

The overall block diagram of the computer is here:
![alt text](https://github.com/MJoergen/bcomp2/blob/master/img/Block_diagram_new.png "")

The CPU model block diagram is here:
![alt text](https://github.com/MJoergen/bcomp2/blob/master/img/CPU_model.png "")

# Resources
Here are some links to additional learning resources:
* http://www.fpga4student.com/
* Datasheet for the BASYS2 board: https://reference.digilentinc.com/_media/basys2:basys2_rm.pdf

# Installation
This project assumes you're running on a Linux based system.
You need to install the Xilinx ISE Design Suite (version 14.7) from this link:
https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/design-tools.html
Don't bother with the cable drivers, they are not needed.
Instead, go to 

Please see the [Digilent's
website](http://store.digilentinc.com/digilent-adept-2-download-only/) to
download both the Runtime and the Utilities.

Alternatively, follow this guide: https://www.realdigital.org/document/44

