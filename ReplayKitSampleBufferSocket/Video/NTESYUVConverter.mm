//  Created by fenric on 16/3/25.
//  Copyright © 2016年 Netease. All rights reserved.
//

#import "NTESYUVConverter.h"
#import "NTESVideoUtil.h"
#import "libyuv.h"
#import <VideoToolbox/VideoToolbox.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
@implementation NTESYUVConverter

+ (NTESI420Frame *)I420ScaleWithSourceI420Frame:(NTESI420Frame *)I420Frame
                                       dstWidth:(float)width
                                      dstHeight:(float)height {
    NTESI420Frame *scaledI420Frame = [[NTESI420Frame alloc] initWithWidth:width height:height];

    libyuv::I420Scale([I420Frame dataOfPlane:NTESI420FramePlaneY],
                      (int)[I420Frame strideOfPlane:NTESI420FramePlaneY],
                      [I420Frame dataOfPlane:NTESI420FramePlaneU],
                      (int)[I420Frame strideOfPlane:NTESI420FramePlaneU],
                      [I420Frame dataOfPlane:NTESI420FramePlaneV],
                      (int)[I420Frame strideOfPlane:NTESI420FramePlaneV],
                      I420Frame.width, I420Frame.height,
                      [scaledI420Frame dataOfPlane:NTESI420FramePlaneY],
                      (int)[scaledI420Frame strideOfPlane:NTESI420FramePlaneY],
                      [scaledI420Frame dataOfPlane:NTESI420FramePlaneU],
                      (int)[scaledI420Frame strideOfPlane:NTESI420FramePlaneU],
                      [scaledI420Frame dataOfPlane:NTESI420FramePlaneV],
                      (int)[scaledI420Frame strideOfPlane:NTESI420FramePlaneV],
                      width, height, libyuv::kFilterNone);

    return scaledI420Frame;
}

//+ (NVSI420Frame *)pixelBufferToI420:(CVImageBufferRef)pixelBuffer withCrop:(float)cropRatio targetSize:(CGSize)size andOrientation:(NVSVideoPackOrientation)orientation {
//
////    CMVideoDimensions outputDimens = [NVSVideoUtil outputVideoDimens:inputDimens crop:cropRatio];
//    return [self pixelBufferToI420:pixelBuffer withCrop:cropRatio andScale:0 andOrientation:orientation];
//}

+ (NTESI420Frame *)pixelBufferToI420:(CVImageBufferRef)pixelBuffer
                            withCrop:(float)cropRatio
                          targetSize:(CGSize)size
                      andOrientation:(NTESVideoPackOrientation)orientation
{
    if (pixelBuffer == NULL) {
        return nil;
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);

    size_t bufferWidth = 0;
    size_t bufferHeight = 0;
    size_t rowSize = 0;
    uint8_t *pixel = NULL;

    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        int basePlane = 0;
        pixel = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, basePlane);
        bufferHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, basePlane);
        bufferWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, basePlane);
        rowSize = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, basePlane);
    } else {
        pixel = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
        bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
        rowSize = CVPixelBufferGetBytesPerRow(pixelBuffer);
    }

    NTESI420Frame *convertedI420Frame = [[NTESI420Frame alloc] initWithWidth:(int)bufferWidth height:(int)bufferHeight];

    int error = -1;

    if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
        error = libyuv::ARGBToI420(
            pixel, (int)rowSize,
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneY], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneY],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneU], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneU],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneV], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneV],
            (int)bufferWidth, (int)bufferHeight);
    } else if (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange == sourcePixelFormat || kCVPixelFormatType_420YpCbCr8BiPlanarFullRange == sourcePixelFormat) {
        error = libyuv::NV12ToI420(
            pixel,
            (int)rowSize,
            (const uint8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
            (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1),
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneY],
            (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneY],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneU],
            (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneU],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneV],
            (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneV],
            (int)bufferWidth,
            (int)bufferHeight);
    }

    if (error) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        NSLog(@"error convert pixel buffer to i420 with error %d", error);
        return nil;
    } else {
        rowSize = [convertedI420Frame strideOfPlane:NTESI420FramePlaneY];
        pixel = convertedI420Frame.data;
    }

    CMVideoDimensions inputDimens = { (int32_t)bufferWidth, (int32_t)bufferHeight };
    CMVideoDimensions outputDimens = [NTESVideoUtil outputVideoDimensEnhanced:inputDimens crop:cropRatio];
