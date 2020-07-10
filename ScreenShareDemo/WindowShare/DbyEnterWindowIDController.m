//
//  DbyEnterWindowIDController.m
//  ScreenShareDemo
//
//  Created by yxibng on 2020/7/8.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "DbyEnterWindowIDController.h"
#import "DbyWindowCaptureController.h"

@interface DbyEnterWindowIDController ()
@property (weak) IBOutlet NSTextField *windowIDInput;

@end

@implementation DbyEnterWindowIDController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.windowIDInput.stringValue = @"241393";
}
- (IBAction)displayPreview:(id)sender {
    
    NSString *wid = _windowIDInput.stringValue;
    
    if (!wid.length) {
        return;
    }
    
    CGWindowID windowId = [wid integerValue];
    NSStoryboard *storyBoard =  [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    DbyWindowCaptureController *viewcontroller = [storyBoard instantiateControllerWithIdentifier:@"DbyWindowCaptureController"];
    viewcontroller.windowID = windowId;
    NSWindow *window = [NSWindow windowWithContentViewController:viewcontroller];
    [window makeKeyAndOrderFront:nil];
    
}

@end
