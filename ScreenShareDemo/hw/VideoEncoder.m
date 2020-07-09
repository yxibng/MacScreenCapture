//
//  VideoEncoder.m
//  ScreenShareDemo
//
//  Created by yxibng on 2020/7/9.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "VideoEncoder.h"

@implementation VideoEncoderParams

- (instancetype)init
{
    self = [super init];
    if (self) {
        _frameRate = 15;
        _maxKeyFrameInterval = 240;
        _allowFrameReordering = NO;
        _encodeType = kCMVideoCodecType_H264;
        _profileLevel = kVTProfileLevel_H264_High_5_1;
        _bitRate = 1024 * 1024;
    }
    return self;
}

@end



@interface VideoEncoder()

@property (nonatomic) VTCompressionSessionRef compressSession;
@property (nonatomic) dispatch_queue_t operationQueue;

@end



@implementation VideoEncoder

- (void)dealloc
{
    if (_compressSession) {
        VTCompressionSessionCompleteFrames(_compressSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_compressSession);
        CFRelease(_compressSession);
        _compressSession = NULL;
    }
}


- (instancetype)initWithParams:(VideoEncoderParams *)params
{
    if (self = [super init]) {
        _encoderParams = params;
        
    }
    return self;
}
- (BOOL)start
{
    return YES;
}

- (BOOL)stop
{
    return YES;
}

- (BOOL)encode:(CMSampleBufferRef)buffer forceKeyFrame:(BOOL)forceKeyFrame
{
    return YES;
}

- (BOOL)adjustBitRate:(NSInteger)bitRate
{
    
    if (bitRate <= 0) {
        return NO;
    }
    
    OSStatus status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nullable)(@(bitRate)));
    
    if (status) {
        NSLog(@"%s, failed status:%d", __FUNCTION__, (int)status);
        return NO;
    }
        
    
    
    
    
    
    return YES;
}


#pragma mark -

- (OSStatus)setupCompressionSession {
    
    OSStatus status = VTCompressionSessionCreate(NULL,
                                                 (int32_t)self.encoderParams.encodeWidth,
                                                 (int32_t)self.encoderParams.encodeHeight,
                                                 self.encoderParams.encodeType,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 encodeOutputDataCallback,
                                                 (__bridge void * _Nullable)(self),
                                                 &_compressSession);
    
    if (status) {
        return status;
    }
    
    //设置码率
    
    
    
    return noErr;
    
    
}






void encodeOutputDataCallback(void * CM_NULLABLE outputCallbackRefCon, void * CM_NULLABLE sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CM_NULLABLE CMSampleBufferRef sampleBuffer) {
    
}

@end
