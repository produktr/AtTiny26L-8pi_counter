# AtTiny26L-8pi_counter

Hand held device with display to count button presses. It uses buttons to detect user input one +1 and one for -1.  
Made with of the shelf components.  

For me this is a exploration in programming ASM assembly as I had never done this before.  
Also the designing was interesting.  

## Components

### The ATTiny microcontroller
As I had a `ATTiny26L` 8-bit microcontroller laying around I decided to use that. As it already has an onboard clock which is plenty
fast enough for this simple project it saved me from connection a XTAL.  

```
Ttiny26
     _____________________________________
  1 /                                     |20
o--|PB0 /OC1A SDA DI MOSI         PA0 ADC0|--o
  2|                                      |19
o--|PB1 OC1A DO MISO              PA1 ADC1|--o
  3|                                      |18
o--|PB2 /OC1B SCL SCK             PA2 ADC2|--o
  4|                                      |17
o--|PB3 OC1B                      PA3 AREF|--o
  5|                                      |16
o--|VCC                                GND|--o
  6|                                      |15
o--|GND                               AVCC|--o
  7|                                      |14
o--|PB4 XTAL1 ADC7                PA4 ADC3|--o
  8|                                      |13
o--|PB5 XTAL2 ADC8                PA5 ADC4|--o
  9|                                      |12
o--|PB6 T0 INT0 ADC9         PA6 ADC5 AIN0|--o
 10|                                      |11
o--|PB7 RESET ADC10          PA7 ADC6 AIN1|--o
   |______________________________________|
```

### The shift register
As the ATTiny doesn't have enough outputs do drive a 7-segment display we need a shift register. I used a `74HCT595N` as again this what I had on hand.

```
74HCT595N
     _____________________________________
  1 /                                     |16
o--|Q1                                 VCC|--o
  2|                                      |15
o--|Q2                                  Q0|--o
  3|                                      |14
o--|Q3                                  DS|--o
  4|                                      |13
o--|Q4                                 ~OE|--o
  5|                                      |12
o--|Q5                                STCP|--o
  6|                                      |11
o--|Q6                                SHCP|--o
  7|                                      |10
o--|Q7                                 ~MR|--o
  8|                                      |9
o--|GND                                Q7S|--o
   |______________________________________|
```

### Something to read the number
A 7-segment display sporting 4 digits is used for outputting the number to the user. I used a `CL5642BH-30` as you guessed it already, was the one I had laying around.

```
CL5642BH-30

       DIG1    A       F      DIG2     DIG3    B
        o12    o11     o10     o9      o8      o7
        |      |       |       |       |       |
    ----|------|-------|-------|-------|-------|----
   |                                                |
   |                                                |
   |                                                |
   |                                                |
    ----|------|-------|-------|-------|-------|----
        |      |       |       |       |       |
        o1     o2      o3      o4      o5      o6
        E      D       :       C       G      DIG4


	--a--
	f   b
	--g--
	e   c
	--d--

1 = no path to ground
0 = path to ground

    | b | a | f | e | d | c | g | ; |
MSB | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | LSB
 1  | 0 | 1 | 1 | 1 | 1 | 0 | 1 | 1 |
 2  | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 1 |
 3  | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 1 |
 4  | 0 | 1 | 0 | 1 | 1 | 0 | 0 | 1 |
 5  | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 1 |
 6  | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
 7  | 0 | 0 | 1 | 1 | 1 | 0 | 1 | 1 |
 8  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
 9  | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 |
 0  | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 |
```

### Other components
Something to mount it all on, for this perfboard was used.  
As I use a 9v battery a 5 volt regulator was used.  
2 buttons to read the user input.  
A 3d printed case.  
Supporting electronics like condensators and current resisters as pull-up/down and current limiting.  
