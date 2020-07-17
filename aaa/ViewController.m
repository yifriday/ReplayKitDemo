//
//  ViewController.m
//  aaa
//
//  Created by EkiSong on 2020/7/4.
//  Copyright © 2020 EkiSong. All rights reserved.
//

#import "ViewController.h"
#import <ReplayKit/ReplayKit.h>
#import "EKSampleHandlerClientSocketManager.h"

@interface ViewController ()
@property (nonatomic, assign) UIBackgroundTaskIdentifier backIden;

@property (nonatomic, strong) IBOutlet UIButton *startBtn;
@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self ios12Action];
    [[EKSampleHandlerClientSocketManager sharedManager] setupSocket];
    [[EKSampleHandlerClientSocketManager sharedManager]setGetBufferBlock:^(CMSampleBufferRef  _Nonnull sampleBuffer) {
        UIImage *image = [self imageConvert:sampleBuffer];
        if (image) {
            self.imageView.image = image;
        }
    }];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didEnterBackGround) name:UIApplicationDidEnterBackgroundNotification object:nil];
}
- (void)didEnterBackGround {
    //保证进入后台后App依然能得到时间处理
    __weak typeof(self) weakSelf = self;
    self.backIden = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [[UIApplication sharedApplication] endBackgroundTask:strongSelf.backIden];
        strongSelf.backIden = UIBackgroundTaskInvalid;
    }];
}

#pragma mark Extension

- (void)ios12Action {
    RPSystemBroadcastPickerView *picker = [[RPSystemBroadcastPickerView alloc] initWithFrame:self.startBtn.frame];
    if (@available(iOS 12.2, *)) {
        picker.preferredExtension = @"com.EkiSong.aaa.replaykitupload";
    }
    [self.view addSubview:picker];
    [self.view bringSubviewToFront:self.startBtn];
}

- (UIImage *)imageConvert:(CMSampleBufferRef)sampleBuffer {
    if (!CMSampleBufferIsValid(sampleBuffer)) {
        return nil;
    }
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    UIImage *image = [UIImage imageWithCIImage:ciImage];
    return image;
}
@end
