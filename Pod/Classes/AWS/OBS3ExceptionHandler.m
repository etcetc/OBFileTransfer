//
//  OBS3ExceptionHandler.m
//  Pods
//
//  Created by Rinat on 21/03/16.
//
//

#import "OBS3ExceptionHandler.h"
#import "S3ErrorResponseHandler.h"
#import "AmazonClientManager.h"
#import <OBLogger/OBLogger.h>


static NSString *RequestTimeTooSkewedErrorCode = @"RequestTimeTooSkewed";
static NSString *MIMEApplicationXML = @"application/xml";

@interface OBS3ExceptionHandler ()

@property (nonatomic, strong, readonly) NSMutableDictionary <NSURLSessionTask *, AmazonServiceException *> *exceptions;

@end

@implementation OBS3ExceptionHandler

#pragma mark S3 exceptions

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _exceptions = [NSMutableDictionary new];
    }
    return self;
}

- (void)addResponse:(NSData *)data forTask:(NSURLSessionTask *)task
{
    if (data.length == 0)
    {
        return;
    }

    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;

    if ([response.MIMEType isEqualToString:MIMEApplicationXML]) // S3 returns detailed desciptions for errors encoded in XML
    {
        if ((response.statusCode == 301) || (response.statusCode >= 400))
        {
            NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
            S3ErrorResponseHandler *errorHandler =
                    [[S3ErrorResponseHandler alloc] initWithStatusCode:(int32_t)response.statusCode];
            [parser setDelegate:errorHandler];
            [parser parse];

            AmazonServiceException *exception = errorHandler.exception;

            if (exception)
            {
                OB_ERROR(@"Amazon S3 exception: %@", exception);
                self.exceptions[task] = exception;

                [self _handleExceptionForTask:task];
            }
        }
    }
}

- (void)removeResponseForTask:(NSURLSessionTask *)task
{
    [self.exceptions removeObjectForKey:task];
}

- (BOOL)isRetryableExceptionFromTask:(NSURLSessionTask *)task;
{
    AmazonServiceException *exception = self.exceptions[task];

    if (!exception)
    {
        return NO;
    }

    if ([exception.errorCode isEqualToString:RequestTimeTooSkewedErrorCode])
    {
        return YES;
    }

    return NO;
}

- (void)_handleExceptionForTask:(NSURLSessionTask *)task
{
    AmazonServiceException *exception = self.exceptions[task];

    if (!exception)
    {
        return;
    }

    if ([exception.errorCode isEqualToString:RequestTimeTooSkewedErrorCode])
    {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        [self _adjustClockWithResponse:response];
    }
}

- (void)_adjustClockWithResponse:(NSHTTPURLResponse *)response
{
    NSString *dateString = response.allHeaderFields[@"date"];
    NSDate *date = [[self _RFC1123DateFormatter] dateFromString:dateString];
    NSTimeInterval offset = [[NSDate date] timeIntervalSinceDate:date];
    [AmazonClientManager setTimeOffset:offset];
    OB_WARN(@"Amazon S3 clock offset adjusted: %1.0f", offset);
}

- (NSDateFormatter *)_RFC1123DateFormatter
{
    static NSDateFormatter *formatter;
    if (!formatter)
    {
        formatter = [NSDateFormatter new];
        [formatter setDateFormat:@"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"];
        [formatter setLenient:false];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    }
    return formatter;
}


@end
