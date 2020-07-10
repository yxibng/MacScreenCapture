//
//  VideoDecorder.m
//  ScreenShareDemo
//
//  Created by yxibng on 2020/7/9.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import "VideoDecorder.h"


@interface VideoDecorder()
/** sps数据 */
@property (nonatomic, assign) uint8_t *sps;
/** sps数据长度 */
@property (nonatomic, assign) NSInteger spsSize;
/** pps数据 */
@property (nonatomic, assign) uint8_t *pps;
/** pps数据长度 */
@property (nonatomic, assign) NSInteger ppsSize;
/** 解码器句柄 */
@property (nonatomic, assign) VTDecompressionSessionRef decoderSession;
/** 视频解码信息句柄 */
@property (nonatomic, assign) CMVideoFormatDescriptionRef decoderFormatDescription;
@end


@implementation VideoDecorder

//解码回调函数
static void decodeOutputDataCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration)
{
    VideoDecorder *decoder = (__bridge VideoDecorder *)(decompressionOutputRefCon);
    if ([decoder.delegate respondsToSelector:@selector(decoder:receiveDecodedBuffer:)]) {
        [decoder.delegate decoder:decoder receiveDecodedBuffer:pixelBuffer];
    }
}



- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}


- (BOOL)initH264Decoder {
    
    if (self.decoderSession) {
        return YES;
    }
    
    
    const uint8_t *const parameterSetPoints[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {self.spsSize, self.ppsSize};
    //根据sps， pps 创建解码视频参数
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, parameterSetPoints, parameterSetSizes, 4, &_decoderFormatDescription);
    if (status) {
        NSLog(@"H264Decoder::CMVideoFormatDescriptionCreateFromH264ParameterSets failed status = %d", (int)status);
        return NO;
    }
    
    //从sps， pps 钟获取解码视频的宽高信息
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(_decoderFormatDescription);
    
    NSDictionary* destinationPixelBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferWidthKey : @(dimensions.width),
        (id)kCVPixelBufferHeightKey : @(dimensions.height),
        (id)kCVPixelBufferOpenGLCompatibilityKey : @(YES)
    };
    
    //设置解码输出数据的回调
    VTDecompressionOutputCallbackRecord callbackRecord;

    callbackRecord.decompressionOutputCallback = decodeOutputDataCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    
    //创建解码器
    status = VTDecompressionSessionCreate(NULL, _decoderFormatDescription, NULL, (__bridge CFDictionaryRef _Nullable)(destinationPixelBufferAttributes), &callbackRecord, &_decoderSession);
    //解码线程数量
    VTSessionSetProperty(self.decoderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef _Nullable)(@(1)));
    //是否实时解码
    VTSessionSetProperty(self.decoderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);

    
    return YES;
}


- (void)decodeNaluData:(NSData *)naluData {
    
    uint8_t *frame = (uint8_t *)naluData.bytes;
    uint32_t frameSize = (uint32_t)naluData.length;
    
    /*
     frame的前四位是NALU数据的开始码， 也就是00 00 00 01
     第五个字节表示数据类型，转为10进制，7是sps， 8是pps， 5是IDR（I帧）
     */
    int nalu_type =  frame[4] & 0x1F;
    
    
    //将NALU的开始码替换成NALU的长度信息
    uint32_t nalSize = frameSize - 4;
    uint8_t *pNalSize = (uint8_t *)(&nalSize);
    frame[0] = *(pNalSize + 3);
    frame[1] = *(pNalSize + 2);
    frame[2] = *(pNalSize + 1);
    frame[3] = *pNalSize;
    
    switch (nalu_type) {
        case 0x05://I 帧
            NSLog(@"NALU type is IDR frame");
            if ([self initH264Decoder]) {
                [self decode:frame withSize:frameSize];
            }
            break;
        case 0x07://SPS
            NSLog(@"NSLU type is SPS frame");
            _spsSize = frameSize -4;
            _sps = malloc(_spsSize);
            memcpy(_sps, frame + 4, _spsSize);
            break;
        case 0x08://PPS
            NSLog(@"NSLU type is PPS frame");
            _ppsSize = frameSize -4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, frame + 4, _ppsSize);
            break;
        default://B帧或者P帧
            NSLog(@"NSLU type is B/P frame");
            if ([self initH264Decoder]) {
                [self decode:frame withSize:frameSize];
            }
            break;
    }
    
}


- (void)decode:(uint8_t *)frame withSize:(uint32_t)frameSize{
 
    //TODO: 判断 sps， pps 变更的时候，需要重置解码器
    
    //创建CMBlockBuffer
    CMBlockBufferRef blockBuffer = NULL;
    
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, frame, frameSize, kCFAllocatorNull, NULL, 0, frameSize, FALSE, &blockBuffer);
    if (status)
    {
        return;
    }
    
    //创建CMSampleBuffer
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {frameSize};
    status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                       blockBuffer,
                                       _decoderFormatDescription,
                                       1,
                                       0,
                                       NULL,
                                       1,
                                       sampleSizeArray,
                                       &sampleBuffer);
    if (status) {
        CFRelease(blockBuffer);
        return;
    }
    
    //VTdecodeFrameFlags 0 为允许多线程解码
    VTDecodeFrameFlags flags =0;
    VTDecodeInfoFlags flagsOut = 0;
    //解码,这里第四个参数会传到解码的callback里的sourceFrameRefCon，可为空
    status = VTDecompressionSessionDecodeFrame(self.decoderSession,
                                               sampleBuffer,
                                               flags,
                                               NULL,
                                               &flagsOut);
    if (status == kVTInvalidSessionErr) {
        NSLog(@"H264Decoder::Invalid session, reset decoder session");
    } else if (status == kVTVideoDecoderBadDataErr) {
              NSLog(@"H264Decoder::decode failed status = %d(Bad data)", (int)status);
    } else if (status != noErr) {
         NSLog(@"H264Decoder::decode failed status = %d", (int)status);
    }
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
}







@end
