//
//  UBTUbertooth.h
//  Ubertooth
//
//  Created by Christopher Martin on 4/27/14.
//  Copyright (c) 2014 shadyproject. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UBTUbertooth : NSObject

@property (nonatomic, readonly) NSNumber* productId;
@property (nonatomic, readonly) NSNumber* vendorId;

+(instancetype)findWithVendorId:(NSNumber*)vendorId andProductId:(NSNumber*)productId;

-(NSString*)firmwareRevision;

-(void)flashLEDs;

@end
