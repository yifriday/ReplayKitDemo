//
//  EKSampleHandlerClientSocketManager.h
//  aaa
//
//  Created by EkiSong on 2020/7/7.
//  Copyright © 2020 EkiSong. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^GetBufferBlock) (CMSampleBufferRef sampleBuffer);

@interface EKSampleHandlerClientSocketManager : NSObject
+ (EKSampleHandlerClientSocketManager *)sharedManager;
- (void)stopSocket;
- (void)setupSocket;
@property(nonatomic, copy) GetBufferBlock getBufferBlock;
@end
NS_ASSUME_NONNULL_END
