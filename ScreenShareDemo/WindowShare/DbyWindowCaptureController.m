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
    _windowID = 52439;
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
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, self.windowID);
    CFIndex count = CFArrayGetCount(windowList);
    if (count == 0) {
        CFRelease(windowList);
        return;
    }
    
    CFDictionaryRef windowInfo = CFArrayGetValueAtIndex(windowList, 0);
    CFDictionaryRef boundsInfo = CFDictionaryGetValue(windowInfo, kCGWindowBounds);
    
    CGRect rect = CGRectNull;
    bool ret = CGRectMakeWithDictionaryRepresentation(boundsInfo, &rect);
    CFRelease(windowList);
    if (!ret) {
        return;
    }
    //取得窗口快照
    CGImageRef windowImage = CGWindowListCreateImage(rect, kCGWindowListOptionIncludingWindow | kCGWindowListExcludeDesktopElements, self.windowID, kCGWindowImageNominalResolution);
    if (!windowImage) {
        NSLog(@"window image is null");
        return;
    }
    
//    NSImage * cursor = [NSCursor currentCursor].image;
//
//    NSPoint point = NSEvent.mouseLocation;
//
//
//
//
//
//
//    NSLog(@"window image = %@, rect = %@",windowImage, NSStringFromRect(rect));

    
    //追加光标， 参考 https://www.coder.work/article/1297008
    CGImageRef imagWithCursor = [self appendMouseCursor:windowImage sourceImageRect:rect];
    CFRelease(windowImage);
    if (!imagWithCursor) {
        return;
    }

    
    
    
    //做裁切
    CGImageRef croppedImage = CGImageCreateWithImageInRect(imagWithCursor, CGRectInfinite);
    CFRelease(imagWithCursor);
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
    
    if (originalWidth == 0 || originalHeight == 0) {
        return NULL;
    }

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


- (void)printWindowInfo
{
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, self.windowID);
    NSArray *array = (__bridge NSArray*)windowList;
    
    for (id window in array) {
        NSLog(@"%@",window);
    }
    
    CFIndex count = CFGetRetainCount(windowList);
    if (count == 0) {
        CFRelease(windowList);
        return;
    }
    
    CFDictionaryRef windowInfo = CFArrayGetValueAtIndex(windowList, 0);
    CFDictionaryRef boundsInfo = CFDictionaryGetValue(windowInfo, kCGWindowBounds);
    
    CGRect rect;
    bool ret = CGRectMakeWithDictionaryRepresentation(boundsInfo, &rect);
    NSLog(@"x = %f, y = %f, width = %f, height = %f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height );
    
    CFRetain(windowList);
    
}

CGImageRef CreateScaledCGImage(CGImageRef image, int width, int height) {
  // Create context, keeping original image properties.
  CGColorSpaceRef colorspace = CGImageGetColorSpace(image);
  CGContextRef context = CGBitmapContextCreate(NULL,
                                               width,
                                               height,
                                               CGImageGetBitsPerComponent(image),
                                               width * sizeof(uint32_t),
                                               colorspace,
                                               CGImageGetBitmapInfo(image));
  if (!context) return nil;
  // Draw image to context, resizing it.
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
  // Extract resulting image from context.
  CGImageRef imgRef = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  return imgRef;
}


//追加光标， 参考 https://www.coder.work/article/1297008
-(CGImageRef)appendMouseCursor:(CGImageRef)pSourceImage sourceImageRect:(CGRect)imageRect {
    // get the cursor image
    
    
    
    if (!pSourceImage) {
        return NULL;
    }
    
    CGEventRef event = CGEventCreate(NULL);
    CGPoint mouseLoc = CGEventGetLocation(event);
    CFRelease(event);
    

    // get the mouse image
    NSImage *overlay = [[NSCursor currentSystemCursor] image];
    
    CGImageRef overlayImage = [overlay CGImageForProposedRect:NULL
                                                      context:nil hints:nil];
    
    if (CGImageGetWidth(overlayImage) != (size_t)overlay.size.width) {
        NSLog(@"should scale");
    }
    
    CGFloat y = NSMaxY(NSScreen.screens.firstObject.frame) - mouseLoc.y;
    CGRect mouseRect = CGRectMake(mouseLoc.x, y, overlay.size.width, overlay.size.height);
    
    if (!CGRectContainsPoint(imageRect, mouseRect.origin)) {
        CFRetain(pSourceImage);
        return pSourceImage;
    }
    
    CGPoint convertedPoint = CGPointMake(mouseRect.origin.x - imageRect.origin.x, mouseRect.origin.y - imageRect.origin.y);

    CGRect cursorRect = CGRectMake(convertedPoint.x, convertedPoint.y, overlay.size.width, overlay.size.height);
    
    NSLog(@"mouseloc = %@", NSStringFromPoint(mouseLoc));
    NSLog(@"imageRect = %@", NSStringFromRect(imageRect));
    NSLog(@"cursorRect = %@", NSStringFromRect(cursorRect));
    
    size_t height = CGImageGetHeight(pSourceImage);
    size_t width =  CGImageGetWidth(pSourceImage);
    int bytesPerRow = (int)CGImageGetBytesPerRow(pSourceImage);

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

    NSRect overlayRect = CGRectMake(0, 0, overlay.size.width, overlay.size.height);
    // then mouse cursor
    CGContextDrawImage(context, cursorRect, [overlay CGImageForProposedRect:&overlayRect context:NULL hints:NULL]);
    // assuming both the image has been drawn then create an Image Ref for that

    CGImageRef pFinalImage = CGBitmapContextCreateImage(context);

    CGContextRelease(context);
    free(imgData);

    return pFinalImage; /* to be released by the caller */
}



@end
