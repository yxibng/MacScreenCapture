//
//  DbyBufferVideoView.m
//  ScreenShareDemo
//
//  Created by yxibng on 2020/6/17.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "DbyBufferVideoView.h"
#import <AVFoundation/AVFoundation.h>

@interface DbyBufferVideoView ()
@property (nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;

@end

@implementation DbyBufferVideoView

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
    self.wantsLayer = true;
    self.layer = [[AVSampleBufferDisplayLayer alloc] init];
}


- (AVSampleBufferDisplayLayer *)displayLayer
{
    return (AVSampleBufferDisplayLayer *)self.layer;
}

#pragma mark -

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (!pixelBuffer) {
        return;
    }

    CVPixelBufferRetain(pixelBuffer);
    CMSampleBufferRef sampleBuffer = [self createSampleBufferWithPixelBuffer:pixelBuffer];
    CVPixelBufferRelease(pixelBuffer);

    if (!sampleBuffer) {
        return;
    }

    [self displaySampleBuffer:sampleBuffer];
    CFRelease(sampleBuffer);
}

- (CMSampleBufferRef)createSampleBufferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (!pixelBuffer) {
        return NULL;
    }

    //不设置具体时间信息
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    //获取视频信息
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    if (result != 0) {
        return NULL;
    }

    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(videoInfo);
    if (result != 0) {
        return NULL;
    }
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);

    return sampleBuffer;
}

- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (sampleBuffer == NULL) {
        return;
    }
    CFRetain(sampleBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            [self.displayLayer flush];
        }
        if (!self.window) {
            //如果当前视图不再window上，就不要显示了
            CFRelease(sampleBuffer);
            return;
        }

        if (self.displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            //此时无法将sampleBuffer加入队列，强行往队列里面添加，会造成崩溃
            NSError *error = self.displayLayer.error;
            NSLog(@"%s, error = %@",__FUNCTION__, error);
            CFRelease(sampleBuffer);
            return;
        }

        [self.displayLayer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}




@end
