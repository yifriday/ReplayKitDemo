//
//  FIAgoraSocketManager.h
//  FIAgoraVideo
//
//  Created by flagadmin on 2020/5/7.
//  Copyright © 2020 flagadmin. All rights reserved.
//

#import <ReplayKit/ReplayKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface FIAgoraSampleHandlerSocketManager : NSObject
+ (FIAgoraSampleHandlerSocketManager *)sharedManager;
- (void)setUpSocket;
- (void)socketDelloc;
- (void)sendVideoBufferToHostApp:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
