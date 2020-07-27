//
//  SampleHandler.m
//  replaykitupload
//
//  Created by EkiSong on 2020/7/6.
//  Copyright © 2020 EkiSong. All rights reserved.
//

#import "SampleHandler.h"
#import "EKSampleHandlerSocketManager.h"

@implementation SampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *, NSObject *> *)setupInfo {
    // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
//    sleep(1);//在pad上瞬时启动时，CPU和内存使用会暴增，所以延迟2s执行，避开高峰
    [[EKSampleHandlerSocketManager sharedManager] setUpSocket];
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    switch (sampleBufferType) {
        case RPSampleBufferTypeVideo:
            // Handle video sample buffer
            [[EKSampleHandlerSocketManager sharedManager] sendVideoBufferToHostApp:sampleBuffer];
            break;
        case RPSampleBufferTypeAudioApp:
            // Handle audio sample buffer for app audio
            break;
        case RPSampleBufferTypeAudioMic:
            // Handle audio sample buffer for mic audio
            break;

        default:
            break;
    }
}
@end
