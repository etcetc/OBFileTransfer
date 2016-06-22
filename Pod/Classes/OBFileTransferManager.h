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

typedef struct
{
    uint64_t bytesWritten;
    uint64_t totalBytes;
    double percentDone;
} OBTransferProgress;


// methods that should be handled by the delegate
@protocol OBFileTransferDelegate <NSObject>

- (void)fileTransferCompleted:(NSString *)markerId withError:(NSError *)error;

@optional
- (void)fileTransferProgress:(NSString *)markerId progress:(OBTransferProgress)progress;

- (void)fileTransferRetrying:(NSString *)markerId attemptCount:(NSUInteger)attemptCount withError:(NSError *)error;

- (NSTimeInterval)retryTimeoutValue:(NSInteger)retryAttempt;
@end

typedef NS_ENUM(NSUInteger, FileManagerErrorCode)
{
    FileManageErrorUnknown = -1,
    FileManageErrorBadHttpResponse = 1000
};

extern NSString *const OBFTMMaxRetriesParam;                               // Set maximum number of retries
extern NSString *const OBFTMFileStoreConfigParam;                          // Configurations for the file store
extern NSString *const OBFTMDownloadDirectoryParam;                        // FilePath for the default download directory
extern NSString *const OBFTMUploadDirectoryParam;                          // FilePath for the default upload directory
extern NSString *const OBFTMRemoteBaseUrlParam;                            // Default remote base URL (only valid for private file stores - for S3, Google cloud, etc these are predetermined)
extern NSString *const OBFTMOnlyForegroundTransferParam;                    // Boolean to specify if we should liimit to foreground transfers

@interface OBFileTransferManager : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (copy) void (^backgroundSessionCompletionHandler)();

// Configuration parameters
@property (nonatomic, strong) NSString *uploadDirectory;
@property (nonatomic, strong) NSString *downloadDirectory;
@property (nonatomic, strong) NSString *remoteUrlBase;
@property (nonatomic) NSUInteger maxAttempts;
@property (nonatomic) BOOL foregroundTransferOnly;

@property (nonatomic, strong) id <OBFileTransferDelegate> delegate;

// Retrieve the singleton
+ (OBFileTransferManager *)instance;

// Pass along configuration parameters
- (void)configure:(NSDictionary *)configuration;

- (NSURLSession *)session;

// Reset the state of all the tasks
- (void)reset:(void (^)())completionBlockOrNil;

/************
 * Main API
 ************/

// Upload/Download the file indicated by the local file path to/from the remote URL.  Assign it the name indicated by the markerId (this is used in callbacks to let
// theclient know when status changes, or in response to status queries.
// Items in params dictionary include those have special meaning to FTM (see list in FileTransferAgent.h), as well as others that can be passed
// if the fileStore API allows it (e.g. sending files to a private server as a multipart form)
// Note that the local file path can be absolute, or relative, in which case it's considered relative to the previously specified download or upload directories
- (void)uploadFile:(NSString *)localFilePath
                to:(NSString *)remoteUrl
        withMarker:(NSString *)markerId
        withParams:(NSDictionary *)params;

- (void)downloadFile:(NSString *)remoteUrl
                  to:(NSString *)localFilePath
          withMarker:(NSString *)markerId
          withParams:(NSDictionary *)params;

/**
 * deleteFile is synchrounous and should be run on a background thread by the caller if async is required.
 */
- (NSError *)deleteFile:(NSString *)remoteUrl;

- (void)restartTransfer:(NSString *)marker onComplete:(void (^)(NSDictionary *))completionBlockOrNil;

- (void)cancelTransfer:(NSString *)marker onComplete:(void (^)())completionBlockOrNil;

- (NSArray *)currentState;

- (void)currentTransferStateWithCompletionHandler:(void (^)(NSArray *ftState))handler;

- (NSString *)pendingSummary;

- (void)retryPending;

- (void)restartAllTasks:(void (^)())completionBlockOrNil;


@end
