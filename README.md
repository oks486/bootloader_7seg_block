7seg-block Bootloader Firmware
=========

"7seg-block" is a 7 segment LED module which equipped with a PIC microcontroller board in the rear, and is able to communicate other modules by asynchronous serial communication. This is firmware of the microcontroller.

The video of prototype of 7seg-block.  
http://youtu.be/Mvtl1LaF3zc


Features
--------------

This firmware has three kind of features below.

### Normal Operation ###

This is the default state when the module is supplied power. When the module receives ASCII data from '0' to '9', 'A' to 'F', 'a' to 'f', and store it once. After that module receives "delimiter code", then display data which has stored.

For example, There are three modules which are connected tandemly. Each module has RX pin on the right side, and TX pin on the left side. The serial data are input to a module of the right-side end, and transmitted in turn to the left-side end.

Then, serial data '1','2','3' are input in order to the right module. Each module store the data '1', '2' or '3' from the left module, and do not display yet. The stored data are displayed to the LED when delimiter code is received next. The stored data cleared after displaying. The delimiter code is transmitted to neighbor module immediately without being stored, therefore each module seemed to turn on simultaneously.

There is "newline code" turning off and clearing stored data all modules, elsewhere. 
It is transmitted in the same way as delimiter code.

Delimiter cord and the newline cord are able to set optionally value.


### User Program Writing ###

When the normal operation, the microcontroller can be written the user program by sending a special command.

The module enter the User Program Write mode, 'g' segment of LED turn on. Sending the user program in intel HEX format to the module, it is written in the program memory. And program writing is finished, LED turn off by executing software reset of microcontroller. If error occurred, it turn on all segment of LED and halt, until the module is power off.

It is also possible to be rewritten all at once while a plurality of modules connecting.


### User Program Execution ###

When the normal operation, the microcontroller can be running the user program by sending a special command.

Reset is not carried out then and only jumps to the start address of the user program.
This means that register setting remains the state of the normal operation.


Sample code
--------------

sample/bootloader_test/bootloader_test.ino  
Arduino sketch of user program writing and running.

sample/user_program/main.c  
User program sample. C program of PIC XC8.

