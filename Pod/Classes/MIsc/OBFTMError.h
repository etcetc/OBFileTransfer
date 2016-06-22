//
//  OBFTMError.h
//  Pods
//
//  Created by Farhad on 8/28/14.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OBFTMErrorCode)
{
    OBFTMUnknownError = -1,
    OBFTMTmpFileCreateError = -2,
    OBFTMTmpDownloadFileCopyError = -3,
    OBFTMTmpFileDeleteError = -4
};

@interface OBFTMError : NSObject

+ (NSString *)errorDomain;

+ (NSString *)localizedDescription:(OBFTMErrorCode)errorCode;


@end
