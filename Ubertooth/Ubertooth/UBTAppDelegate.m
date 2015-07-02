//
//  UBTAppDelegate.m
//  Ubertooth
//
//  Created by Christopher Martin on 4/6/14.
//  Copyright (c) 2014 shadyproject. All rights reserved.
//

#import "UBTAppDelegate.h"
#import "UBTWindowController.h"

@interface UBTAppDelegate ()

@property (nonatomic, strong) UBTWindowController *controller;

@end

@implementation UBTAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.controller = [[UBTWindowController alloc] init];
    [self.controller showWindow:nil]; //might want to pass ourself in 
}

-(void)findAttachedDevice{
    
}



@end
