//
//  OBS3FileTransferAgent.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/26/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBS3FileTransferAgent.h"
#import <AWSS3/AWSS3.h>
#import "AmazonClientManager.h"

NSString *const OBS3StorageProtocol = @"s3";
NSString *const OBS3TvmServerUrlParam = @"S3TvmServerUrlParam";
NSString *const OBS3RegionParam = @"S3RegionParam";
NSString *const OBS3NoTvmAccessKeyParam = @"S3NoTvmAccessKeyParam";
NSString *const OBS3NoTvmSecretKeyParam = @"S3NoTvmSecretKeyParam";
NSString *const OBS3NoTvmSecurityTokenParam = @"S3NoTvmSecurityTokenParam";

@interface OBS3FileTransferAgent ()
@property (nonatomic, strong) NSString *tvmUrl;
@property (nonatomic) AmazonRegion awsRegion;
@end

@implementation OBS3FileTransferAgent

- (instancetype)initWithConfig:(NSDictionary *)configParams
{
    if ([self init])
    {
        self.tvmUrl = configParams[OBS3TvmServerUrlParam];
        self.awsRegion = [self amazonRegion:configParams[OBS3RegionParam]];
        [self validateSetup];
        [AmazonClientManager setTvmServerUrl:self.tvmUrl];
        [AmazonClientManager setNoTvmCredentials:[self noTvmCredentials:configParams]];
        [AmazonClientManager setRegion:self.awsRegion];
    }
    return self;
}

- (AmazonCredentials *)noTvmCredentials:(NSDictionary *)configParams
{
    if (configParams[OBS3NoTvmAccessKeyParam] == nil || configParams[OBS3NoTvmSecretKeyParam] == nil)
        return nil;

    return [[AmazonCredentials alloc] initWithAccessKey:configParams[OBS3NoTvmAccessKeyParam]
                                          withSecretKey:configParams[OBS3NoTvmSecretKeyParam]
                                      withSecurityToken:configParams[OBS3NoTvmSecurityTokenParam]];
}

// Create an S3 download request
- (NSMutableURLRequest *)downloadFileRequest:(NSString *)s3Url withParams:(NSDictionary *)params
{
    NSDictionary *urlComponents = [self urlToComponents:s3Url];
    NSString *filename;
    if (params[FilenameParamKey] != nil)
        filename = params[FilenameParamKey];
    else
        filename = urlComponents[@"filename"];

    OB_INFO(@"Creating S3 download file request from bucket:%@ key:%@", urlComponents[@"bucketName"], filename);

    S3GetPreSignedURLRequest *getRequest = [S3GetPreSignedURLRequest new];
    getRequest.key = filename;
    getRequest.bucket = urlComponents[@"bucketName"];
    getRequest.expires = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 7]; // 7 days
    getRequest.endpoint = [AmazonClientManager s3].endpoint;
    [getRequest setSecurityToken:[AmazonClientManager securityToken]];
    getRequest.protocol = @"https";

    NSURL *url = [[AmazonClientManager s3] getPreSignedURL:getRequest];

    NSMutableURLRequest *request = [NSMutableURLRequest new];
    request.HTTPMethod = @"GET";
    request.URL = url;
    return request;
}

// Upload the file to S3
// NOTE:
//   params actually contains header and parameter information for the request
//   parameters that start with underscore (_) are special.
//   We currently only look at _contentType
- (NSMutableURLRequest *)uploadFileRequest:(NSString *)filePath to:(NSString *)s3Url withParams:(NSDictionary *)params
{
    if (s3Url == nil) s3Url = @""; // Not sure what special case this is here for.

    NSDictionary *urlComponents = [self urlToComponents:s3Url];

    NSString *filename;
    if (params[FilenameParamKey] != nil)
        filename = params[FilenameParamKey];
    else if (urlComponents[@"filename"] != nil)
        filename = urlComponents[@"filename"];
    else
        filename = [[filePath pathComponents] lastObject];

    S3PutObjectRequest *putRequest = [[S3PutObjectRequest alloc] initWithKey:filename
                                                                    inBucket:urlComponents[@"bucketName"]];

    OB_INFO(@"Creating S3 upload request for file %@ to bucket: %@, key: %@", filePath, urlComponents[@"bucketName"], filename);
    putRequest.filename = filePath;  // Is this used for anything?
    putRequest.endpoint = [AmazonClientManager s3].endpoint;
    putRequest.securityToken = [AmazonClientManager securityToken];
    putRequest.contentType = params[ContentTypeParamKey] ? params[ContentTypeParamKey] : [self mimeTypeFromFilename:filePath];

    [self addMetadataToS3PutObjectRequest:putRequest params:params];

    // NOTE - as of ios 8 it seems that I have to supply the content length or else it remains at 0 and nothing is sent
    NSError *error;
    putRequest.contentLength = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error] fileSize];

    NSMutableURLRequest *request = [[AmazonClientManager s3] signS3Request:putRequest];

    // We have to copy over because request is actually a sublass of NSMutableRequest and can cause problems
    NSMutableURLRequest *request2 = [[NSMutableURLRequest alloc] initWithURL:request.URL];
    [request2 setHTTPMethod:request.HTTPMethod];
    [request2 setAllHTTPHeaderFields:[request allHTTPHeaderFields]];

    return request2;
}

