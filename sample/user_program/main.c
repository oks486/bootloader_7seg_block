/* 
 * File:   main.c
 * Author: oaks@osk486
 *
 */

#include <pic.h>
#include <stdint.h>

#define CHECK_RECV (PIR1 & 0x20)    // RCIF

//#pragma config CPD=OFF, BOREN=OFF, IESO=OFF, FOSC=INTOSC, FCMEN=OFF, MCLRE=OFF, WDTE=OFF, CP=OFF, PWRTE=ON, PLLEN=OFF


void main(void)
{
    uint8_t data;
    uint8_t count = 0;


    // Clock
    OSCCON  = 0b01111000;       // IRCF(6-3) = 16MHz
    while(!(OSCSTAT & 0x01));   // wait

    // IO Port
    PORTA = 0b00111111;         // PORTA output data
    PORTC = 0b00111111;         // PORTC output data
    WPUA  = 0b00000100;         // pull-up (unused pin)

    ANSELA = 0b00000000;        // PORTA Analog input disable
    ANSELC = 0b00000000;        // PORTC Analog input disable

    TRISA = 0b00000110;         // PORTA direction
    TRISC = 0b00000000;         // PORTA direction

    // Port Fuction setting
    APFCON = 0b10000100;        // Tx=RA0, Rx=RA1

    // USART setting
    RCSTA   = 0b10010000;       // SPEN(7) = 1, CREN(4) = 1
    TXSTA   = 0b00100000;       // TXEN(5) = 1, SYNC(4) = 0

    //9600 boud
    BAUDCON = 0b00000000;
    SPBRGL  = 0x19;             // baudrate couneter

    //38400 baud
    //BAUDCON = 0b00000000;
    //TXSTA  |= 0b00000100;       // BRGH = 1
    //SPBRGL  = 0x19;             // baudrate couneter


    while(1)
    {
        if(CHECK_RECV) {
            data = RCREG;
            TXREG = data;

            switch(count % 6) {
                case 0:
                    PORTA=0b00110000;
                    PORTC=0b00011111;
                    break;
                case 1:
                    PORTA=0b00110000;
                    PORTC=0b00111110;
                    break;
                case 2:
                    PORTA=0b00110000;
                    PORTC=0b00111101;
                    break;
                case 3:
                    PORTA=0b00110000;
                    PORTC=0b00101111;
                    break;
                case 4:
                    PORTA=0b00110000;
                    PORTC=0b00110111;
                    break;
                case 5:
                    PORTA=0b00100000;
                    PORTC=0b00111111;
                    break;
                default:
                    PORTA=0b00110000;
                    PORTC=0b00111111;
                    break;
            }

            count++;
            if (count > 5) {
                count = 0;
            }

        }

    }

}
