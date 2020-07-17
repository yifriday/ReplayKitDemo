//
//
//  Created by fenric on 17/3/20.
//  Copyright © 2017年 Netease. All rights reserved.
//

#import "NTESVideoUtil.h"

#define NVSVideoUtilCropWidthAlignment 2

@implementation NTESVideoUtil


+ (CMVideoDimensions)outputVideoDimensEnhanced:(CMVideoDimensions)inputDimens crop:(float)ratio
{
    inputDimens.width >>= 1;
    inputDimens.width <<= 1;
    inputDimens.height >>= 1;
    inputDimens.height <<= 1;
    if (ratio <= 0 || ratio > 1) {
        return inputDimens;
    }
    

    CMVideoDimensions outputDimens  = {0,0};
    
    int cropW,cropH,sw,sh;
    sw = inputDimens.width;
    sh = inputDimens.height;
    
    if(sw/sh == ratio) {
        outputDimens.width = inputDimens.width;
        outputDimens.height = inputDimens.height;
        return outputDimens;
    }
    
    if(sw/sh < ratio) {
        for(cropW = 0; cropW < sw; cropW += 2) {
            for(cropH = 0; cropH < sh; cropH += 2) {
                if((sw - cropW) == ratio * (sh - cropH)) {
                    outputDimens.height = sh - cropH;
                    outputDimens.width = sw - cropW;
                    
                    return outputDimens;
                }
            }
        }
    }else{
        for(cropH = 0; cropH < sh; cropH += 2) {
            for(cropW = 0; cropW < sw; cropW += 2) {
                if((sw - cropW) == ratio * (sh - cropH)) {
                    outputDimens.height = sh - cropH;
                    outputDimens.width = sw - cropW;
                
                    return outputDimens;
                }
            }
        }
    }
    return outputDimens;
}

+ (CMVideoDimensions)outputVideoDimens:(CMVideoDimensions)inputDimens crop:(float)ratio
{
    if (ratio <= 0 || ratio > 1) {
        return inputDimens;
    }
    
    CMVideoDimensions outputDimens  = inputDimens;
    
    if (inputDimens.width > inputDimens.height) {
        if (inputDimens.width * ratio > inputDimens.height) {
            outputDimens.width = inputDimens.height / ratio;
        }
        else {
            outputDimens.height = inputDimens.width * ratio;
        }
    }
    else {
        if (inputDimens.height * ratio > inputDimens.width) {
            outputDimens.height = inputDimens.width / ratio;
        }
        else {
            outputDimens.width = inputDimens.height * ratio;
        }
    }
    
    int32_t mod = outputDimens.width % NVSVideoUtilCropWidthAlignment;
    
    if (mod) {
        outputDimens.width -= mod;
    }

    mod = outputDimens.height % NVSVideoUtilCropWidthAlignment;

    if (mod) {
        outputDimens.height -= mod;
    }
    
    return outputDimens;
}

+ (CMVideoDimensions)calculateDiemnsDividedByTwo:(int)width andHeight:(int)height
{
    CMVideoDimensions dimens = {width,height};
    int32_t mod = dimens.width % NVSVideoUtilCropWidthAlignment;
    if (mod) {
        dimens.width -= mod;
    }
    
    mod = dimens.height % NVSVideoUtilCropWidthAlignment;
    
    if (mod) {
        dimens.height -= mod;
    }

    return dimens;
}

@end
