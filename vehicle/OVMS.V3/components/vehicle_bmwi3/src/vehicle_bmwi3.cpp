/*
;    Project:       Open Vehicle Monitor System
;    Date:          14th March 2017
;
;    Changes:
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

#include "ovms_log.h"
static const char *TAG = "v-bmwi3";

#include <stdio.h>
#include "vehicle_bmwi3.h"

#define BMWI3_ECU_SME                                     0x607   // "Battery Management Electronics"

#define BMWI3_PID_SME_ABSOLUTE_SOC                        0xDDBC  // Absolute SOC values (current/max/min)
#define BMWI3_PID_SME_HV_VOLTAGE                          0xDD68  // HV pack voltage (whether contactor closed or not)



static const OvmsVehicle::poll_pid_t obdii_polls[] = {
  // TXMODULEID, RXMODULEID, TYPE, PID, { POLLTIMES }, BUS
  { 0x6f1, BMWI3_ECU_SME, VEHICLE_POLL_TYPE_OBDIIEXTENDED, BMWI3_PID_SME_ABSOLUTE_SOC, {  60, 60, 60 }, 0 }, // SOC
  { 0x6f1, BMWI3_ECU_SME, VEHICLE_POLL_TYPE_OBDIIEXTENDED, BMWI3_PID_SME_HV_VOLTAGE,   {  60, 60, 60 }, 0 }, // Volts
  { 0, 0, 0x00, 0x00, { 0, 0, 0 }, 0 }
};

OvmsVehicleBMWi3::OvmsVehicleBMWi3()
{
  ESP_LOGI(TAG, "BMW i3/i3s vehicle module");
  // Get the Canbus running
  RegisterCanBus(1,CAN_MODE_ACTIVE,CAN_SPEED_500KBPS);
  PollSetPidList(m_can1, obdii_polls);
  PollSetState(0);
  
}

OvmsVehicleBMWi3::~OvmsVehicleBMWi3()
{
  ESP_LOGI(TAG, "Shutdown BMW i3/i3s vehicle module");
}

void OvmsVehicleBMWi3::IncomingPollReply(canbus* bus, uint16_t type, uint16_t pid, uint8_t* data, uint8_t length, uint16_t mlremain)
{
  string& rxbuf = bmwi3_obd_rxbuf;

  // Assemble first and following frames to get complete reply
  
  // init rx buffer on first (it tells us whole length)
  if (m_poll_ml_frame == 0) {
    rxbuf.clear();
    rxbuf.reserve(length + mlremain);
  }
  // Append each piece
  rxbuf.append((char*)data, length);
  if (mlremain) {
    // we need more - return for now.
    return;
  }
  
  // We now have received the whole reply - lets mine our nuggets!
  switch (pid) {

  case BMWI3_PID_SME_ANZEIGE_SOC: {
    unsigned int soc_raw = ((unsigned int)rxbuf[0] << 8) | (unsigned int)rxbuf[1];
    float soc = soc_raw / 10.0f;
    StdMetrics.ms_v_bat_soc->SetValue(soc);
    ESP_LOGD(TAG, "BMWI3: got SOC=%3.1f%%", soc);
    break;
  }

  case 0xdd68: {
    unsigned int volts_raw = ((unsigned int)rxbuf[0] << 8) | (unsigned int)rxbuf[1];
    float volts = volts_raw / 100.0f;
    StdMetrics.ms_v_bat_voltage->SetValue(volts);
    ESP_LOGD(TAG, "BMWI3: got Volts=%3.2f%%", volts);
    break;
  }

  // Unknown: output
  default: {
    char *buf = NULL;
    size_t rlen = rxbuf.size(), offset = 0;
    do {
      rlen = FormatHexDump(&buf, rxbuf.data() + offset, rlen, 16);
      offset += 16;
      ESP_LOGW(TAG, "BMWI3: unhandled reply [%02x %02x]: %s", type, pid, buf ? buf : "-");
    } while (rlen);
    if (buf)
      free(buf);
    break;
  }
  } /* switch */
}

class OvmsVehicleBMWi3Init
{
  public: OvmsVehicleBMWi3Init();
}
MyOvmsVehicleBMWi3Init  __attribute__ ((init_priority (9000)));

OvmsVehicleBMWi3Init::OvmsVehicleBMWi3Init()
{
  ESP_LOGI(TAG, "Registering Vehicle: BMW i3 (9000)");

  MyVehicleFactory.RegisterVehicle<OvmsVehicleBMWi3>("I3", "BMW i3, i3s");
}

