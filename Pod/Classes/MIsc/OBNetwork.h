//
//  OBNetwork.h
//  Pods
//
//  Created by Farhad on 8/26/14.
//
//

#import <Foundation/Foundation.h>

@interface OBNetwork : NSObject

+ (BOOL)isInternetAvailable;

+ (BOOL)isReachable:(NSString *)domain;

@end
