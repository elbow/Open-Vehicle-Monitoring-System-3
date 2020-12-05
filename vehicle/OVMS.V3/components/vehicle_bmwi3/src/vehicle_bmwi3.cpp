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
;    2020	    BMWi3 support: Stephen Davies
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

OvmsVehicleBMWi3::OvmsVehicleBMWi3()
  {
  ESP_LOGI(TAG, "Generic BMW i3/i3s vehicle module");
  }

OvmsVehicleBMWi3::~OvmsVehicleBMWi3()
  {
  ESP_LOGI(TAG, "Shutdown BMW i3/i3s vehicle module");
  }

class OvmsVehicleBMWi3Init
  {
  public: OvmsVehicleBMWi3Init();
} MyOvmsVehicleBMWi3Init  __attribute__ ((init_priority (9000)));

OvmsVehicleBMWi3Init::OvmsVehicleBMWi3Init()
  {
  ESP_LOGI(TAG, "Registering Vehicle: BMW i3 (9000)");

  MyVehicleFactory.RegisterVehicle<OvmsVehicleBMWi3>("BMWI3","BMW i3, i3s");
  }

