//
//  EKSampleHandlerSocketManager.h
//  aaa
//
//  Created by EkiSong on 2020/7/7.
//  Copyright © 2020 EkiSong. All rights reserved.
//

#import <ReplayKit/ReplayKit.h>
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface EKSampleHandlerSocketManager : NSObject
+ (EKSampleHandlerSocketManager *)sharedManager;
- (void)setUpSocket;
- (void)socketDelloc;
- (void)sendVideoBufferToHostApp:(CMSampleBufferRef)sampleBuffer;
- (long)getCurUsedMemory;
@end
NS_ASSUME_NONNULL_END