//        CMVideoDimensions outputDimens = {(int32_t)738,(int32_t)1312};
    CMVideoDimensions sizeDimens = { (int32_t)size.width, (int32_t)size.height };
    CMVideoDimensions targetDimens = [NTESVideoUtil outputVideoDimensEnhanced:sizeDimens crop:cropRatio];
    int cropX = (inputDimens.width - outputDimens.width) / 2;
    int cropY = (inputDimens.height - outputDimens.height) / 2;

    if (cropX % 2) {
        cropX += 1;
    }

    if (cropY % 2) {
        cropY += 1;
    }
    float scale = targetDimens.width * 1.0 / outputDimens.width;

    NTESI420Frame *croppedI420Frame = [[NTESI420Frame alloc] initWithWidth:outputDimens.width height:outputDimens.height];

    error = libyuv::ConvertToI420(pixel, bufferHeight * rowSize * 1.5,
                                  [croppedI420Frame dataOfPlane:NTESI420FramePlaneY], (int)[croppedI420Frame strideOfPlane:NTESI420FramePlaneY],
                                  [croppedI420Frame dataOfPlane:NTESI420FramePlaneU], (int)[croppedI420Frame strideOfPlane:NTESI420FramePlaneU],
                                  [croppedI420Frame dataOfPlane:NTESI420FramePlaneV], (int)[croppedI420Frame strideOfPlane:NTESI420FramePlaneV],
                                  cropX, cropY,
                                  (int)bufferWidth, (int)bufferHeight,
                                  croppedI420Frame.width, croppedI420Frame.height,
                                  libyuv::kRotate0, libyuv::FOURCC_I420);

    if (error) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        NSLog(@"error convert pixel buffer to i420 with error %d", error);
        return nil;
    }

    NTESI420Frame *i420Frame;

    if (scale == 1.0) {
        i420Frame = croppedI420Frame;
    } else {
        int width = outputDimens.width * scale;
        width &= 0xFFFFFFFE;
        int height = outputDimens.height * scale;
        height &= 0xFFFFFFFE;

        i420Frame = [[NTESI420Frame alloc] initWithWidth:width height:height];

        libyuv::I420Scale([croppedI420Frame dataOfPlane:NTESI420FramePlaneY], (int)[croppedI420Frame strideOfPlane:NTESI420FramePlaneY],
                          [croppedI420Frame dataOfPlane:NTESI420FramePlaneU], (int)[croppedI420Frame strideOfPlane:NTESI420FramePlaneU],
                          [croppedI420Frame dataOfPlane:NTESI420FramePlaneV], (int)[croppedI420Frame strideOfPlane:NTESI420FramePlaneV],
                          croppedI420Frame.width, croppedI420Frame.height,
                          [i420Frame dataOfPlane:NTESI420FramePlaneY], (int)[i420Frame strideOfPlane:NTESI420FramePlaneY],
                          [i420Frame dataOfPlane:NTESI420FramePlaneU], (int)[i420Frame strideOfPlane:NTESI420FramePlaneU],
                          [i420Frame dataOfPlane:NTESI420FramePlaneV], (int)[i420Frame strideOfPlane:NTESI420FramePlaneV],
                          i420Frame.width, i420Frame.height,
                          libyuv::kFilterBilinear);
    }

    int dstWidth, dstHeight;
    libyuv::RotationModeEnum rotateMode = [NTESYUVConverter rotateMode:orientation];

    if (rotateMode != libyuv::kRotateNone) {
        if (rotateMode == libyuv::kRotate270 || rotateMode == libyuv::kRotate90) {
            dstWidth = i420Frame.height;
            dstHeight = i420Frame.width;
        } else {
            dstWidth = i420Frame.width;
            dstHeight = i420Frame.height;
        }
        NTESI420Frame *rotatedI420Frame = [[NTESI420Frame alloc]initWithWidth:dstWidth height:dstHeight];

        libyuv::I420Rotate([i420Frame dataOfPlane:NTESI420FramePlaneY], (int)[i420Frame strideOfPlane:NTESI420FramePlaneY],
                           [i420Frame dataOfPlane:NTESI420FramePlaneU], (int)[i420Frame strideOfPlane:NTESI420FramePlaneU],
                           [i420Frame dataOfPlane:NTESI420FramePlaneV], (int)[i420Frame strideOfPlane:NTESI420FramePlaneV],
                           [rotatedI420Frame dataOfPlane:NTESI420FramePlaneY], (int)[rotatedI420Frame strideOfPlane:NTESI420FramePlaneY],
                           [rotatedI420Frame dataOfPlane:NTESI420FramePlaneU], (int)[rotatedI420Frame strideOfPlane:NTESI420FramePlaneU],
                           [rotatedI420Frame dataOfPlane:NTESI420FramePlaneV], (int)[rotatedI420Frame strideOfPlane:NTESI420FramePlaneV],
                           i420Frame.width, i420Frame.height,
                           rotateMode);
        i420Frame = rotatedI420Frame;
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return i420Frame;
}

