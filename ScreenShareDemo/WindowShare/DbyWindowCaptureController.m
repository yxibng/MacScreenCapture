//
//  DbyWindowCaptureController.m
//  ScreenShareDemo
//
//  Created by yxibng on 2020/6/17.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "DbyWindowCaptureController.h"
#import "DbyBufferVideoView.h"

#import "libyuv.h"



@import CoreServices; // or `@import CoreServices;` on Mac
@import ImageIO;

#define kFrameRate 15


@interface DbyWindowCaptureController ()

@property (weak) IBOutlet DbyBufferVideoView *videoView;
@property (nonatomic) dispatch_source_t timer;
@property (nonatomic) dispatch_queue_t taskQueue;
@property (nonatomic) CGWindowID windowID;
@end

@implementation DbyWindowCaptureController

- (void)viewDidLoad {
    [super viewDidLoad];
    _taskQueue = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL);
    _windowID = kCGNullWindowID;
    _windowID = 265205;
    [self startTimer];
}


- (void)start
{
    [self startTimer];
}

- (void)stop
{
    [self stopTimer];
}



- (void)startTimer
{
    [self stopTimer];
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.taskQueue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 / kFrameRate * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        [self captureWindowImageFrame];
    });
    dispatch_resume(timer);
    _timer = timer;
}

- (void)stopTimer
{
    if (_timer) {
        dispatch_source_cancel(_timer);
    }
    _timer = NULL;
}

- (void)captureWindowImageFrame
{
    CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, self.windowID, kCGWindowImageDefault);
    
    if (!windowImage) {
        return;
    }
    
    CVPixelBufferRef buffer = [self pixelBufferFromCGImage:windowImage];
    [self.videoView displayPixelBuffer:buffer];
    CVPixelBufferRelease(buffer);
    CFRelease(windowImage);
}


- (void)writeImageWithIndex:(NSInteger)index image:(CGImageRef)image
{
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSLog(@"%@",path);
    path = [path stringByAppendingFormat:@"/%ld.png", (long)index];
    CGImageWriteToFile(image, path);

}



BOOL CGImageWriteToFile(CGImageRef image, NSString *path) {
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    if (!destination) {
        NSLog(@"Failed to create CGImageDestination for %@", path);
        return NO;
    }

    CGImageDestinationAddImage(destination, image, nil);

    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to write image to %@", path);
        CFRelease(destination);
        return NO;
    }

    CFRelease(destination);
    return YES;
}



- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    NSCParameterAssert(NULL != image);
    size_t originalWidth = CGImageGetWidth(image);
    size_t originalHeight = CGImageGetHeight(image);
    
    size_t bytePerRow = CGImageGetBytesPerRow(image);
    CFDataRef data  = CGDataProviderCopyData(CGImageGetDataProvider(image));
    const UInt8 *ptr =  CFDataGetBytePtr(data);
    
    //create rgb buffer
    NSDictionary *att = @{(NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{} };
    
    CVPixelBufferRef buffer;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                 originalWidth,
                                 originalHeight,
                                 kCVPixelFormatType_32BGRA,
                                 (void *)ptr,
                                 bytePerRow,
                                 _CVPixelBufferReleaseBytesCallback,
                                 (void *)data,
                                 (__bridge CFDictionaryRef _Nullable)att,
                                 &buffer);
    return buffer;
    
    
    
    
     CVPixelBufferRef i420Buffer;
    
    CVPixelBufferCreate(kCFAllocatorDefault, originalWidth, originalHeight, kCVPixelFormatType_420YpCbCr8Planar, (__bridge CFDictionaryRef _Nullable)att,&i420Buffer);
    
    
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    CVPixelBufferLockBaseAddress(i420Buffer, 0);
    
    
    
    
    void *y_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 0);
    void *u_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 1);
    void *v_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 2);

    
    int stride_y = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 0);
    int stride_u = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 1);
    int stride_v = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 2);
    
    
    void *rgb = CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    void *rgb_stride = CVPixelBufferGetBytesPerRow(buffer);
    
    
    BGRAToI420(rgb, rgb_stride,
               y_frame, stride_y,
               u_frame, stride_u,
               v_frame, stride_v,
               originalWidth, originalHeight);
    
    CVPixelBufferUnlockBaseAddress(i420Buffer, 0);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CVPixelBufferRelease(buffer);
    
    return  i420Buffer;
}

void _CVPixelBufferReleaseBytesCallback(void *releaseRefCon, const void *baseAddress) {
    
    CFDataRef data = releaseRefCon;
    CFRelease(data);
    
}


@end
