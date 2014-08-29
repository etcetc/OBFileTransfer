//
//  OBFTMError.m
//  Pods
//
//  Created by Farhad on 8/28/14.
//
//

#import "OBFTMError.h"

@implementation OBFTMError

+(NSString *) errorDomain
{
    return @"com.onebeat.fileTransferModule";
}

// TODO - to make this localized I need to put the strings into a bundle
//    and localize the string on the bundle.  It's a lot of work.  Will do it later.
+(NSString *) localizedDescription: (OBFTMErrorCode) errorCode
{
    NSString *key, *description;
    switch (errorCode) {
        case OBFTMTmpFileCreateError:
            key = @"OBFTMTmpFileCreateError";
            description = @"Unable to create temporary file";
            break;
            
        case OBFTMTmpFileDeleteError:
            key = @"OBFTMTmpFileDeleteError";
            description = @"Unable to delete temporary file";
            break;
        
        case OBFTMTmpDownloadFileCopyError:
            key = @"OBFTMTmpDownloadFileCopyError";
            description = @"Unable to copy downloaded file to asked-for location";
            break;
            
        default:
            key = @"OBFTMUnknownError";
            description = @"Unknown error";
            break;
    }
//    return NSLocalizedString(key, nil);
    return description;
}

@end
