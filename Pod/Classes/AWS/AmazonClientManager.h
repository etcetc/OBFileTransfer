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

#import <Foundation/Foundation.h>
#import <AWSRuntime/AWSRuntime.h>

#import <AWSS3/AWSS3.h>
#import "Response.h"


@interface AmazonClientManager:NSObject {
}

@property (nonatomic,strong) NSString * tvmServerUrl;

+(AmazonS3Client *)s3;
+(void)setTvmServerUrl: (NSString *) tvmServerUrl;
+(void)setNoTvmCredentials:(AmazonCredentials *)credentials;
+(void)setRegion: (AmazonRegion) region;
+(Response *)validateCredentials;
+(void)wipeAllCredentials;
+ (BOOL)wipeCredentialsOnAuthError:(NSError *)error;

+(NSString *)securityToken;

extern NSString * const kAmazonTokenHeader;

@end
