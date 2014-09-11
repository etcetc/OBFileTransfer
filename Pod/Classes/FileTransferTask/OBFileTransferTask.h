//
//  OBFileTransferTask.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/28/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OBFTMTaskStatus) {
    // These should probably be renamed with the OBFTM prefix since they are used externally. But hard to do as rename doesnt work on them.
    FileTransferInProgress,
    FileTransferDownloadFileReady,
    FileTransferPendingRetry,
};

extern NSString * const OBFTMCreatedOnKey;
extern NSString * const OBFTMTypeUploadKey;
extern NSString * const OBFTMMarkerKey;
extern NSString * const OBFTMNSTaskIdentifierKey;
extern NSString * const OBFTMRemoteUrlKey;
extern NSString * const OBFTMLocalFilePathKey;
extern NSString * const OBFTMParamsKey;
extern NSString * const OBFTMAttemptsKey;
extern NSString * const OBFTMStatusKey;
extern NSString * const OBFTMCountOfBytesExpectedToReceiveKey;
extern NSString * const OBFTMCountOfBytesReceivedKey;
extern NSString * const OBFTMCountOfBytesExpectedToSendKey;
extern NSString * const OBFTMCountOfBytesSentKey;


@interface OBFileTransferTask : NSObject <NSCoding>

@property (nonatomic,strong) NSDate * createdOn;
@property (nonatomic) BOOL typeUpload;
@property (nonatomic) NSInteger attemptCount;
@property (nonatomic,strong) NSString *marker;
@property (nonatomic,strong) NSString *remoteUrl;
@property (nonatomic,strong) NSString *localFilePath;
@property (nonatomic) NSUInteger nsTaskIdentifier;
@property (nonatomic,strong) NSDictionary *params;
@property (nonatomic) OBFTMTaskStatus status;

// Return a request that would map to this transfer agent (NOT USED FOR NOW)
//-(NSMutableURLRequest *) request;

-(NSString *) description;
-(NSString *) statusDescription;
-(NSString *) transferDirection;
-(NSDictionary *) info;

// these are for converting to a simple dictionary for serializing, etc.
-(NSDictionary *) asDictionary;
-(instancetype) initFromDictionary: (NSDictionary *)savedFormat;

@end
