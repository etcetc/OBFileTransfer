//
//  OBS3FileTransferAgent.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/26/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OBFileTransferAgent.h"

extern NSString *const OBS3StorageProtocol;
extern NSString *const OBS3TvmServerUrlParam;
extern NSString *const OBS3RegionParam;
extern NSString *const OBS3NoTvmAccessKeyParam;
extern NSString *const OBS3NoTvmSecretKeyParam;
extern NSString *const OBS3NoTvmSecurityTokenParam;

/** TransferAgent for use with Amazon S3
 * configParams:
 * 
 * OBS3TvmServerUrlParam: 
 *      The url for the TokenVending machine. If nil then a TokenVendingMachine is not used.
 *
 * OBS3NoTvmAccessKeyParam,
 * OBS3NoTvmSecretKeyParam,
 * OBS3NoTvmSecurityTokenParam:
 *      The credentials to use in case TokenVendingMachine is not used. SecurityToken may be nil. If either
 * AccessKey or SecretKey are nil S3 is accessed without credentials for the case of public S3 buckets.
 * 
 * OBS3RegionParam:
 *      The endpoint for the region of the S3 bucket. If nil then US_EAST_1 region is used.
 */
@interface OBS3FileTransferAgent : OBFileTransferAgent

@end
