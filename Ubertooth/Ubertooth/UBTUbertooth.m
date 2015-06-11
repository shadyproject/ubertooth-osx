//
//  UBTUbertooth.m
//  Ubertooth
//
//  Created by Christopher Martin on 4/27/14.
//  Copyright (c) 2014 shadyproject. All rights reserved.
//

#import "UBTUbertooth.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/IOUSBUserClient.h>

@implementation UBTUbertooth {
    IOUSBDeviceInterface **ubertooth;
}

+ (instancetype)findWithVendorId:(NSNumber*)vendorId andProductId:(NSNumber*)productId {
    NSMutableDictionary *matchingDict = [NSMutableDictionary dictionary];
    
    matchingDict[@kUSBVendorID] = vendorId;
    matchingDict[@kUSBProductID] = productId;
    
    io_iterator_t iterator = 0;
    io_service_t usbDevice = 0;
    
    IOServiceGetMatchingServices(kIOMasterPortDefault, (__bridge CFDictionaryRef)(matchingDict), &iterator);
    
    usbDevice = IOIteratorNext(iterator);
    
    if (usbDevice == 0) {
        return nil;
    } else {
        kern_return_t kr;
        IOCFPlugInInterface **pluginInterface = NULL;
        IOUSBDeviceInterface **ubertoothInterface = NULL;
        HRESULT result;
        SInt32 score;
        
        kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score);
        kr = IOObjectRelease(usbDevice);
        
        result = (*pluginInterface)->QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID*)&ubertoothInterface);
        (*pluginInterface)->Release(pluginInterface);
        
        //TODO: we might want to check vendor ID and such here to verify we have a correct device
        
        UBTUbertooth *ubertooth = [[UBTUbertooth alloc] initWithDeviceInterface:*ubertoothInterface];
        return ubertooth;
    }
}

-(instancetype)initWithDeviceInterface:(IOUSBDeviceInterface*)interface {
    
    if ((self = [super init])) {
        ubertooth = &interface;
        kern_return_t kr = (*ubertooth)->USBDeviceOpen(ubertooth);
        if (kIOReturnSuccess != kr) {
            NSLog(@"WARNING>>Could not open USB Device");
        }
    }
    
    return self;
}

-(void)dealloc{
    CFRelease(ubertooth);
}

- (NSString*)firmwareRevision{
   
    //get the firmware revision
    UInt8 cmdResult[2 + 1 + 255];
    UInt16 resultVersion;
    char version[100];
    
    IOUSBDevRequest firmwareRevReq;
    firmwareRevReq.bmRequestType = USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice);
    firmwareRevReq.bRequest = 33; //UBERTOOTH_GET_REV_NUM
    firmwareRevReq.wValue = 0;
    firmwareRevReq.wIndex = 0;
    firmwareRevReq.pData = cmdResult;
    firmwareRevReq.wLength = sizeof(cmdResult);
    
    kern_return_t kr = (*ubertooth)->DeviceRequest(ubertooth, &firmwareRevReq);
    if (kIOReturnSuccess != kr) {
        return @"Unknown";
    }
    
    resultVersion = cmdResult[0] | (cmdResult[1] << 8);
    if (firmwareRevReq.wLenDone == 2) {
        //old style svn rev
        sprintf(version, "%u", resultVersion);
    } else {
        UInt8 len = MIN(firmwareRevReq.wLenDone - 3, MIN(sizeof(cmdResult) - 1, cmdResult[2]));
        memcpy(version, &cmdResult[3], len);
        version[len] = '\0';
    }
    
    NSString *displayRevision = [NSString stringWithCString:version encoding:NSUTF8StringEncoding];
    return displayRevision;
}

-(void)flashLEDs {
    
}

@end