+ (NTESI420Frame *)pixelBufferToI420:(CVImageBufferRef)pixelBuffer {
    return [self pixelBufferToI420:pixelBuffer scale:1];
}

+ (NTESI420Frame *)pixelBufferToI420:(CVPixelBufferRef)pixelBuffer scale:(CGFloat)scale {
    if (pixelBuffer == NULL) {
        return nil;
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);

    size_t bufferWidth = 0;
    size_t bufferHeight = 0;
    size_t rowSize = 0;
    uint8_t *pixel = NULL;

    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        int basePlane = 0;
        pixel = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, basePlane);
        bufferHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, basePlane);
        bufferWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, basePlane);
        rowSize = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, basePlane);
    } else {
        pixel = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
        bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
        rowSize = CVPixelBufferGetBytesPerRow(pixelBuffer);
    }
    NTESI420Frame *convertedI420Frame = [[NTESI420Frame alloc] initWithWidth:(int)bufferWidth height:(int)bufferHeight];

    int error = -1;
    if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
        error = libyuv::ARGBToI420(
            pixel, (int)rowSize,
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneY], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneY],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneU], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneU],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneV], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneV],
            (int)bufferWidth, (int)bufferHeight);
    } else if (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange == sourcePixelFormat || kCVPixelFormatType_420YpCbCr8BiPlanarFullRange == sourcePixelFormat) {
        error = libyuv::NV12ToI420(
            pixel,
            (int)rowSize,
            (const uint8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
            (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1),
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneY],
            (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneY],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneU],
            (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneU],
            [convertedI420Frame dataOfPlane:NTESI420FramePlaneV],
            (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneV],
            (int)bufferWidth,
            (int)bufferHeight);
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    if (error) {
        NSLog(@"error convert pixel buffer to i420 with error %d", error);
        return nil;
    }
    if (scale == 1.0) {
        return convertedI420Frame;
    }
    //缩放
    int width = bufferWidth * scale;
    width &= 0xFFFFFFFE;
    int height = bufferHeight * scale;
    height &= 0xFFFFFFFE;

    NTESI420Frame *i420Frame = [[NTESI420Frame alloc] initWithWidth:width height:height];

    libyuv::I420Scale([convertedI420Frame dataOfPlane:NTESI420FramePlaneY], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneY],
                      [convertedI420Frame dataOfPlane:NTESI420FramePlaneU], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneU],
                      [convertedI420Frame dataOfPlane:NTESI420FramePlaneV], (int)[convertedI420Frame strideOfPlane:NTESI420FramePlaneV],
                      convertedI420Frame.width, convertedI420Frame.height,
                      [i420Frame dataOfPlane:NTESI420FramePlaneY], (int)[i420Frame strideOfPlane:NTESI420FramePlaneY],
                      [i420Frame dataOfPlane:NTESI420FramePlaneU], (int)[i420Frame strideOfPlane:NTESI420FramePlaneU],
                      [i420Frame dataOfPlane:NTESI420FramePlaneV], (int)[i420Frame strideOfPlane:NTESI420FramePlaneV],
                      i420Frame.width, i420Frame.height,
                      libyuv::kFilterBilinear);

    convertedI420Frame = NULL;
    convertedI420Frame = nil;
    return i420Frame;
}

