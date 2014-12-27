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

NSString * const OBS3StorageProtocol = @"s3";
NSString * const OBS3TvmServerUrlParam = @"S3TvmServerUrlParam";
NSString * const OBS3RegionParam = @"S3RegionParam";

@interface OBS3FileTransferAgent ()
@property (nonatomic,strong) NSString * tvmUrl;
@property (nonatomic) AmazonRegion awsRegion;
@end

@implementation OBS3FileTransferAgent

-(instancetype) initWithConfig:(NSDictionary *)configParams
{
    if ( [self init] ) {
        self.tvmUrl = configParams[OBS3TvmServerUrlParam];
        self.awsRegion = [self amazonRegion:configParams[OBS3RegionParam]];
        [self validateSetup];
        [AmazonClientManager setTvmServerUrl:self.tvmUrl];
        [AmazonClientManager setRegion: self.awsRegion];
    }
    return self;
}

// Create an S3 download request
- (NSMutableURLRequest *) downloadFileRequest:(NSString *)s3Url withParams:(NSDictionary *)params
{
    NSDictionary *urlComponents = [self urlToComponents:s3Url];
    S3GetObjectRequest * getRequest = [[S3GetObjectRequest alloc] initWithKey:urlComponents[@"filePath"] withBucket:urlComponents[@"bucketName"]];
    OB_INFO(@"Creating S3 download file request from %@ ",s3Url);
    getRequest.endpoint =[AmazonClientManager s3].endpoint;
    [getRequest setSecurityToken:[AmazonClientManager securityToken]];
    NSMutableURLRequest *request = [[AmazonClientManager s3] signS3Request:getRequest];
    
    //    We have to copy over because request is actually a sublass of NSMutableREquest and can cause problems
    NSMutableURLRequest* request2 = [[NSMutableURLRequest alloc]initWithURL:request.URL];
    [request2 setHTTPMethod:request.HTTPMethod];
    [request2 setAllHTTPHeaderFields:[request allHTTPHeaderFields]];
    [request2 setAllowsCellularAccess:YES];
    [request2 setNetworkServiceType:NSURLNetworkServiceTypeBackground];
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
    
    NSDictionary *urlComponents = [self urlToComponents:s3Url];
    S3PutObjectRequest * putRequest = [[S3PutObjectRequest alloc] initWithKey:urlComponents[@"filePath"] inBucket:urlComponents[@"bucketName"]];
    OB_INFO(@"Creating S3 upload request for file %@ to %@ ",filePath,s3Url);
    putRequest.filename = filePath;
    putRequest.filename = @"/Users/ff/foo.jpg";
    putRequest.endpoint =[AmazonClientManager s3].endpoint;
    [putRequest setSecurityToken:[AmazonClientManager securityToken]];
    
    putRequest.contentType = params[ContentTypeParamKey] ? params[ContentTypeParamKey] : [self mimeTypeFromFilename:filePath];
    NSError *error;
//    NOTE - as of ios 8 it seems that I have to supply the content length or else it remains at 0 and nothing is sent
    putRequest.contentLength = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error] fileSize];
    
    NSMutableURLRequest *request = [[AmazonClientManager s3] signS3Request:putRequest];
    
    //    We have to copy over because request is actually a sublass of NSMutableREquest and can cause problems
    NSMutableURLRequest* request2 = [[NSMutableURLRequest alloc]initWithURL:request.URL];
    [request2 setHTTPMethod:request.HTTPMethod];
    [request2 setAllHTTPHeaderFields:[request allHTTPHeaderFields]];
    [request2 setAllowsCellularAccess:YES];
    [request2 setNetworkServiceType:NSURLNetworkServiceTypeBackground];
    return request2;
}

// Returns an NSDictionary with the following keys:
// bucketName: the name of the bucket
// filePath: the file path in the bucket
// Input: of form protocol://bucket-name/file-path or just bucket-name/file-path
-(NSDictionary *) urlToComponents: (NSString *) url
{
    NSString *path;
    if ( [url rangeOfString:[OBS3StorageProtocol stringByAppendingString:@"://"]].location == 0  ) {
        path = [url substringFromIndex:OBS3StorageProtocol.length + 3];
    } else {
        path = url;
    }
    //    This'll throw up if there are no /s in the input
    NSInteger firstSlash = [path rangeOfString:@"/"].location;
    return @{@"bucketName":[path substringToIndex:firstSlash], @"filePath": [path substringFromIndex:firstSlash+1]};
}


-(BOOL) hasMultipartBody
{
    return NO;
}

-(void) validateSetup
{
    NSAssert(self.tvmUrl != nil, @"The TVM Url must be specified");
}

-(AmazonRegion) amazonRegion: (NSString *)region
{
    NSString *lcRegion = [region lowercaseString];
    AmazonRegion awsRegion;
    if ( region == nil )
        return US_EAST_1;
    
    if ( [lcRegion isEqualToString:@"us_east_1"] )
        awsRegion = US_EAST_1;
    else if ( [lcRegion isEqualToString:@"us_west_1"] )
        awsRegion = US_WEST_1;
    else if ( [lcRegion isEqualToString:@"us_west_2"] )
        awsRegion = US_WEST_2;
    else if ( [lcRegion isEqualToString:@"ap_southeast_1"] )
        awsRegion = AP_SOUTHEAST_1;
    else if ( [lcRegion isEqualToString:@"ap_southeast_2"] )
        awsRegion = AP_SOUTHEAST_2;
    else if ( [lcRegion isEqualToString:@"ap_northeast_1"] )
        awsRegion = AP_NORTHEAST_1;
    else if ( [lcRegion isEqualToString:@"sa_east_1"] )
        awsRegion = SA_EAST_1;
    else
        [NSException raise:NSInternalInconsistencyException format:@"Unknown AWS Region specified: %@",region];
    return awsRegion;
}

@end
