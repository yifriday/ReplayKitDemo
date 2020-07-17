//
//  FIAgoraClientBufferSocketManager.m
//  FIAgoraVideo
//
//  Created by flagadmin on 2020/5/7.
//  Copyright © 2020 flagadmin. All rights reserved.
//
#import <ReplayKit/ReplayKit.h>
#import "NTESYUVConverter.h"
#import "NTESI420Frame.h"
#import "GCDAsyncSocket.h"
#import "NTESSocketPacket.h"
#import "NTESTPCircularBuffer.h"
#import "FIAgoraClientBufferSocketManager.h"

@interface FIAgoraClientBufferSocketManager()<GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableArray *sockets;
@property (nonatomic, assign) NTESTPCircularBuffer *recvBuffer;
@property(nonatomic, strong) NSString *testText;


@end

@implementation FIAgoraClientBufferSocketManager
+ (FIAgoraClientBufferSocketManager *)sharedManager{
    static FIAgoraClientBufferSocketManager *shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
}
#pragma mark - 屏幕共享

- (void)stopSocket
{
    if (_socket)
    {
        [_socket disconnect];
        _socket = nil;
        [_sockets removeAllObjects];
        NTESTPCircularBufferCleanup(_recvBuffer);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];

}

- (void)setupSocket
{
    self.sockets = [NSMutableArray array];
    _recvBuffer = (NTESTPCircularBuffer *)malloc(sizeof(NTESTPCircularBuffer)); // 需要释放
    NTESTPCircularBufferInit(_recvBuffer, kRecvBufferMaxSize);
//    self.queue = dispatch_queue_create("com.netease.edu.rp.server", DISPATCH_QUEUE_SERIAL);
    self.queue = dispatch_get_main_queue();
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    self.socket.IPv6Enabled = NO;
    NSError *error;
    //    [self.socket acceptOnUrl:[NSURL fileURLWithPath:serverURL] error:&error];
    [self.socket acceptOnPort:8999 error:&error];
    [self.socket readDataWithTimeout:-1 tag:0];
    NSLog(@"%@", error);
    NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(defaultsChanged:)
                   name:NSUserDefaultsDidChangeNotification
                 object:nil];
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err
{
    NTESTPCircularBufferClear(self.recvBuffer);
    [self.sockets removeObject:sock];
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock
{
    NTESTPCircularBufferClear(self.recvBuffer);
    [self.sockets removeObject:sock];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NTESTPCircularBufferClear(self.recvBuffer);
    [self.sockets addObject:newSocket];
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    static uint64_t currenDataSize = 0;
    static uint64_t targeDataSize = 0;

    BOOL isHeader = NO;
    if (data.length == sizeof(NTESPacketHead)) { // 检查是不是帧头
        NTESPacketHead *header = (NTESPacketHead *)data.bytes;
        if (header->version == 1 && header->command_id == 1 && header->service_id == 1) {
            isHeader = YES;
            targeDataSize = header->data_len;
            currenDataSize = 0;
        }
    } else {
        currenDataSize += data.length;
    }
    
    if (isHeader) { // a.接收到新的帧头，需要先把原来的缓存处理或者清空
        [self handleRecvBuffer];
        NTESTPCircularBufferProduceBytes(self.recvBuffer,
                                         data.bytes,
                                         (int32_t)data.length);
    } else if (currenDataSize >= targeDataSize
               && currenDataSize != -1) { // b.加上新来的数据后缓存中已经满足一帧
        NTESTPCircularBufferProduceBytes(self.recvBuffer,
                                         data.bytes,
                                         (int32_t)data.length);
        currenDataSize = -1;
        [self handleRecvBuffer];
    } else { // c.不够一帧，只添加不处理
        NTESTPCircularBufferProduceBytes(self.recvBuffer,
                                         data.bytes,
                                         (int32_t)data.length);
    }
    [sock readDataWithTimeout:-1 tag:0];
}


- (void)handleRecvBuffer {
    if (!self.sockets.count)
    {
        return;
    }
    
    int32_t availableBytes = 0;
    void * buffer = NTESTPCircularBufferTail(self.recvBuffer, &availableBytes);
    int32_t headSize = sizeof(NTESPacketHead);
    
    if(availableBytes <= headSize) {
        //        NSLog(@" > 不够文件头");
        NTESTPCircularBufferClear(self.recvBuffer);
        return;
    }
    
    NTESPacketHead head;
    memset(&head, 0, sizeof(head));
    memcpy(&head, buffer, headSize);
    uint64_t dataLen = head.data_len;
    
    if(dataLen > availableBytes - headSize && dataLen >0) {
        //        NSLog(@" > 不够数据体");
        NTESTPCircularBufferClear(self.recvBuffer);
        return;
    }
    
    void *data = malloc(dataLen);
    memset(data, 0, dataLen);
    memcpy(data, buffer + headSize, dataLen);
    NTESTPCircularBufferClear(self.recvBuffer); // 处理完一帧数据就清空缓存

    if([self respondsToSelector:@selector(onRecvData:)]) {
        @autoreleasepool {
            [self onRecvData:[NSData dataWithBytes:data length:dataLen]];
        };
    }
    
    free(data);
}

- (void)defaultsChanged:(NSNotification *)notification
{
    GCDAsyncSocket *socket = self.sockets.count ? self.sockets[0] : nil;

    NSUserDefaults *defaults = (NSUserDefaults*)[notification object];
    id setting = nil;
     // 分辨率
    static NSInteger quality;
    setting = [defaults objectForKey:@"videochat_preferred_video_quality"];
    if (quality != [setting integerValue] && setting)
    {
        quality = [setting integerValue];
        NTESPacketHead head;
        head.service_id = 0;
        head.command_id = 1; // 1：分辨率 2：裁剪比例 3：视频方向
        head.data_len = 0;
        head.version = 0;
        NSString *str = [NSString stringWithFormat:@"%d", [setting intValue]];
        [socket writeData:[NTESSocketPacket packetWithBuffer:[str dataUsingEncoding:NSUTF8StringEncoding] head:&head] withTimeout:-1 tag:0];
    }
    
    // 视频方向
    static NSInteger orientation;
    setting = [defaults objectForKey:@"videochat_preferred_video_orientation"];
    if (orientation != [setting integerValue] && setting)
    {
        orientation = [setting integerValue];
        NTESPacketHead head;
        head.service_id = 0;
        head.command_id = 3; // 1：分辨率 2：裁剪比例 3：视频方向
        head.data_len = 0;
        head.version = 0;
        head.serial_id = 0;
        NSString *str = [NSString stringWithFormat:@"%@", setting];
        [socket writeData:[NTESSocketPacket packetWithBuffer:[str dataUsingEncoding:NSUTF8StringEncoding] head:&head] withTimeout:-1 tag:0];

    }
}


#pragma mark - NTESSocketDelegate

- (void)onRecvData:(NSData *)data
{
    static int i = 0;
    i++;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NTESI420Frame *frame = [NTESI420Frame initWithData:data];
        CMSampleBufferRef sampleBuffer = [frame convertToSampleBuffer];
        NSLog(@"收到了%d条数据", i);
        NSString *testText = [NSString stringWithFormat:@"收到了%d条数据",i];
        if (self.testBlock) {
            self.testBlock(testText, sampleBuffer);
        }
    
        CFRelease(sampleBuffer);
    });
    
}

@end
