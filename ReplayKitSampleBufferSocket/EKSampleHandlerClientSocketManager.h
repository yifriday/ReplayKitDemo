//
//  FIAgoraClientBufferSocketManager.h
//  FIAgoraVideo
//
//  Created by flagadmin on 2020/5/7.
//  Copyright © 2020 flagadmin. All rights reserved.
//
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^TestBlock) (NSString *testText,CMSampleBufferRef sampleBuffer);

@interface FIAgoraClientBufferSocketManager : NSObject
+ (FIAgoraClientBufferSocketManager *)sharedManager;
- (void)stopSocket;
- (void)setupSocket;
@property(nonatomic, copy) TestBlock testBlock;


@end

NS_ASSUME_NONNULL_END
