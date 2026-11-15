#include "Hardware.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/storage/nvme/NVMeSMARTLibExternal.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>
#include <string.h>

// MARK: - HID thermal sensors (private IOKit symbols, stable since Apple Silicon launched)

typedef struct __IOHIDEvent *IOHIDEventRef;
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef matching);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

static const int64_t kTemperatureEventType = 15;
static const int32_t kTemperatureField = 15 << 16;

CFDictionaryRef PulsoCopyThermalSensors(const char *prefix, int limit) {
    static IOHIDEventSystemClientRef client = NULL;
    static CFArrayRef services = NULL;
    static CFMutableArrayRef names = NULL; // Names are fixed, so read them once.
    if (client == NULL) {
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (client == NULL) return NULL;
        int page = 0xff00, usage = 5;
        CFNumberRef pageNumber = CFNumberCreate(NULL, kCFNumberIntType, &page);
        CFNumberRef usageNumber = CFNumberCreate(NULL, kCFNumberIntType, &usage);
        const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
        const void *values[] = { pageNumber, usageNumber };
        CFDictionaryRef matching = CFDictionaryCreate(NULL, keys, values, 2,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        IOHIDEventSystemClientSetMatching(client, matching);
        CFRelease(matching);
        CFRelease(pageNumber);
        CFRelease(usageNumber);
        services = IOHIDEventSystemClientCopyServices(client);
        names = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
        for (CFIndex i = 0; services && i < CFArrayGetCount(services); i++) {
            IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
            CFTypeRef name = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
            if (name != NULL && CFGetTypeID(name) == CFStringGetTypeID()) {
                CFArrayAppendValue(names, name);
            } else {
                CFArrayAppendValue(names, CFSTR(""));
            }
            if (name != NULL) CFRelease(name);
        }
    }
    if (services == NULL) return NULL;

    CFStringRef prefixString = prefix ? CFStringCreateWithCString(NULL, prefix, kCFStringEncodingUTF8) : NULL;
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    int read = 0;
    for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
        CFStringRef name = CFArrayGetValueAtIndex(names, i);
        if (CFStringGetLength(name) == 0) continue;
        if (prefixString && !CFStringHasPrefix(name, prefixString)) continue;
        if (limit > 0 && read >= limit) break;
        read++;
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kTemperatureEventType, 0, 0);
        if (event == NULL) continue;
        double celsius = IOHIDEventGetFloatValue(event, kTemperatureField);
        // Uncalibrated sensors report negative or absurd values.
        if (celsius > 0 && celsius < 150) {
            CFNumberRef value = CFNumberCreate(NULL, kCFNumberDoubleType, &celsius);
            CFDictionarySetValue(result, name, value);
            CFRelease(value);
        }
        CFRelease(event);
    }
    if (prefixString) CFRelease(prefixString);
    return result;
}

// MARK: - NVMe SMART

bool PulsoReadNVMeSMART(PulsoSMART *out) {
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IONVMeBlockStorageDevice"), &iterator) != KERN_SUCCESS) {
        return false;
    }
    bool found = false;
    io_object_t service;
    while (!found && (service = IOIteratorNext(iterator))) {
        IOCFPlugInInterface **plugin = NULL;
        SInt32 score;
        if (IOCreatePlugInInterfaceForService(service, kIONVMeSMARTUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score) == KERN_SUCCESS && plugin) {
            IONVMeSMARTInterface **smart = NULL;
            (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIONVMeSMARTInterfaceID), (LPVOID *)&smart);
            if (smart) {
                NVMeSMARTData data;
                memset(&data, 0, sizeof(data));
                if ((*smart)->SMARTReadData(smart, &data) == kIOReturnSuccess) {
                    out->temperatureCelsius = (int)data.TEMPERATURE - 273; // Reported in Kelvin.
                    out->percentageUsed = data.PERCENTAGE_USED;
                    out->criticalWarning = data.CRITICAL_WARNING;
                    found = true;
                }
                (*smart)->Release(smart);
            }
            IODestroyPlugInInterface(plugin);
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    return found;
}

// MARK: - SMC (fans)

