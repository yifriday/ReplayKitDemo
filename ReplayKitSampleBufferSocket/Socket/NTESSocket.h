//
//  NTESSocket.h
//  DailyProj
//
//  Created by He on 2019/1/30.
//  Copyright © 2019 He. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    uint8_t version;
    uint8_t service_id;
    uint8_t command_id;
    uint8_t serial_id;
    uint64_t data_len;
} NTESPacketHead;

#define kRecvBufferMaxSize 1024 * 1024 *15
#define kRecvBufferPerSize 1024

NS_ASSUME_NONNULL_BEGIN

@protocol NTESSocketDelegate <NSObject>

@optional
- (void)onRecvData:(NSData *)data;
- (void)onRecvData:(NSData *)data head:(NTESPacketHead *)head;
- (void)didDisconnected;
@end

@interface NTESSocket : NSObject
@property(nonatomic, copy) NSString *ip;
@property(nonatomic, copy) NSString *port;
@property(nonatomic, weak) id<NTESSocketDelegate> delegate;

- (instancetype)initWithPort:(NSString *)port IP:(NSString *)IP;

// Server
- (BOOL)startAcceptClient;

// Client
- (BOOL)connectToServerWithPort:(NSString *)port IP:(NSString *)IP;
- (void)startRecv;

// Common
- (void)stop;
- (void)sendData:(NSData *)data;
- (void)sendData:(NSData *)data head:(NTESPacketHead *)head;

@end

NS_ASSUME_NONNULL_END
