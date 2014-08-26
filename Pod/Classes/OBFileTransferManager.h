//
//  OBFileTransferManager.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/20/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OBFileTransferAgentFactory.h"
#import "OBFileTransferTask.h"

// methods that should be handled by the delegate
@protocol OBFileTransferDelegate <NSObject>

-(void) fileTransferCompleted: (NSString *)markerId withError: (NSError *)error;

@optional
-(void) fileTransferProgress: (NSString *)markerId percent: (NSUInteger) progress;
-(void) fileTransferRetrying: (NSString *)markerId attemptCount: (NSUInteger)attemptCount withError: (NSError *)error;
-(NSTimeInterval) retryTimeoutValue: (NSInteger)retryAttempt;
@end

typedef NS_ENUM(NSUInteger, FileManagerErrorCode) {
    FileManageErrorUnknown = -1,
    FileManageErrorBadHttpResponse = 1000,
};

@interface OBFileTransferManager : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (copy) void (^backgroundSessionCompletionHandler)();
@property (nonatomic,strong) NSString * uploadDirectory;
@property (nonatomic,strong) NSString * downloadDirectory;
@property (nonatomic,strong) NSString * remoteUrlBase;
@property (nonatomic,strong) id<OBFileTransferDelegate> delegate;
@property (nonatomic) BOOL foregroundTransferOnly;
@property (nonatomic) NSUInteger maxAttempts;
@property (nonatomic) OBFileStore fileStore;


+(OBFileTransferManager *) instance;

-(void) initSession;
- (NSURLSession *) session;

// Reset the state of all the tasks
-(void) reset;

// Main API
- (void) uploadFile:(NSString *)localFilePath to:(NSString *)remoteUrl withMarker: (NSString *)markerId withParams:(NSDictionary *)params;
- (void) downloadFile:(NSString *)remoteUrl to:(NSString *)localFilePath withMarker: (NSString *)markerId withParams:(NSDictionary *)params;
-(NSArray *) currentState;
-(NSString *) pendingSummary;
-(void) retryPending;


@end
