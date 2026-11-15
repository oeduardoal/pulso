#ifndef PULSO_HARDWARE_H
#define PULSO_HARDWARE_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

/// Readings that have no Swift-friendly public API. Every function is safe to call on
/// hardware that lacks the sensor and returns false or an empty result instead.

/// Temperature sensors exposed through the HID event system on Apple Silicon.
/// Returns a dictionary of sensor name to degrees Celsius (CFNumber), or NULL. Caller releases.
/// `prefix` limits the read to sensors whose name starts with it (NULL reads all), and `limit`
/// caps how many are read (0 for no cap). Each read costs about half a millisecond.
CFDictionaryRef _Nullable PulsoCopyThermalSensors(const char * _Nullable prefix, int limit);

typedef struct {
    int temperatureCelsius;
    int percentageUsed;
    int criticalWarning;
} PulsoSMART;

/// Reads the NVMe SMART log of the first internal NVMe drive.
bool PulsoReadNVMeSMART(PulsoSMART * _Nonnull out);

/// Number of fans reported by the SMC, 0 on fanless Macs.
int PulsoFanCount(void);

/// Current speed of fan `index` in RPM, or -1 when unavailable.
double PulsoFanSpeed(int index);

/// GPU utilization in percent from the IOAccelerator statistics, or -1.
int PulsoGPUUtilization(void);

/// Total bytes read and written by all block storage drivers since boot.
bool PulsoDiskIOBytes(uint64_t * _Nonnull bytesRead, uint64_t * _Nonnull bytesWritten);

#endif
