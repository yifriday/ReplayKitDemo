//
//
//  Created by fenric on 16/3/25.
//  Copyright © 2016年 Netease. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "NTESI420Frame.h"


typedef NS_ENUM(uint8_t, NTESVideoPackOrientation) {
    NTESVideoPackOrientationPortrait               = 0, //No rotation
    NTESVideoPackOrientationLandscapeLeft          = 1, //Rotate 90 degrees clockwise
    NTESVideoPackOrientationPortraitUpsideDown     = 2, //Rotate 180 degrees
    NTESVideoPackOrientationLandscapeRight         = 3, //Rotate 270 degrees clockwise
};

@interface NTESYUVConverter : NSObject

+ (NTESI420Frame *)pixelBufferToI420:(CVImageBufferRef)pixelBuffer
                           withCrop:(float)cropRatio
                         targetSize:(CGSize)size
                     andOrientation:(NTESVideoPackOrientation)orientation;

+ (CVPixelBufferRef)i420FrameToPixelBuffer:(NTESI420Frame *)i420Frame;

+ (CMSampleBufferRef)pixelBufferToSampleBuffer:(CVPixelBufferRef)pixelBuffer;

@end
