//
//  NTESSocket.m
//  DailyProj
//
//  Created by He on 2019/1/30.
//  Copyright © 2019 He. All rights reserved.
//

#import "NTESSocket.h"
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "NTESTPCircularBuffer.h"

@interface NTESSocket()
@property (nonatomic, assign) int socket;
@property (nonatomic, assign) int serverSocket;
@property (nonatomic, assign) int clientSocket;
@property (nonatomic, assign) BOOL isServerSocket;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (atomic,    assign) BOOL isWork;
@property (nonatomic, assign) NTESTPCircularBuffer *recvBuffer;
@end

@implementation NTESSocket

#pragma mark - API

- (void)dealloc {
    _isWork = NO;
    if(_socket != -1) {
        close(_socket);
    }
    if(_serverSocket != -1) {
        close(_serverSocket);
    }
    if(_clientSocket != -1) {
        close(_clientSocket);
    }
}

- (instancetype)initWithPort:(NSString *)port IP:(NSString *)IP
{
    if(self = [super init]) {
        _socket = -1;
        _serverSocket = -1;
        _clientSocket = -1;
        _port = port;
        _ip = IP;
        _queue = dispatch_queue_create("com.netease.ddddaily.send", DISPATCH_QUEUE_SERIAL);
        if(![self setupSocket])  {
            return nil;
        }
        
        if(![self bindSocket]) {
            return nil;
        }
    }
    return self;
}

// Server
- (BOOL)startAcceptClient {
    return [self listenAndAccept];
}

- (void)stop {
    NSLog(@" >> 停止");
    _isWork = NO;
    
    if(_socket != -1) {
        close(_socket);
        _socket = -1;
    }
    if(_serverSocket != -1) {
        close(_serverSocket);
        _serverSocket = -1;
    }
    if(_clientSocket != -1) {
        close(_clientSocket);
        _clientSocket = -1;
    }
    if(_delegate && [_delegate respondsToSelector:@selector(didDisconnected)]) {
        [_delegate didDisconnected];
    }
}

// Client
- (BOOL)connectToServerWithPort:(NSString *)port IP:(NSString *)IP {
    struct sockaddr_in addr_in;
    addr_in.sin_family = AF_INET;
    addr_in.sin_addr.s_addr = inet_addr([IP UTF8String]);
    addr_in.sin_port = htons([port intValue]);
    
    int success = connect(self.socket, (const struct sockaddr *)&addr_in, sizeof(struct sockaddr_in));
    if(-1 == success) {
        NSLog(@" > 连接到服务端失败 port:%@ IP:%@", port, IP);
        return NO;
    }
    self.isServerSocket = NO;
    return YES;
}

// Common
- (void)startRecv {
    if(self.isServerSocket) {
        [self receiveDataFromSocket:self.clientSocket];
    }else {
        [self receiveDataFromSocket:self.socket];
    }
}

- (void)sendData:(NSData *)data {
    if(self.isServerSocket) {
        [self sendDataToSocket:self.clientSocket buffer:[data bytes] size:data.length];
    }else {
        [self sendDataToSocket:self.socket buffer:[data bytes] size:data.length];
    }
}

- (void)sendData:(NSData *)data head:(NTESPacketHead *)head {
    if(self.isServerSocket) {
        [self sendDataToSocket:self.clientSocket
                        buffer:[data bytes]
                          size:data.length
                          head:head];
    }
    
}

#pragma mark - Internal

- (BOOL)setupSocket {
    _socket = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    if(_socket == -1) {
        NSLog(@" > 创建socket失败");
        return NO;
    }
    return YES;
}

- (BOOL)bindSocket {
    if(_socket <= 0) {
        NSLog(@" > socket创建失败");
        return NO;
    }
    struct sockaddr_in addr_in;
    addr_in.sin_family = AF_INET;
    addr_in.sin_addr.s_addr = inet_addr([self.ip UTF8String]);
    addr_in.sin_port = htons([self.port intValue]);
    
    int bd = bind(_socket, (const struct sockaddr *)&addr_in, sizeof(struct sockaddr_in));
    if(-1 == bd) {
        NSLog(@" > Bind socket失败");
        return NO;
    }
    return YES;
}

- (BOOL)listenAndAccept {
    int success = listen(_socket, 10);
    if(-1 == success) {
        NSLog(@" > Listen socket失败");
        return NO;
    }
    self.isServerSocket = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        do {
            struct sockaddr_in recvAddr;
            socklen_t recv_size = sizeof(struct sockaddr_in);
            NSLog(@" > 开始监听 %@ %@", self.ip, self.port);
            int client = accept(self.socket, (struct sockaddr *)&recvAddr, &recv_size);
            if(-1 == client) {
                NSLog(@" > 连接 客户端socket失败, 结束 %@", @(self.isWork));
            }else {
                if (self.clientSocket != -1)
                    close(self.clientSocket);
                self.clientSocket = client;
                [self receiveDataFromSocket:self.clientSocket];
            }
        }while(self.isWork);
        
    });
    return YES;
}

