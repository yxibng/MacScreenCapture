//
//  DbyPreviewVideoView.h
//  DbyPaasMultiStream
//
//  Created by yxibng on 2020/6/15.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DbyPreviewVideoView : NSView
- (void)setSession:(AVCaptureSession *)session;
@end

NS_ASSUME_NONNULL_END
