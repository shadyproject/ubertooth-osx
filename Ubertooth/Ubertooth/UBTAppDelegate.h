//
//  UBTAppDelegate.h
//  Ubertooth
//
//  Created by Christopher Martin on 4/6/14.
//  Copyright (c) 2014 shadyproject. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface UBTAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

-(void)findAttachedDevice;

@end
