//
//  DbyPreviewVideoView.m
//  DbyPaasMultiStream
//
//  Created by yxibng on 2020/6/15.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "DbyPreviewVideoView.h"


@interface DbyPreviewVideoView ()
@property (nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;
@end


@implementation DbyPreviewVideoView



- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self setup];
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.wantsLayer = YES;
    self.layer = [[AVCaptureVideoPreviewLayer alloc] init];
}

- (void)setSession:(AVCaptureSession *)session
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *)self.layer;
        layer.session = session;
    });
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end
