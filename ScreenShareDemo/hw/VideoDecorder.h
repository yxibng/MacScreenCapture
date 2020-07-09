//
//  VideoDecorder.h
//  ScreenShareDemo
//
//  Created by yxibng on 2020/7/9.
//  Copyright © 2020 yxibng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>


NS_ASSUME_NONNULL_BEGIN

@interface VideoDecorder : NSObject


- (void)decodeNaluData:(NSData *)naluData;


@end

NS_ASSUME_NONNULL_END
