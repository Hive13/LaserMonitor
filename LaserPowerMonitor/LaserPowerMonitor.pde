#include <EEPROM.h>
#include "EEPROMAnything.h"
#include <LiquidCrystal.h>
#include <stdio.h>

/*
 This sketch shows two timers. One is user resettable and one is not. 
 The timers keep track of how long an analog input goes past a threshold.
 The smallest increment is one minute. If the threshold is exceeded for 
 any point in a minute (even less than a second) that minute is counted 
 towards the time.
 
  The circuit:
 * LCD RS pin to digital pin 12
 * LCD Enable pin to digital pin 11
 * LCD D4 pin to digital pin 5
 * LCD D5 pin to digital pin 4
 * LCD D6 pin to digital pin 3
 * LCD D7 pin to digital pin 2
 * LCD R/W pin to ground
 * 10K resistor:
 * ends to +5V and ground
 * wiper to LCD VO pin (pin 3)
 *
 * Analog input for thresholding analog in pin 0
 * button input for reset digital pin 1
 */

#define MAX_OUT_CHARS 16  //max nbr of characters to be sent on any one serial command

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

const long second = 1000;
const long minute = 60000;    // number of millis in a minute
const long hour = 3600000;    // number of millis in an hour

int userResetPin = 13;        // pin used for resetting user laser time
int analogPin = 0;           // light sensor input (or voltsge) connected to analog pin 0
int analogVal = 0;           // variable to store the value read
int anaLowThreshold = 1000;   // if analog value rises above this value its considered ON
int anaHighThreshold = 1010;  // if analog value falls below this value its considered OFF
int cursorPos = 0;
long millisOnLast = 0;
long millisOffLast = 0;
long millisTemp = 0;
long millisDiff = 0;
boolean lastLaserOn = false;
long userMillis = 0;
int userHours = 0;
int userMinutes = 0;        // number of minutes user has used the laser (resettable when button pressed)
int userSeconds = 0;
int tubeHours = 0;
int tubeMinutes = 0;        // number of minutes tube has been used (not resettable)
int tubeSeconds = 0;
long tubeMillis = 0;        

char   buffer[MAX_OUT_CHARS];  //buffer used to format a line (+1 is for trailing 0)
char   buffer2[MAX_OUT_CHARS];  //buffer used to format a line (+1 is for trailing 0)

struct config_t
{
    long seconds;
    long uSeconds;
} laserTime;

void setup() {
    pinMode(userResetPin, INPUT); 
  Serial.begin(9600);
  EEPROM_readAnything(0, laserTime);
  tubeMillis = laserTime.seconds*1000;
  userMillis = laserTime.uSeconds*1000;
  
  // set up the LCD's number of columns and rows: 
  lcd.begin(16, 2);
  // Print a message to the LCD.
  Serial.println("setup");
  lcd.println("T:00000:00:00   ");
  lcd.print("U:00:00:00");
}

void loop() {
  // do a tight loop on checking the laser and keeping track of on/off times
  for (int i=0; i <= 100; i++) {
    analogVal = analogRead(analogPin);    // read the input pin
//    Serial.print("anaVal:");
//    Serial.println(analogVal);
    if (analogVal <  anaLowThreshold) {
      lastLaserOn = true;

      millisTemp = (long) millis();
      millisDiff = millisTemp-millisOnLast;
      millisOnLast = millisTemp;
    }
    if (analogVal > anaHighThreshold) {
      lastLaserOn = false;
      millisOffLast = (long) millis();
    }
    int userReset = digitalRead(userResetPin);
    if (userReset == HIGH) {
//      Serial.println("User reset");
      userMillis = 0;
    }
      userMillis = userMillis + millisDiff;
      tubeMillis = tubeMillis + millisDiff;
      millisDiff = 0;
  }

  // set the cursor to column 12, line 1
  // (note: line 1 is the second row, since counting begins with 0):
  tubeHours = tubeMillis/hour;
  tubeMinutes = (tubeMillis-tubeHours*hour)/minute;
  tubeSeconds = (tubeMillis-tubeHours*hour-tubeMinutes*minute)/second;
  userHours = userMillis/hour;
  userMinutes = (userMillis-userHours*hour)/minute;
  userSeconds = (userMillis-userHours*hour-userMinutes*minute)/second;
  sprintf(buffer,"T:%05d:%02d:%02d", tubeHours,  tubeMinutes, tubeSeconds);
  sprintf(buffer2,"U:%02d:%02d:%02d", userHours,  userMinutes, userSeconds);

  // Only write to EEPROM if the current value is more than 5 minutes from the previous EEPROM value
  // to reduce the number of writes to EEPROM, since it is only good for 100,000 writes
  EEPROM_readAnything(0, laserTime);
  long laserSeconds = laserTime.seconds;
  if ((laserSeconds+300) < (tubeMillis/1000)) {    
    Serial.print("LaserSeconds:");
    Serial.print(laserSeconds);
    Serial.print("adjTubeSecs:");
    Serial.println(((tubeMillis/1000)+300));
    laserTime.seconds = tubeMillis/1000;
    laserTime.uSeconds = userMillis/1000;
    EEPROM_writeAnything(0, laserTime);
    Serial.println("Wrote to EEPROM");
  }  
  lcd.setCursor(0,0);
  lcd.print(buffer);
//  Serial.println(buffer);
  lcd.setCursor(0,1);
  lcd.print(buffer2);
//  Serial.println(buffer2);

}