typedef struct { char major, minor, build, reserved; UInt16 release; } SMCVersion;
typedef struct { UInt16 version, length; UInt32 cpuPLimit, gpuPLimit, memPLimit; } SMCPLimitData;
typedef struct { UInt32 dataSize, dataType; char dataAttributes; } SMCKeyInfo;
typedef struct {
    UInt32 key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfo keyInfo;
    char result, status, data8;
    UInt32 data32;
    unsigned char bytes[32];
} SMCKeyData;

enum { kSMCHandleYPCEvent = 2, kSMCReadKey = 5, kSMCGetKeyInfo = 9 };

static io_connect_t SMCConnection(void) {
    static io_connect_t connection = 0;
    static bool attempted = false;
    if (!attempted) {
        attempted = true;
        io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
        if (service) {
            IOServiceOpen(service, mach_task_self(), 0, &connection);
            IOObjectRelease(service);
        }
    }
    return connection;
}

static UInt32 FourCC(const char *key) {
    return ((UInt32)key[0] << 24) | ((UInt32)key[1] << 16) | ((UInt32)key[2] << 8) | (UInt32)key[3];
}

static bool SMCRead(const char *key, SMCKeyData *output) {
    io_connect_t connection = SMCConnection();
    if (!connection) return false;
    SMCKeyData input;
    memset(&input, 0, sizeof(input));
    memset(output, 0, sizeof(*output));
    size_t size = sizeof(SMCKeyData);
    input.key = FourCC(key);
    input.data8 = kSMCGetKeyInfo;
    if (IOConnectCallStructMethod(connection, kSMCHandleYPCEvent, &input, sizeof(input), output, &size) != KERN_SUCCESS || output->result != 0) {
        return false;
    }
    SMCKeyInfo info = output->keyInfo;
    input.keyInfo.dataSize = info.dataSize;
    input.data8 = kSMCReadKey;
    memset(output, 0, sizeof(*output));
    if (IOConnectCallStructMethod(connection, kSMCHandleYPCEvent, &input, sizeof(input), output, &size) != KERN_SUCCESS || output->result != 0) {
        return false;
    }
    output->keyInfo = info;
    return true;
}

int PulsoFanCount(void) {
    SMCKeyData data;
    if (!SMCRead("FNum", &data)) return 0;
    return data.bytes[0];
}

double PulsoFanSpeed(int index) {
    char key[5];
    snprintf(key, sizeof(key), "F%dAc", index);
    SMCKeyData data;
    if (!SMCRead(key, &data)) return -1;
    if (data.keyInfo.dataType == FourCC("flt ")) {
        float value;
        memcpy(&value, data.bytes, sizeof(value));
        return value;
    }
    if (data.keyInfo.dataType == FourCC("fpe2")) {
        return (double)(((int)data.bytes[0] << 6) + ((int)data.bytes[1] >> 2));
    }
    return -1;
}

// MARK: - GPU

int PulsoGPUUtilization(void) {
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) != KERN_SUCCESS) {
        return -1;
    }
    int utilization = -1;
    io_object_t service;
    while ((service = IOIteratorNext(iterator))) {
        CFDictionaryRef stats = IORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"), NULL, 0);
        if (stats) {
            CFNumberRef value = CFDictionaryGetValue(stats, CFSTR("Device Utilization %"));
            int number;
            if (value && CFNumberGetValue(value, kCFNumberIntType, &number) && number > utilization) {
                utilization = number;
            }
            CFRelease(stats);
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    return utilization;
}

// MARK: - Disk I/O

bool PulsoDiskIOBytes(uint64_t *bytesRead, uint64_t *bytesWritten) {
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) != KERN_SUCCESS) {
        return false;
    }
    *bytesRead = 0;
    *bytesWritten = 0;
    io_object_t service;
    while ((service = IOIteratorNext(iterator))) {
        CFDictionaryRef stats = IORegistryEntryCreateCFProperty(service, CFSTR("Statistics"), NULL, 0);
        if (stats) {
            uint64_t value;
            CFNumberRef number = CFDictionaryGetValue(stats, CFSTR("Bytes (Read)"));
            if (number && CFNumberGetValue(number, kCFNumberSInt64Type, &value)) *bytesRead += value;
            number = CFDictionaryGetValue(stats, CFSTR("Bytes (Write)"));
            if (number && CFNumberGetValue(number, kCFNumberSInt64Type, &value)) *bytesWritten += value;
            CFRelease(stats);
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    return true;
}
