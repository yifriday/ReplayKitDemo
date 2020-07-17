//
//  NTESSocketPacket.m
//  NIMEducationDemo
//
//  Created by He on 2019/5/6.
//  Copyright © 2019 Netease. All rights reserved.
//

#import "NTESSocketPacket.h"

@implementation NTESSocketPacket

+ (NSData *)packetWithBuffer:(NSData *)rawData
{
    NSMutableData *mutableData = [NSMutableData data];
    @autoreleasepool {
        if (rawData.length == 0)
        {
            return NULL;
        }
        static uint64_t serial_id = 0;
        size_t size = rawData.length;
        void *data = malloc(sizeof(NTESPacketHead));
        NTESPacketHead *head = (NTESPacketHead *)malloc(sizeof(NTESPacketHead));
        head->version = 1;
        head->command_id = 1;
        head->service_id = 1;
        head->serial_id = serial_id++;
        head->data_len = (uint32_t)size;
        
        size_t headSize = sizeof(NTESPacketHead);
        memcpy(data, head, headSize);
        NSData *headData = [NSData dataWithBytes:data length:headSize];
        [mutableData appendData:headData];
//        [mutableData appendData:rawData];
        
        free(data);
        free(head);
    }
    return [mutableData copy];
}

+ (NSData *)packetWithBuffer:(NSData *)rawData head:(NTESPacketHead *)head
{
    if (rawData)
    {
        head->data_len = rawData.length;
    }
    
    NSMutableData *mutableData = [NSMutableData data];
    NSData *headData = [NSData dataWithBytes:head length:sizeof(NTESPacketHead)];
    [mutableData appendData:headData];
    
    if (rawData)
    {
        [mutableData appendData:rawData];
    }
    return mutableData.copy;
}

@end
