//
//  DbyVideoCapturer.h
//  DbyPaasMultiStream
//
//  Created by yxibng on 2020/6/15.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DbyVideoCapturerStatus) {
    DbyVideoCapturerStatus_NoError = 0,
    DbyVideoCapturerStatus_NoPresssion,
    DbyVideoCapturerStatus_SetupError,
    DbyVideoCapturerStatus_SystemInterrupt,
    DbyVideoCapturerStatus_SystemError
};

@class DbyVideoCapturer;
@protocol DbyVideoCapturerDelegate <NSObject>

- (void)videoCapturer:(DbyVideoCapturer *)capturer didStartWithStatus:(int)status;
- (void)videoCapturer:(DbyVideoCapturer *)capturer didReceivePixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)videoCapturer:(DbyVideoCapturer *)capturer didStopWithStatus:(int)status;
- (void)videoCapturer:(DbyVideoCapturer *)capturer didReceiveSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end


@interface DbyVideoCapturer : NSObject
@property (nonatomic, strong, readonly) AVCaptureSession *session;
- (instancetype)initWithDelegate:(id<DbyVideoCapturerDelegate>)delegate;

@property (nonatomic, weak) id<DbyVideoCapturerDelegate>delegate;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
