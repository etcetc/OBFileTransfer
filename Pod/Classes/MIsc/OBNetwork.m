//
//  OBNetwork.m
//  Pods
//
//  Created by Farhad on 8/26/14.
//
//

#import "OBNetwork.h"
#include<netdb.h>

@implementation OBNetwork

+ (BOOL)isInternetAvailable
{
    return [self isReachable:@"google.com"];
}

+ (BOOL)isReachable:(NSString *)domain
{
    struct hostent *hostinfo;
    hostinfo = gethostbyname([domain UTF8String]);
    return hostinfo == NULL ? NO : YES;
}

@end