- (void)receiveDataFromSocket:(int)socket
{
    if(-1 == socket) {
        NSLog(@" > 接收 目标socket为空");
        return;
    }
    self.isWork = YES;
    if(_recvBuffer == NULL) {
        _recvBuffer = (NTESTPCircularBuffer *)malloc(sizeof(NTESTPCircularBuffer));
        NTESTPCircularBufferInit(_recvBuffer, kRecvBufferMaxSize);
    }
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(queue, ^{
        char *buffer = malloc(kRecvBufferPerSize);
        ssize_t size = -1;
        bool connected = true;
        while (self.isWork && connected) {
            memset(buffer, 0, kRecvBufferPerSize);
            size = recv(socket, buffer, kRecvBufferPerSize, 0);
            if(size == 0) {
                NSLog(@" > 断开");
                connected = false;
                break;
            }else if(size > 0){
                NTESTPCircularBufferProduceBytes(self.recvBuffer, buffer, (int32_t)size);
                [self handleRecvBuffer];
            }
        };
        free(buffer);
        if(!self.isServerSocket) {
            [self stop];
        }else {
            self.clientSocket = -1;
        }
    });
    
}
-(void)sendDataToSocket:(int)socket
                 buffer:(const void *)buffer
                   size:(size_t)size
                   head:(NTESPacketHead *)head
{
    size_t packetSize = 0;
    void *packetBuffer = [self packetWithBuffer:buffer size:size packetSize:&packetSize head:head];
    
    if(socket <= 0 ||packetBuffer == NULL || 0 == packetSize) {
        //        NSLog(@" >> 异常数据");
        free(packetBuffer);
        return;
    }
    dispatch_async(self.queue, ^{
        size_t length = send(socket, packetBuffer, packetSize, 0);
        free(packetBuffer);
        if(length == -1) {
            if(!self.isServerSocket) {
                [self stop];
            }
        }
    });
}
- (void)sendDataToSocket:(int)socket
                  buffer:(const void *)buffer
                    size:(size_t)size {
    if(socket == -1) {
        return;
    }
    
    size_t packetSize = 0;
    void *packetBuffer = [self packetWithBuffer:buffer size:size packetSize:&packetSize];
    
    if(socket <= 0 ||packetBuffer == NULL || 0 == packetSize) {
        if(packetBuffer) {
            free(packetBuffer);
        }
        return;
    }
    dispatch_async(self.queue, ^{
        size_t length = send(socket, packetBuffer, packetSize, 0);
        free(packetBuffer);
        if(length == -1) {
            if(!self.serverSocket) {
                [self stop];
            }else {
                self.clientSocket = -1;
            }
        }
    });
    
}

- (void)handleRecvBuffer {
    int32_t availableBytes = 0;
    void * buffer = NTESTPCircularBufferTail(self.recvBuffer, &availableBytes);
    int32_t headSize = sizeof(NTESPacketHead);
    
    if(availableBytes <= headSize) {
//        NSLog(@" > 不够文件头");
        return;
    }

    NTESPacketHead head;
    memset(&head, 0, sizeof(head));
    memcpy(&head, buffer, headSize);
    uint64_t dataLen = head.data_len;

    if(dataLen > availableBytes - headSize && dataLen >0) {
//        NSLog(@" > 不够数据体");
        return;
    }
    
    void *data = malloc(dataLen);
    memset(data, 0, dataLen);
    memcpy(data, buffer + headSize, dataLen);
    NTESTPCircularBufferConsume(self.recvBuffer, (int32_t)(headSize+dataLen));
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(onRecvData:head:)]) {
        @autoreleasepool {
            [self.delegate onRecvData:[NSData dataWithBytes:data length:dataLen] head:&head];
        };
    }
    if(self.delegate && [self.delegate respondsToSelector:@selector(onRecvData:)]) {
        @autoreleasepool {
            [self.delegate onRecvData:[NSData dataWithBytes:data length:dataLen]];
        };
    }

    free(data);
    
    if (availableBytes - headSize - dataLen >= headSize)
    {
        [self handleRecvBuffer];
    }
}

#pragma mark - Packet
- (void *)packetWithBuffer:(const void *)buffer
                      size:(size_t)size
                packetSize:(size_t *)packetSize
{
    if (0 == size)
    {
        return NULL;
    }
    
    void *data = malloc(sizeof(NTESPacketHead) + size);
    NTESPacketHead * head = (NTESPacketHead *)malloc(sizeof(NTESPacketHead));
    head->version = 1;
    head->command_id = 0;
    head->service_id = 0;
    head->serial_id = 0;
    head->data_len = (uint32_t)size;
    
    size_t headSize = sizeof(NTESPacketHead);
    *packetSize = size + headSize;
    memcpy(data, head, headSize);
    memcpy(data + headSize, buffer, size);
    
    free(head);
    
    return data;
}

- (void *)packetWithBuffer:(const void *)buffer
                      size:(size_t)size
                packetSize:(size_t *)packetSize
                      head:(NTESPacketHead *)head
{
    if(0 == size) {
        return NULL;
    }
    void *data = malloc(sizeof(NTESPacketHead) + size);

    head->data_len = (uint32_t)size;
    
    size_t headSize = sizeof(NTESPacketHead);
    *packetSize = size + headSize;
    memcpy(data, head, headSize);
    memcpy(data + headSize, buffer, size);
    
    return data;
}

@end
