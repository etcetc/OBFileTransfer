/*
 * Copyright 2010-2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "AmazonClientManager.h"
#import "AmazonKeyChainWrapper.h"
#import "AmazonTVMClient.h"
#import "OBLogger.h"
#import <AWSRuntime/AmazonSDKUtil.h>
#import "OBSystemTimeObserver.h"

static AmazonS3Client       *s3  = nil;
static AmazonTVMClient      * _tvm = nil;
static AmazonRegion _awsRegion;
static AmazonCredentials * _noTvmCredentials = nil;

NSString * const kAmazonTokenHeader = @"x-amz-security-token";

@interface AmazonClientManager ()
@end

@implementation AmazonClientManager

+ (AmazonS3Client *)s3
{
    [AmazonClientManager validateCredentials];
    [self observeClockChanges];
    return s3;
}

+ (void)observeClockChanges
{
    static OBSystemTimeObserver *observer;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        observer = [OBSystemTimeObserver new];
        [observer startObserving];
    });
}

+ (void)setTvmServerUrl: (NSString *) tvmServerUrl;
{
    if (tvmServerUrl == nil || [tvmServerUrl isEqualToString:@""]){
        OB_INFO(@"Using S3 without TokenVendingMachine");
        _tvm = nil;
        return;
    }
    
    // TODO - will want to use SSL later
    if ( _tvm == nil || ![_tvm.endpoint isEqualToString:tvmServerUrl] ) {
        OB_INFO(@"Using S3 with TokenVendingMachine");
        _tvm = [[AmazonTVMClient alloc] initWithEndpoint:tvmServerUrl useSSL:NO];
    }
}

+(void)setNoTvmCredentials:(AmazonCredentials *)credentials{
    _noTvmCredentials = credentials;
}

+(AmazonTVMClient *) tvm
{
    return _tvm;
}

+(void) setRegion: (AmazonRegion) region
{
    _awsRegion = region;
}

+(void)setTimeOffset:(NSTimeInterval)offset
{
    [AmazonSDKUtil setRuntimeClockSkew:offset];
}

+(Response *)validateCredentials
{
    Response *ableToGetToken = [[Response alloc] initWithCode:200 andMessage:@"OK"];
    
    if (_tvm != nil && [AmazonKeyChainWrapper areCredentialsExpired]) {
        
        @synchronized(self)
        {
            if ([AmazonKeyChainWrapper areCredentialsExpired]) {
                
                ableToGetToken = [[AmazonClientManager tvm] anonymousRegister];
                
                if ( [ableToGetToken wasSuccessful])
                {
                    ableToGetToken = [[AmazonClientManager tvm] getToken];
                    
                    if ( [ableToGetToken wasSuccessful])
                    {
                        [AmazonClientManager initClients];
                    }
                }
            }
        }
    }
    // Always init clients if _tvm is nil so that changes in credentials made by the app to noTvm credentials take effect.
    else if ( s3 == nil || _tvm == nil)
    {
        @synchronized(self)
        {
            if (s3 == nil || _tvm == nil)
            {
                [AmazonClientManager initClients];
            }
        }
    }
    
    return ableToGetToken;
}

+(void)initClients
{
    if (_tvm != nil) {
        OB_INFO(@"Creating s3client with TvmCredentials");
        s3  = [[AmazonS3Client alloc] initWithCredentials:[AmazonKeyChainWrapper getCredentialsFromKeyChain]];
    } else {
        if (_noTvmCredentials != nil){
            OB_INFO(@"Creating s3client with noTvmCredentials");
            s3  = [[AmazonS3Client alloc] initWithCredentials:_noTvmCredentials];
        } else {
            // For publicly accessable buckets.
            OB_INFO(@"Creating s3client with NO credentials");
            s3 = [[AmazonS3Client alloc] init];
        }
    }
    
    // If _awsRegion is not set the AwsRegion enum defaults to US_EAST_1.
    s3.endpoint = [AmazonEndpoints s3Endpoint:_awsRegion];
}

+(NSString *) securityToken
{
    if (_tvm != nil)
        return [AmazonKeyChainWrapper securityToken];
    
    if (_noTvmCredentials != nil)
        return _noTvmCredentials.securityToken;
    
    return nil;
}

+(void)wipeAllCredentials
{
    @synchronized(self)
    {
        [AmazonKeyChainWrapper wipeCredentialsFromKeyChain];
        s3  = nil;
    }
}

+ (BOOL)wipeCredentialsOnAuthError:(NSError *)error
{
    id exception = [error.userInfo objectForKey:@"exception"];
    
    if([exception isKindOfClass:[AmazonServiceException class]])
    {
        AmazonServiceException *e = (AmazonServiceException *)exception;
        
        if(
           // STS http://docs.amazonwebservices.com/STS/latest/APIReference/CommonErrors.html
           [e.errorCode isEqualToString:@"IncompleteSignature"]
           || [e.errorCode isEqualToString:@"InternalFailure"]
           || [e.errorCode isEqualToString:@"InvalidClientTokenId"]
           || [e.errorCode isEqualToString:@"OptInRequired"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           || [e.errorCode isEqualToString:@"ServiceUnavailable"]
           
           // For S3 http://docs.amazonwebservices.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList
           || [e.errorCode isEqualToString:@"AccessDenied"]
           || [e.errorCode isEqualToString:@"BadDigest"]
           || [e.errorCode isEqualToString:@"CredentialsNotSupported"]
           || [e.errorCode isEqualToString:@"ExpiredToken"]
           || [e.errorCode isEqualToString:@"InternalError"]
           || [e.errorCode isEqualToString:@"InvalidAccessKeyId"]
           || [e.errorCode isEqualToString:@"InvalidPolicyDocument"]
           || [e.errorCode isEqualToString:@"InvalidToken"]
           || [e.errorCode isEqualToString:@"NotSignedUp"]
           || [e.errorCode isEqualToString:@"RequestTimeTooSkewed"]
           || [e.errorCode isEqualToString:@"SignatureDoesNotMatch"]
           || [e.errorCode isEqualToString:@"TokenRefreshRequired"]
           
           // SimpleDB http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/APIError.html
           || [e.errorCode isEqualToString:@"AccessFailure"]
           || [e.errorCode isEqualToString:@"AuthFailure"]
           || [e.errorCode isEqualToString:@"AuthMissingFailure"]
           || [e.errorCode isEqualToString:@"InternalError"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           
           // SNS http://docs.amazonwebservices.com/sns/latest/api/CommonErrors.html
           || [e.errorCode isEqualToString:@"IncompleteSignature"]
           || [e.errorCode isEqualToString:@"InternalFailure"]
           || [e.errorCode isEqualToString:@"InvalidClientTokenId"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           
           // SQS http://docs.amazonwebservices.com/AWSSimpleQueueService/2011-10-01/APIReference/Query_QueryErrors.html#list-of-errors
           || [e.errorCode isEqualToString:@"AccessDenied"]
           || [e.errorCode isEqualToString:@"AuthFailure"]
           || [e.errorCode isEqualToString:@"AWS.SimpleQueueService.InternalError"]
           || [e.errorCode isEqualToString:@"InternalError"]
           || [e.errorCode isEqualToString:@"InvalidAccessKeyId"]
           || [e.errorCode isEqualToString:@"InvalidSecurity"]
           || [e.errorCode isEqualToString:@"InvalidSecurityToken"]
           || [e.errorCode isEqualToString:@"MissingClientTokenId"]
           || [e.errorCode isEqualToString:@"MissingCredentials"]
           || [e.errorCode isEqualToString:@"NotAuthorizedToUseVersion"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           || [e.errorCode isEqualToString:@"X509ParseError"]
           )
        {
            [AmazonClientManager wipeAllCredentials];
            
            return YES;
        }
    }
    
    return NO;
}


@end
