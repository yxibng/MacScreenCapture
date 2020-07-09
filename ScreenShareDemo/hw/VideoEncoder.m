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
        OSStatus status = [self setupCompressionSession];
        if (status) {
            return nil;
        }
    }
    return self;
}
- (BOOL)start
{
    
    if (!self.compressSession) {
        NSLog(@"%s, session not created", __FUNCTION__);
        return NO;
    }
    OSStatus status = VTCompressionSessionPrepareToEncodeFrames(self.compressSession);
    if (status) {
        NSLog(@"%s, LINE %d, failed status:%d",__FUNCTION__, __LINE__, (int)status);
        return NO;
    }
    return YES;
}

- (BOOL)stop
{
    if (!self.compressSession) {
        return YES;
    }
    OSStatus status = VTCompressionSessionCompleteFrames(self.compressSession, kCMTimeInvalid);
    if (status) {
        NSLog(@"%s, LINE %d, failed status:%d",__FUNCTION__, __LINE__, (int)status);
        return NO;
    }
    return YES;
}

- (BOOL)encode:(CMSampleBufferRef)buffer forceKeyFrame:(BOOL)forceKeyFrame
{
    if (!self.compressSession) {
        return NO;
    }
    
    
    if (!buffer) {
        return NO;
    }
    
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    NSDictionary *frameProperties = @{
        (__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @(forceKeyFrame)
    };
    
    OSStatus status = VTCompressionSessionEncodeFrame(self.compressSession,
                                                      pixelBuffer,
                                                      kCMTimeInvalid,
                                                      kCMTimeInvalid,
                                                      (__bridge CFDictionaryRef)frameProperties,
                                                      (__bridge void * _Nullable)(self),
                                                      NULL);
    
    if (status) {
        NSLog(@"VTCompressionSessionEncodeFrame, LINE %d, failed status:%d", __LINE__, (int)status);
        return NO;
    }
    return YES;
}

- (OSStatus)adjustBitRate:(NSInteger)bitRate
{
    
    assert(bitRate > 0);
    //参考 https://stackoverflow.com/questions/31458150/how-to-set-bitrate-for-vtcompressionsession
    /*
     status = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(600 * 1024));
     status = VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[800 * 1024 / 8, 1]);
     
     Just remember that kVTCompressionPropertyKey_AverageBitRate takes bits
     kVTCompressionPropertyKey_DataRateLimits takes bytes and seconds.
     */
    
    //设置平均码率
    OSStatus status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nullable)(@(bitRate)));
    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_AverageBitRate, failed status:%d", (int)status);
        return status;
    }
        
    //设置最大码率, 参考webRTC 限制最大码率不超过平均码率的1.5倍
    int64_t maxBytesPerSecond = bitRate * 1.5 / 8;
    status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(maxBytesPerSecond),@( 1)]);

    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_DataRateLimits, failed status:%d", (int)status);
        return status;
    }
    return status;
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
        NSLog(@"VTCompressionSessionCreate:failed status:%d", (int)status);
        return status;
    }
    
    //设置码率
    status = [self adjustBitRate:self.encoderParams.bitRate];
    if (status) {
        return status;
    }
    
    //设置 profile level
    status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_ProfileLevel, self.encoderParams.profileLevel);
    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_ProfileLevel failed, status = %d", status);
        return status;
    }
    
    //设置实时输出，避免延迟
    status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_RealTime to TRUE, failed, status = %d", status);
        return status;
    }
    
    
    //配置是否产生B帧
    CFBooleanRef allowFrameReordering = self.encoderParams.allowFrameReordering ? kCFBooleanTrue : kCFBooleanFalse;
    status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_AllowFrameReordering, allowFrameReordering);
    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_AllowFrameReordering, failed, status = %d", status);
        return status;
    }
    
    
    //配置 I 帧间隔, 关键帧的帧率
    NSInteger maxKeyFrameInterval = self.encoderParams.frameRate * self.encoderParams.maxKeyFrameInterval;
    status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nullable)(@(maxKeyFrameInterval)));
    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_MaxKeyFrameInterval, failed, status = %d", status);
        return status;
    }
    //配置关键帧持续时间
    NSInteger maxKeyFrameIntervalDuration = self.encoderParams.maxKeyFrameInterval;
    status = VTSessionSetProperty(self.compressSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef _Nullable)(@(maxKeyFrameIntervalDuration)));
    
    if (status) {
        NSLog(@"set kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, failed, status = %d", status);
        return status;
    }
    //准备编码器
    status = VTCompressionSessionPrepareToEncodeFrames(self.compressSession);
    if (status) {
        NSLog(@"set VTCompressionSessionPrepareToEncodeFrames, failed, status = %d", status);
        return status;
    }
    return noErr;
}


void encodeOutputDataCallback(void * CM_NULLABLE outputCallbackRefCon, void * CM_NULLABLE sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CM_NULLABLE CMSampleBufferRef sampleBuffer) {
    
    
    
    
    
    
}

@end
