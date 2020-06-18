//
//  DbyBufferVideoView.h
//  ScreenShareDemo
//
//  Created by yxibng on 2020/6/17.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DbyBufferVideoView : NSView
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
