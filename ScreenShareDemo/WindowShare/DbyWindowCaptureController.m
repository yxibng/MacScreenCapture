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
    _windowID = 269343;
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
    
    //取得窗口快照
    CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, self.windowID, kCGWindowImageDefault);
    if (!windowImage) {
        return;
    }
    
//    //追加光标， 参考 https://www.coder.work/article/1297008
//    CGImageRef imagWithCursor = [self appendMouseCursor:windowImage];
//    CFRelease(windowImage);
//    if (!imagWithCursor) {
//        return;
//    }
//
    
    //做裁切
    CGImageRef croppedImage = CGImageCreateWithImageInRect(windowImage, CGRectInfinite);
    CFRelease(windowImage);
    if (!croppedImage) {
        return;
    }
    
//    //写文件
//    static int index = 0;
//    [self writeImageWithIndex:index image:croppedImage];
//    index++;
    
    
    //转化为 buffer 并展示
    CVPixelBufferRef buffer = [self pixelBufferFromCGImage:croppedImage];
    [self.videoView displayPixelBuffer:buffer];
    CVPixelBufferRelease(buffer);
    CFRelease(croppedImage);
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
    
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    int width = CVPixelBufferGetWidth(buffer);
    int height = CVPixelBufferGetHeight(buffer);
    
    
    CVPixelBufferRef i420Buffer;
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8Planar, (__bridge CFDictionaryRef _Nullable)att,&i420Buffer);
    CVPixelBufferLockBaseAddress(i420Buffer, 0);
    
    void *y_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 0);
    void *u_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 1);
    void *v_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 2);

    
    int stride_y = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 0);
    int stride_u = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 1);
    int stride_v = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 2);
    
    
    void *rgb = CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    void *rgb_stride = CVPixelBufferGetBytesPerRow(buffer);
    
    
    ARGBToI420(rgb, rgb_stride,
               y_frame, stride_y,
               u_frame, stride_u,
               v_frame, stride_v,
               width, height);
    
    CVPixelBufferUnlockBaseAddress(i420Buffer, 0);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CVPixelBufferRelease(buffer);
    
    return  i420Buffer;
}

void _CVPixelBufferReleaseBytesCallback(void *releaseRefCon, const void *baseAddress) {
    
    CFDataRef data = releaseRefCon;
    CFRelease(data);
    
}


-(CGImageRef)appendMouseCursor:(CGImageRef)pSourceImage{
    // get the cursor image
    NSPoint mouseLoc;
    mouseLoc = [NSEvent mouseLocation]; //get cur

    NSLog(@"Mouse location is x=%d,y=%d",(int)mouseLoc.x,(int)mouseLoc.y);

    // get the mouse image
    NSImage *overlay    =   [[[NSCursor arrowCursor] image] copy];

    NSLog(@"Mouse location is x=%d,y=%d cursor width = %d, cursor height = %d",(int)mouseLoc.x,(int)mouseLoc.y,(int)[overlay size].width,(int)[overlay size].height);

    int x = (int)mouseLoc.x;
    int y = (int)mouseLoc.y;
    int w = (int)[overlay size].width;
    int h = (int)[overlay size].height;
    int org_x = x;
    int org_y = y;

    size_t height = CGImageGetHeight(pSourceImage);
    size_t width =  CGImageGetWidth(pSourceImage);
    int bytesPerRow = CGImageGetBytesPerRow(pSourceImage);

    unsigned int * imgData = (unsigned int*)malloc(height*bytesPerRow);

    // have the graphics context now,
    CGRect bgBoundingBox = CGRectMake (0, 0, width,height);

    CGContextRef context =  CGBitmapContextCreate(imgData, width,
                                                  height,
                                                  8, // 8 bits per component
                                                  bytesPerRow,
                                                  CGImageGetColorSpace(pSourceImage),
                                                  CGImageGetBitmapInfo(pSourceImage));

    // first draw the image
    CGContextDrawImage(context,bgBoundingBox,pSourceImage);

    // then mouse cursor
    CGContextDrawImage(context,CGRectMake(0, 0, width,height),pSourceImage);

    // then mouse cursor
    CGContextDrawImage(context,CGRectMake(org_x, org_y, w,h),[overlay CGImageForProposedRect: NULL context: NULL hints: NULL] );


    // assuming both the image has been drawn then create an Image Ref for that

    CGImageRef pFinalImage = CGBitmapContextCreateImage(context);

    CGContextRelease(context);
    free(imgData);

    return pFinalImage; /* to be released by the caller */
}



@end
