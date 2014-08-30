//
//  OBS3FileTransferAgent.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/26/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBS3FileTransferAgent.h"
#import <AWSS3/AWSS3.h>
#import <OBLogger/OBLogger.h>
#import "AmazonClientManager.h"

@implementation OBS3FileTransferAgent

// Create an S3 download request
// params are ignored
- (NSMutableURLRequest *) downloadFileRequest:(NSString *)s3Url withParams:(NSDictionary *)params
{
    NSDictionary *urlComponents = [self s3UrlToComponents:s3Url];
    S3GetObjectRequest * getRequest = [[S3GetObjectRequest alloc] initWithKey:urlComponents[@"filePath"] withBucket:urlComponents[@"bucketName"]];
    OB_INFO(@"Creating S3 download file request from %@ ",s3Url);
    getRequest.endpoint =[AmazonClientManager s3].endpoint;
    [getRequest setSecurityToken:[AmazonClientManager securityToken]];
    NSMutableURLRequest *request = [[AmazonClientManager s3] signS3Request:getRequest];
    
    //    We have to copy over because request is actually a sublass of NSMutableREquest and can cause problems
    NSMutableURLRequest* request2 = [[NSMutableURLRequest alloc]initWithURL:request.URL];
    [request2 setHTTPMethod:request.HTTPMethod];
    [request2 setAllHTTPHeaderFields:[request allHTTPHeaderFields]];
    return request2;
}

// Upload the file to S3
// The to: parameter is the path of the file in the bucket
//
// NOTE:
//   The to: field is the directory structure - does not include the target filename!
//   params actually contains header and parameter information for the request
//   parameters that start with underscore (_) are special.
//   We currently only look at _contentType
-(NSMutableURLRequest *) uploadFileRequest:(NSString *)filePath to:(NSString *)s3Url withParams:(NSDictionary *)params
{
    if ( s3Url == nil ) s3Url = @"";
    NSString *filename = params[FilenameParamKey] == nil ? [[filePath pathComponents] lastObject] : params[FilenameParamKey];
    if ( ![s3Url hasSuffix:@"/"] )
        s3Url = [s3Url stringByAppendingString:@"/"];
    
    if ( [filename hasPrefix:@"/"] )
        s3Url = [s3Url stringByAppendingString:[filename substringFromIndex:1]];
    else
        s3Url =[s3Url stringByAppendingString:filename];
    
    NSDictionary *urlComponents = [self s3UrlToComponents:s3Url];
    S3PutObjectRequest * putRequest = [[S3PutObjectRequest alloc] initWithKey:urlComponents[@"filePath"] inBucket:urlComponents[@"bucketName"]];
    OB_INFO(@"Creating S3 upload request for file %@ to %@ ",filePath,s3Url);
    putRequest.filename = filePath;
    putRequest.endpoint =[AmazonClientManager s3].endpoint;
    [putRequest setSecurityToken:[AmazonClientManager securityToken]];
    
    putRequest.contentType = params[ContentTypeParamKey] ? params[ContentTypeParamKey] : [self mimeTypeFromFilename:filePath];
    NSMutableURLRequest *request = [[AmazonClientManager s3] signS3Request:putRequest];
    
    //    We have to copy over because request is actually a sublass of NSMutableREquest and can cause problems
    NSMutableURLRequest* request2 = [[NSMutableURLRequest alloc]initWithURL:request.URL];
    [request2 setHTTPMethod:request.HTTPMethod];
    [request2 setAllHTTPHeaderFields:[request allHTTPHeaderFields]];
    return request2;
}

// Returns an NSDictionary with the following keys:
// bucketName: the name of the bucket
// filePath: the file path in the bucket
// Input: of form s3://bucket-name/file-path or just bucket-name/file-path
-(NSDictionary *) s3UrlToComponents: (NSString *) s3Url
{
    NSString *path;
    if ( [[s3Url substringToIndex:5] isEqualToString:@"s3://"] ) {
        path = [s3Url substringFromIndex:5];
    } else {
        path = s3Url;
    }
//    This'll throw up if there are no /s in the input
    NSInteger firstSlash = [path rangeOfString:@"/"].location;
    return @{@"bucketName":[path substringToIndex:firstSlash], @"filePath": [path substringFromIndex:firstSlash+1]};
}

-(BOOL) hasMultipartBody
{
    return NO;
}


@end
