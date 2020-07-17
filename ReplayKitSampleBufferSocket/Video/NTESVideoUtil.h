//
//
//  Created by fenric on 17/3/20.
//  Copyright © 2017年 Netease. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMFormatDescription.h>

@interface NTESVideoUtil : NSObject

+ (CMVideoDimensions)outputVideoDimens:(CMVideoDimensions)inputDimens
                                  crop:(float)ratio;

+ (CMVideoDimensions)calculateDiemnsDividedByTwo:(int)width andHeight:(int)height;

+ (CMVideoDimensions)outputVideoDimensEnhanced:(CMVideoDimensions)inputDimens crop:(float)ratio;
@end
