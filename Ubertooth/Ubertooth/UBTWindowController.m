//
//  UBTWindowController.m
//  Ubertooth
//
//  Created by Christopher Martin on 7/1/15.
//  Copyright (c) 2015 shadyproject. All rights reserved.
//

#import "UBTWindowController.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/IOUSBUserClient.h>

@interface UBTWindowController ()

@property (nonatomic, weak) IBOutlet NSTextField *deviceConnectedField;
@property (nonatomic, weak) IBOutlet NSTextField *firmwareRevisionField;
@property (nonatomic, weak) IBOutlet NSButton *refreshButton;

@property (nonatomic, strong) NSDictionary* deviceIds;

@end

@implementation UBTWindowController

- (instancetype)init {
    return [super initWithWindowNibName:@"UBTWindowController"];
}

- (instancetype) initWithWindowNibName:(NSString *)windowNibName {
    NSLog(@"External clients are not allowed to call -[%@ initWithWindowNibName] directly", [self class]);
    [self doesNotRecognizeSelector:_cmd];
    
    return nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Devices" ofType:@"plist"];
    self.deviceIds = [NSDictionary dictionaryWithContentsOfFile: path];
}

#pragma mark - IBActions
- (IBAction)searchForDevice:(id)sender{
    self.refreshButton.enabled = NO;
    
    [self findAttachedDevice];
    
    self.refreshButton.enabled = YES;
}

-(void)findAttachedDevice {
    __block io_iterator_t iterator = 0;
    __block io_service_t usbDeviceRef = 0;
    
    __block UInt16 foundVendor;
    __block UInt16 foundProduct;
    
    [self.deviceIds enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        
        NSLog(@"Searching for %@", key);
        NSDictionary *ids = obj;
        
        NSInteger vendorId = [ids[@"VendorID"] integerValue];
        NSInteger productId = [ids[@"ProductID"] integerValue];
        
        CFNumberRef vId = CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &vendorId);
        CFNumberRef pId = CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &productId);
        
        CFDictionaryAddValue(matchingDict, CFSTR(kUSBVendorID), vId);
        CFDictionaryAddValue(matchingDict, CFSTR(kUSBProductID), pId);
        
        IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator);
        
        //TODO: iterate over this to find multiple connected ubertooths
        usbDeviceRef =  IOIteratorNext(iterator);
        
        if (usbDeviceRef == 0) {
            NSLog(@"Could not find %@", key);
        } else {
            NSLog(@"Found %@", key);
            self.firmwareRevisionField.hidden = NO;
            self.deviceConnectedField.stringValue = [NSString stringWithFormat:@"%@ connected.", key];
            *stop = YES;
            
            CFNumberGetValue(vId, kCFNumberSInt16Type, &foundVendor);
            CFNumberGetValue(pId, kCFNumberSInt16Type, &foundProduct);
        }
    }];
    
    if (!usbDeviceRef) {
        return;
    }
    
    kern_return_t kr;
    IOCFPlugInInterface **pluginInterface = NULL;
    IOUSBDeviceInterface **ubertooth = NULL;
    HRESULT result;
    SInt32 score;
    
    kr = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score);
    //we don't need the device ref after we have the plugin
    kr = IOObjectRelease(usbDeviceRef);
    
    if (kIOReturnSuccess != kr || !pluginInterface) {
        self.deviceConnectedField.stringValue = [NSString stringWithFormat:@"Couldn't create a device plugin: (%08x)", kr];
    }
    
    //grab the device interface
    result = (*pluginInterface)->QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID*)&ubertooth);
    
    //once we have the device interface, we can free the plugin
    (*pluginInterface)->Release(pluginInterface);
    
    if (result || !ubertooth) {
        self.deviceConnectedField.stringValue = [NSString stringWithFormat:@"Couldn't create device interface: (%08x)", (int)result];
    }
    
    UInt16 vendor, product, release;
    
    kr = (*ubertooth)->GetDeviceVendor(ubertooth, &vendor);
    kr = (*ubertooth)->GetDeviceProduct(ubertooth, &product);
    kr = (*ubertooth)->GetDeviceReleaseNumber(ubertooth, &release);
    
    if (vendor != foundVendor || product != foundProduct) {
        self.deviceConnectedField.stringValue = @"Got device, but doesn't look like ubertooth";
        return;
    }
    
    //open the device
    kr = (*ubertooth)->USBDeviceOpen(ubertooth);
    if (kIOReturnSuccess != kr) {
        self.deviceConnectedField.stringValue = @"Could not open device";
        return;
    }
    
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
    
    kr = (*ubertooth)->DeviceRequest(ubertooth, &firmwareRevReq);
    
    if (kIOReturnSuccess != kr) {
        self.firmwareRevisionField.stringValue = @"Firmware Revision: Unknown";
        return;
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
    self.firmwareRevisionField.stringValue = [NSString stringWithFormat:@"Firmware Revision: %@", displayRevision];
}

@end
