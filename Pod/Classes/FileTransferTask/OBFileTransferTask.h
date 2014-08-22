//
//  OBFileTransferTask.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/28/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OBFileTransferTaskStatus) {
    FileTransferInProgress,
    FileTransferPendingRetry,
};

extern NSString * const CreatedOnKey;
extern NSString * const TypeUploadKey;
extern NSString * const MarkerKey;
extern NSString * const NSTaskIdentifierKey;
extern NSString * const RemoteUrlKey;
extern NSString * const LocalFilePathKey;
extern NSString * const ParamsKey;
extern NSString * const AttemptsKey;
extern NSString * const StatusKey;

@interface OBFileTransferTask : NSObject <NSCoding>

@property (nonatomic,strong) NSDate * createdOn;
@property (nonatomic) BOOL typeUpload;
@property (nonatomic) NSInteger attemptCount;
@property (nonatomic,strong) NSString *marker;
@property (nonatomic,strong) NSString *remoteUrl;
@property (nonatomic,strong) NSString *localFilePath;
@property (nonatomic) NSUInteger nsTaskIdentifier;
@property (nonatomic,strong) NSDictionary *params;
@property (nonatomic) OBFileTransferTaskStatus status;

// Return a request that would map to this transfer agent (NOT USED FOR NOW)
//-(NSMutableURLRequest *) request;

-(NSString *) description;
-(NSString *) statusDescription;
-(NSString *) transferDirection;
-(NSDictionary *) stateSummary;

// these are for converting to a simple dictionary for serializing, etc.
-(NSDictionary *) asDictionary;
-(instancetype) initFromDictionary: (NSDictionary *)savedFormat;

@end