+ (CVPixelBufferRef)i420FrameToPixelBuffer:(NTESI420Frame *)i420Frame
{
    if (i420Frame == nil) {
        return NULL;
    }

    CVPixelBufferRef pixelBuffer = NULL;

    NSDictionary *pixelBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSDictionary dictionary], (id)kCVPixelBufferIOSurfacePropertiesKey,
                                           nil];

    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          i420Frame.width,
                                          i420Frame.height,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)pixelBufferAttributes,
                                          &pixelBuffer);

    if (result != kCVReturnSuccess) {
//        NVSLogErr(@"Failed to create pixel buffer: %d", result);
        return NULL;
    }

    result = CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    if (result != kCVReturnSuccess) {
        CFRelease(pixelBuffer);
//        NVSLogErr(@"Failed to lock base address: %d", result);
        return NULL;
    }

    uint8 *dstY = (uint8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    int dstStrideY = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    uint8 *dstUV = (uint8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    int dstStrideUV = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

    int ret = libyuv::I420ToNV12([i420Frame dataOfPlane:NTESI420FramePlaneY], (int)[i420Frame strideOfPlane:NTESI420FramePlaneY],
                                 [i420Frame dataOfPlane:NTESI420FramePlaneU], (int)[i420Frame strideOfPlane:NTESI420FramePlaneU],
                                 [i420Frame dataOfPlane:NTESI420FramePlaneV], (int)[i420Frame strideOfPlane:NTESI420FramePlaneV],
                                 dstY, dstStrideY, dstUV, dstStrideUV,
                                 i420Frame.width, i420Frame.height);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    if (ret) {
//        NVSLogErr(@"Error converting I420 VideoFrame to NV12: %d", result);
        CFRelease(pixelBuffer);
        return NULL;
    }

    return pixelBuffer;
}

+ (libyuv::RotationModeEnum)rotateMode:(NTESVideoPackOrientation)orientation
{
    switch (orientation) {
        case NTESVideoPackOrientationPortraitUpsideDown:
            return libyuv::kRotate180;
        case NTESVideoPackOrientationLandscapeLeft:
            return libyuv::kRotate90;
        case NTESVideoPackOrientationLandscapeRight:
            return libyuv::kRotate270;
        case NTESVideoPackOrientationPortrait:
        default:
            return libyuv::kRotate0;
    }
}

+ (CMSampleBufferRef)pixelBufferToSampleBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (pixelBuffer == NULL) {
        return NULL;
    }
    CMSampleBufferRef sampleBuffer;
    CMTime frameTime = CMTimeMakeWithSeconds([[NSDate date] timeIntervalSince1970], 1000000000);
    CMSampleTimingInfo timing = { kCMTimeInvalid, frameTime, kCMTimeInvalid };
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);

    OSStatus status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    if (status != noErr) {
        NSLog(@"Failed to create sample buffer with error %@.", @(status));
    }

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);

    CVPixelBufferRelease(pixelBuffer);
    if (videoInfo) CFRelease(videoInfo);

    return sampleBuffer;
}

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>

typedef unsigned char uint8_t;

/**
 * @param src input nv12 raw data array
 * @param dst output nv12 raw data result,
 * the memory need to be allocated outside of the function
 * @param srcWidth width of the input nv12 image
 * @param srcHeight height of the input nv12 image
 * @param dstWidth
 * @param dstHeight
 */

