//
//  DbyVideoCapturer.m
//  DbyPaasMultiStream
//
//  Created by yxibng on 2020/6/15.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "DbyVideoCapturer.h"

@interface DbyVideoCapturer ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) BOOL setupResult;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) dispatch_queue_t sampleBufferQueue;
@end


@implementation DbyVideoCapturer

- (instancetype)initWithDelegate:(id<DbyVideoCapturerDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        
        _sessionQueue = dispatch_queue_create("com.dby.demo.video.session.queue", DISPATCH_QUEUE_SERIAL);
        _sampleBufferQueue = dispatch_queue_create("com.dby.demo.video.sample.buffer.queue", DISPATCH_QUEUE_SERIAL);
        _session = [[AVCaptureSession alloc] init];
        
        dispatch_async(self.sessionQueue, ^{
            [self setupSession];
        });
        
    }
    return self;
}

- (void)setupSession {
    
    [self.session beginConfiguration];
    
    AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:CGMainDisplayID()];
    input.capturesMouseClicks = YES;
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    } else {
        [self.session commitConfiguration];
        self.setupResult = NO;
        return;
    }
        
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey, nil];
    output.videoSettings = settings;
    [output setSampleBufferDelegate:self queue:self.sampleBufferQueue];
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
    } else {
        //add output failed
        [self.session commitConfiguration];
        self.setupResult = NO;
        return;
    }
    self.setupResult = YES;
    [self.session commitConfiguration];
    
}


- (void)start {
    
    dispatch_async(self.sessionQueue, ^{
        if (!self.setupResult) {
            if ([self.delegate respondsToSelector:@selector(videoCapturer:didStartWithStatus:)]) {
                [self.delegate videoCapturer:self didStartWithStatus:DbyVideoCapturerStatus_SetupError];
            }
            return;
        }
        
        if (@available(macOS 10.14, *)) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    [self startSession];
                } else {
                    if ([self.delegate respondsToSelector:@selector(videoCapturer:didStartWithStatus:)]) {
                        [self.delegate videoCapturer:self didStartWithStatus:DbyVideoCapturerStatus_NoPresssion];
                    }
                }
            }];
        } else {
            // Fallback on earlier versions
            [self startSession];
        }
    });
    
}

- (void)startSession
{
    [self.session startRunning];
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didStartWithStatus:)]) {
        [self.delegate videoCapturer:self didStartWithStatus:DbyVideoCapturerStatus_NoError];
    }
}



- (void)stop {
    dispatch_async(self.sessionQueue, ^{
        [self.session stopRunning];
        if ([self.delegate respondsToSelector:@selector(videoCapturer:didStopWithStatus:)]) {
            [self.delegate videoCapturer:self didStopWithStatus:DbyVideoCapturerStatus_NoError];
        }
    });
}


#pragma mark - delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didReceiveSampleBuffer:)]) {
        [self.delegate videoCapturer:self didReceiveSampleBuffer:sampleBuffer];
    }
    
    //回调 pixBuffer
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didReceivePixelBuffer:)]) {
        [self.delegate videoCapturer:self didReceivePixelBuffer:pixelBuffer];
    }
}





@end