- (NSError *)deleteFile:(NSString *)s3Url
{
    NSDictionary *urlComponents = [self urlToComponents:s3Url];
    OB_INFO(@"Deleting S3 file bucket:%@ file:%@", urlComponents[@"bucketName"], urlComponents[@"filename"]);
    S3DeleteObjectRequest *request = [[S3DeleteObjectRequest alloc] init];
    request.key = urlComponents[@"filename"];
    request.bucket = urlComponents[@"bucketName"];
    request.endpoint = [AmazonClientManager s3].endpoint;
    request.securityToken = [AmazonClientManager securityToken];
    NSError *error = nil;
    @try
    {
        [[AmazonClientManager s3] deleteObject:request];
    }
    @catch (AmazonServiceException *e)
    {
        error = [NSError errorWithDomain:NSURLErrorDomain
                                    code:e.statusCode
                                userInfo:@{NSLocalizedDescriptionKey : e.message}];
    }
    return error;
}

// Returns an NSDictionary with the following keys:
// bucketName: the name of the bucket
// filePath: the file path in the bucket
// Input: of form protocol://bucket-name/file-path or just bucket-name/file-path
- (NSDictionary *)urlToComponents:(NSString *)url
{
    NSString *path;
    if ([url rangeOfString:[OBS3StorageProtocol stringByAppendingString:@"://"]].location == 0)
    {
        path = [url substringFromIndex:OBS3StorageProtocol.length + 3];
    }
    else
    {
        path = url;
    }

    NSInteger firstSlash = [path rangeOfString:@"/"].location;
    if (firstSlash == NSNotFound)
        return @{@"bucketName" : path};
    else
        return @{@"bucketName" : [path substringToIndex:firstSlash], @"filename" : [path substringFromIndex:firstSlash + 1]};
}


- (BOOL)hasMultipartBody
{
    return NO;
}

- (void)validateSetup
{
}

- (AmazonRegion)amazonRegion:(NSString *)region
{
    NSString *lcRegion = [region lowercaseString];
    AmazonRegion awsRegion;
    if (region == nil)
        return US_EAST_1;

    lcRegion = [lcRegion stringByReplacingOccurrencesOfString:@"_" withString:@"-"];

    if ([lcRegion isEqualToString:@"us-east-1"])
        awsRegion = US_EAST_1;
    else if ([lcRegion isEqualToString:@"us-west-1"])
        awsRegion = US_WEST_1;
    else if ([lcRegion isEqualToString:@"us-west-2"])
        awsRegion = US_WEST_2;
    else if ([lcRegion isEqualToString:@"ap-southeast-1"])
        awsRegion = AP_SOUTHEAST_1;
    else if ([lcRegion isEqualToString:@"ap-southeast-2"])
        awsRegion = AP_SOUTHEAST_2;
    else if ([lcRegion isEqualToString:@"ap-northeast-1"])
        awsRegion = AP_NORTHEAST_1;
    else if ([lcRegion isEqualToString:@"sa-east-1"])
        awsRegion = SA_EAST_1;
    else
    {
        OB_ERROR(@"Unknown AWS Region specified: %@", region);
        awsRegion = US_EAST_1;
    }
    return awsRegion;
}

- (void)addMetadataToS3PutObjectRequest:(S3PutObjectRequest *)request params:(NSDictionary *)params
{
    NSDictionary *metadataDictionary = params[kOBFileTransferMetadataKey];
    for (NSString *key in metadataDictionary)
    {
        [request addMetadataWithValue:metadataDictionary[key] forKey:key];
    }
}

@end
