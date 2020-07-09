//
//  VideoEncoder.h
//  ScreenShareDemo
//
//  Created by yxibng on 2020/7/9.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN


@interface VideoEncoderParams : NSObject

/*
 编码帧率，默认 15
 */
@property (nonatomic, assign) NSInteger frameRate;
/*
 编码帧的宽度
 */
@property (nonatomic, assign) NSInteger encodeWidth;
/*
 编码帧的高度
 */
@property (nonatomic, assign) NSInteger encodeHeight;

//h264
@property (nonatomic, assign, readonly) CMVideoCodecType encodeType;

/*
 default kVTProfileLevel_H264_High_5_1
 */
@property (nonatomic) CFStringRef profileLevel;

/*
 编码的码率，单位 kbps
 */
@property (nonatomic, assign) NSInteger bitRate;

/** 最大I帧间隔，单位为秒，缺省为240秒一个I帧 */
@property (nonatomic, assign) NSInteger maxKeyFrameInterval;
/** 是否允许产生B帧 缺省为NO */
@property (nonatomic, assign) BOOL allowFrameReordering;

@end


@interface VideoEncoder : NSObject


@property (nonatomic, strong) VideoEncoderParams *encoderParams;


- (instancetype)initWithParams:(VideoEncoderParams *)params;
- (BOOL)start;
- (BOOL)stop;

- (BOOL)encode:(CMSampleBufferRef)buffer forceKeyFrame:(BOOL)forceKeyFrame;
- (BOOL)adjustBitRate:(NSInteger)bitRate;


@end

NS_ASSUME_NONNULL_END