void nv12_nearest_scale(uint8_t *__restrict src, uint8_t *__restrict dst,
                        int srcWidth, int srcHeight, int dstWidth, int
                        dstHeight) //restrict keyword is for compiler to optimize program
{
    register int sw = srcWidth;  //register keyword is for local var to accelorate
    register int sh = srcHeight;
    register int dw = dstWidth;
    register int dh = dstHeight;
    register int y, x;
    unsigned long int srcy, srcx, src_index, dst_index;
    unsigned long int xrIntFloat_16 = (sw << 16) / dw + 1; //better than float division
    unsigned long int yrIntFloat_16 = (sh << 16) / dh + 1;

    uint8_t *dst_uv = dst + dh * dw; //memory start pointer of dest uv
    uint8_t *src_uv = src + sh * sw; //memory start pointer of source uv
    uint8_t *dst_uv_yScanline;
    uint8_t *src_uv_yScanline;
    uint8_t *dst_y_slice = dst; //memory start pointer of dest y
    uint8_t *src_y_slice;
    uint8_t *sp;
    uint8_t *dp;

    for (y = 0; y < (dh & ~7); ++y) { //'dh & ~7' is to generate faster assembly code
        srcy = (y * yrIntFloat_16) >> 16;
        src_y_slice = src + srcy * sw;

        if ((y & 1) == 0) {
            dst_uv_yScanline = dst_uv + (y / 2) * dw;
            src_uv_yScanline = src_uv + (srcy / 2) * sw;
        }

        for (x = 0; x < (dw & ~7); ++x) {
            srcx = (x * xrIntFloat_16) >> 16;
            dst_y_slice[x] = src_y_slice[srcx];

            if ((y & 1) == 0) { //y is even
                if ((x & 1) == 0) { //x is even
                    src_index = (srcx / 2) * 2;

                    sp = dst_uv_yScanline + x;
                    dp = src_uv_yScanline + src_index;
                    *sp = *dp;
                    ++sp;
                    ++dp;
                    *sp = *dp;
                }
            }
        }
        dst_y_slice += dw;
    }
}

