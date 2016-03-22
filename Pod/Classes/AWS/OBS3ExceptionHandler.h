//
//  OBS3ExceptionHandler.h
//  Pods
//
//  Created by Rinat on 21/03/16.
//
//

#import <Foundation/Foundation.h>

@interface OBS3ExceptionHandler : NSObject

- (void)addResponse:(NSData *)data forTask:(NSURLSessionTask *)task;
- (void)removeResponseForTask:(NSURLSessionTask *)task;
- (BOOL)isRetryableExceptionFromTask:(NSURLSessionTask *)task;

@end
