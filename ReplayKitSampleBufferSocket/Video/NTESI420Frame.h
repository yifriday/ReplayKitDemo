//
//
//  Created by Netease on 15/4/17.
//  Copyright (c) 2017年 Netease. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>

typedef NS_ENUM(NSUInteger, NTESI420FramePlane) {
    NTESI420FramePlaneY = 0,
    NTESI420FramePlaneU = 1,
    NTESI420FramePlaneV = 2,
};

@interface NTESI420Frame : NSObject

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;
@property (nonatomic, readonly) int i420DataLength;
@property (nonatomic, assign)   UInt64 timetag;
@property (nonatomic, readonly) UInt8 *data;

+ (instancetype)initWithData:(NSData *)data;

- (NSData *)bytes;

- (id)initWithWidth:(int)w height:(int)h;

- (UInt8 *)dataOfPlane:(NTESI420FramePlane)plane;

- (NSUInteger)strideOfPlane:(NTESI420FramePlane)plane;

- (CMSampleBufferRef)convertToSampleBuffer;

@end
