/*
;    Project:       Open Vehicle Monitor System
;    Date:          14th March 2017
;
;    OVMS Changes:
;    1.0  Initial release
;
;    (C) 2011       Michael Stegen / Stegen Electronics
;    (C) 2011-2017  Mark Webb-Johnson
;    (C) 2011        Sonny Chen @ EPRO/DX
;
;    BMW I3 component:
;    Developed by Stephen Davies <steve@telviva.co.za>
;
;    2020-12-12     0.0       Work started
;
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.
*/

#ifndef __VEHICLE_BMWI3_H__
#define __VEHICLE_BMWI3_H__

#include "vehicle.h"

using namespace std;

// rxbuff access macros: b=byte# 0..7 / n=nibble# 0..15
#define RXBUF_BYTE(b)     rxbuf[b]
#define RXBUF_UINT(b)     (((UINT)RXBUF_BYTE(b) << 8) | RXBUF_BYTE(b+1))
#define RXBUF_SINT(b)     (((short)(RXBUF_BYTE(b) << 8)) | RXBUF_BYTE(b+1))
#define RXBUF_UINT24(b)   (((uint32_t)RXBUF_BYTE(b) << 16) | ((UINT)RXBUF_BYTE(b+1) << 8) | RXBUF_BYTE(b+2))
#define RXBUF_UINT32(b)   (((uint32_t)RXBUF_BYTE(b) << 24) | ((uint32_t)RXBUF_BYTE(b+1) << 16)  | ((UINT)RXBUF_BYTE(b+2) << 8) | RXBUF_BYTE(b+3))
#define RXBUF_NIBL(b)     (rxbuff[b] & 0x0f)
#define RXBUF_NIBH(b)     (rxbuff[b] >> 4)
#define RXBUF_NIB(n)      (((n)&1) ? RXBUF_NIBL((n)>>1) : RXBUF_NIBH((n)>>1))


#define POLLSTATE_OFF		  PollSetState(0)
#define POLLSTATE_ON		  PollSetState(1)
#define POLLSTATE_RUNNING	  PollSetState(2)
#define POLLSTATE_CHARGING	  PollSetState(3)


class OvmsVehicleBMWi3 : public OvmsVehicle
  {
  public:
    OvmsVehicleBMWi3();
    ~OvmsVehicleBMWi3();

  protected:
    string bmwi3_obd_rxbuf;
    void IncomingPollReply(canbus* bus, uint16_t type, uint16_t pid, uint8_t* data, uint8_t length, uint16_t mlremain);
  };

#endif //#ifndef __VEHICLE_BMWI3_H__