void nv12_bilinear_scale(uint8_t *src, uint8_t *dst,
                         int srcWidth, int srcHeight, int dstWidth, int dstHeight)
{
    int x, y;
    int ox, oy;
    int tmpx, tmpy;
    int xratio = (srcWidth << 8) / dstWidth;
    int yratio = (srcHeight << 8) / dstHeight;
    uint8_t *dst_y = dst;
    uint8_t *dst_uv = dst + dstHeight * dstWidth;
    uint8_t *src_y = src;
    uint8_t *src_uv = src + srcHeight * srcWidth;

    uint8_t y_plane_color[2][2];
    uint8_t u_plane_color[2][2];
    uint8_t v_plane_color[2][2];
    int j, i;
    int size = srcWidth * srcHeight;
    int offsetY;
    int y_final, u_final, v_final;
    int u_final1 = 0;
    int v_final1 = 0;
    int u_final2 = 0;
    int v_final2 = 0;
    int u_final3 = 0;
    int v_final3 = 0;
    int u_final4 = 0;
    int v_final4 = 0;
    int u_sum = 0;
    int v_sum = 0;

    tmpy = 0;
    for (j = 0; j < (dstHeight & ~7); ++j) {
        //tmpy = j * yratio;
        oy = tmpy >> 8;
        y = tmpy & 0xFF;

        tmpx = 0;
        for (i = 0; i < (dstWidth & ~7); ++i) {
            // tmpx = i * xratio;
            ox = tmpx >> 8;
            x = tmpx & 0xFF;

            offsetY = oy * srcWidth;
            //YYYYYYYYYYYYYYYY
            y_plane_color[0][0] = src[ offsetY + ox ];
            y_plane_color[1][0] = src[ offsetY + ox + 1 ];
            y_plane_color[0][1] = src[ offsetY + srcWidth + ox ];
            y_plane_color[1][1] = src[ offsetY + srcWidth + ox + 1 ];

            int y_final = (0x100 - x) * (0x100 - y) * y_plane_color[0][0]
                + x * (0x100 - y) * y_plane_color[1][0]
                + (0x100 - x) * y * y_plane_color[0][1]
                + x * y * y_plane_color[1][1];
            y_final = y_final >> 16;
            if (y_final > 255) y_final = 255;
            if (y_final < 0) y_final = 0;
            dst_y[ j * dstWidth + i] = (uint8_t)y_final; //set Y in dest array
            //UVUVUVUVUVUV
            if ((j & 1) == 0) { //j is even
                if ((i & 1) == 0) { //i is even
                    u_plane_color[0][0] = src[ size + offsetY + ox ];
                    u_plane_color[1][0] = src[ size + offsetY + ox ];
                    u_plane_color[0][1] = src[ size + offsetY + ox ];
                    u_plane_color[1][1] = src[ size + offsetY + ox ];

                    v_plane_color[0][0] = src[ size + offsetY + ox + 1];
                    v_plane_color[1][0] = src[ size + offsetY + ox + 1];
                    v_plane_color[0][1] = src[ size + offsetY + ox + 1];
                    v_plane_color[1][1] = src[ size + offsetY + ox + 1];
                } else { //i is odd
                    u_plane_color[0][0] = src[ size + offsetY + ox - 1 ];
                    u_plane_color[1][0] = src[ size + offsetY + ox + 1 ];
                    u_plane_color[0][1] = src[ size + offsetY + ox - 1 ];
                    u_plane_color[1][1] = src[ size + offsetY + ox + 1 ];

                    v_plane_color[0][0] = src[ size + offsetY + ox ];
                    v_plane_color[1][0] = src[ size + offsetY + ox + 1 ];
                    v_plane_color[0][1] = src[ size + offsetY + ox ];
                    v_plane_color[1][1] = src[ size + offsetY + ox + 1 ];
                }
            } else { // j is odd
                if ((i & 1) == 0) { //i is even
                    u_plane_color[0][0] = src[ size + offsetY + ox ];
                    u_plane_color[1][0] = src[ size + offsetY + ox ];
                    u_plane_color[0][1] = src[ size + offsetY + srcWidth + ox ];
                    u_plane_color[1][1] = src[ size + offsetY + srcWidth + ox ];

                    v_plane_color[0][0] = src[ size + offsetY + ox + 1];
                    v_plane_color[1][0] = src[ size + offsetY + ox + 1];
                    v_plane_color[0][1] = src[ size + offsetY + srcWidth + ox + 1];
                    v_plane_color[1][1] = src[ size + offsetY + srcWidth + ox + 1];
                } else { //i is odd
                    u_plane_color[0][0] = src[ size + offsetY + ox - 1 ];
                    u_plane_color[1][0] = src[ size + offsetY + srcWidth + ox - 1 ];
                    u_plane_color[0][1] = src[ size + offsetY + ox + 1];
                    u_plane_color[1][1] = src[ size + offsetY + srcWidth + ox + 1];

                    v_plane_color[0][0] = src[ size + offsetY + ox ];
                    v_plane_color[1][0] = src[ size + offsetY + srcWidth + ox ];
                    v_plane_color[0][1] = src[ size + offsetY + ox + 2 ];
                    v_plane_color[1][1] = src[ size + offsetY + srcWidth + ox + 2 ];
                }
            }

            int u_final = (0x100 - x) * (0x100 - y) * u_plane_color[0][0]
                + x * (0x100 - y) * u_plane_color[1][0]
                + (0x100 - x) * y * u_plane_color[0][1]
                + x * y * u_plane_color[1][1];
            u_final = u_final >> 16;

            int v_final = (0x100 - x) * (0x100 - y) * v_plane_color[0][0]
                + x * (0x100 - y) * v_plane_color[1][0]
                + (0x100 - x) * y * v_plane_color[0][1]
                + x * y * v_plane_color[1][1];
            v_final = v_final >> 16;
            if ((j & 1) == 0) {
                if ((i & 1) == 0) {
                    //set U in dest array
                    dst_uv[(j / 2) * dstWidth + i ] = (uint8_t)(u_sum / 4);
                    //set V in dest array
                    dst_uv[(j / 2) * dstWidth + i + 1] = (uint8_t)(v_sum / 4);
                    u_sum = 0;
                    v_sum = 0;
                }
            } else {
                u_sum += u_final;
                v_sum += v_final;
            }
            tmpx += xratio;
        }
        tmpy += yratio;
    }
}

int ImageResize(uint8_t *src, uint8_t *dst, int sw,
                int sh, int dw, int dh)
{
    if ( (src == NULL) || (dst == NULL) || (0 == dw) || (0 == dh) ||
         (0 == sw) || (0 == sh)) {
        printf("params error\n");
        return -1;
    }
    nv12_nearest_scale(src, dst, sw, sh, dw, dh);
    //nv12_bilinear_scale(src, dst, sw, sh, dw, dh);
    //greyscale(src, dst, sw, sh, dw, dh);
    return 0;
}

@end
