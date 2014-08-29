//
//  OBFileTransferManager.m
//  How to use this framework
//
//  The FileTransferManager can be handed the responsibility of sending a file.  It will attempt to do so in the background.  If there is no connectivity
//  or the transfer doesn't complete, it will queue it for retry and test again when there is connectivity.
//  The File TransferManager can support multiple targets (currently 2: standard upload to a server, or Amazon S3 using the Token Vending Machine model).
//
//  TODO: AmazonClientManager should really be passed along to this - right now it's hardcoded
//  Usage:
//    OBFileTransferManager ftm = [OBFileTransferManager instance]
//    [ftm uploadFile: someFilePathString to:remoteUrlString withMarker:markerString
//
//  Created by Farhad Farzaneh on 6/20/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <OBLogger/OBLogger.h>
#import "OBFileTransferManager.h"
#import "OBServerFileTransferAgent.h"
#import "OBFileTransferTaskManager.h"
#import "OBNetwork.h"
#import "OBFTMError.h"

// *********************************
// The File Transfer Manager
// *********************************

@interface OBFileTransferManager()
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic,strong) OBFileTransferTaskManager * transferTaskManager;
@property BOOL timerEngaged;
@end

@implementation OBFileTransferManager

static NSString * const OBFileTransferSessionIdentifier = @"com.onebeat.fileTransferSession";

OBFileTransferTaskManager * _transferTaskManager = nil;

#define INFINITE_ATTEMPTS 0

//--------------
// Instantiation
//--------------

- (instancetype)init{
    self = [super init];
    if (self){
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    return self;
}

// Right now we just return a single instance but in the future I could return multiple instances
// if I want to have different delegates for each
// GARF - deprecate - not using a singleton pattern
+(instancetype) instance
{
    static OBFileTransferManager * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.maxAttempts = INFINITE_ATTEMPTS;
    });
    return instance;
}


//--------------
// Configure
//--------------

// You can set a default uploadDirectory, downloadDirectory, and remoteUrlBase
// Then when you pass any parameter in the upload and download messages, they will be made into fully formed paths.  For the
// directories, if the path for the passed param starts with '/', it is assumed to already be a fully formed path

// Set the download directory, but they may be renamed...
-(void) setDownloadDirectory:(NSString *)downloadDirectory
{
    NSError * error;
    _downloadDirectory = downloadDirectory;
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    if ( error != nil ) {
        OB_ERROR(@"create download directory failed: %@",error.localizedDescription);
    }
}

-(void) setRemoteUrlBase:(NSString *)remoteUrlBase
{
    _remoteUrlBase = remoteUrlBase;
    if ( ![_remoteUrlBase hasSuffix:@"/"] ) {
        _remoteUrlBase = [_remoteUrlBase stringByAppendingString:@"/"];
    }
}

// Initialize the instance. Don't want to call it initialize
-(void) initSession
{
    [self session];
}

// ---------------
// Lazy Instantiators for key helper objects
// ---------------

// The transfer task manager keeps track of ongoing transfers
-(OBFileTransferTaskManager *)transferTaskManager
{
    if ( _transferTaskManager == nil )
        @synchronized(self) {
            _transferTaskManager = [[OBFileTransferTaskManager alloc] init];
            [_transferTaskManager restoreState];
        }
    return _transferTaskManager;
}

// ---------------
// Session methods
// ---------------

/*
 Singleton with unique identifier so our session is matched when our app is relaunched either in foreground or background. From: apple docuementation :: Note: You must create exactly one session per identifier (specified when you create the configuration object). The behavior of multiple sessions sharing the same identifier is undefined.
 */

- (NSURLSession *) session{
    static NSURLSession *backgroundSession = nil;
    static dispatch_once_t once;
    //    Create a single session and make it be thread-safe
    dispatch_once(&once, ^{
        OB_INFO(@"Creating a %@ URLSession",self.foregroundTransferOnly ? @"foreground" : @"background");
        NSURLSessionConfiguration *configuration = self.foregroundTransferOnly ? [NSURLSessionConfiguration defaultSessionConfiguration] :
            [NSURLSessionConfiguration backgroundSessionConfiguration:OBFileTransferSessionIdentifier];
        configuration.HTTPMaximumConnectionsPerHost = 10;
        backgroundSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        [backgroundSession resetWithCompletionHandler:^{
            OB_DEBUG(@"Reset the session cache");
        }];
        
    });
    return backgroundSession;
}

-(void) printSessionTasks
{
    [[self session] getTasksWithCompletionHandler: ^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if ( uploadTasks.count == 0 ) {
            OB_DEBUG(@"No Upload tasks");
        } else {
            OB_DEBUG(@"CURRENT UPLOAD TASKS");
            for ( NSURLSessionTask * task in uploadTasks ) {
                OB_DEBUG(@"%@",[[self.transferTaskManager transferTaskForNSTask:task] description]);
            }
        }
        if ( downloadTasks.count == 0 ) {
            OB_DEBUG(@"No Download tasks");
        } else {
            OB_DEBUG(@"CURRENT DOWNLOAD TASKS");
            for ( NSURLSessionTask * task in downloadTasks ) {
                OB_DEBUG(@"%@",[[self.transferTaskManager transferTaskForNSTask:task] description]);
            }
        }
    }];
}

-(void) cancelSessionTasks: (void(^)()) completionBlockOrNil;
{
    OB_DEBUG(@"Canceling session tasks");
    [[self session] getTasksWithCompletionHandler: ^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if ( uploadTasks.count != 0 ) {
            for ( NSURLSessionTask * task in uploadTasks ) {
                OB_DEBUG(@"Canceling upload task %lu with reference: %@",(unsigned long)task.taskIdentifier,[[self.transferTaskManager transferTaskForNSTask:task] description]);
                [task cancel];
            }
        }
        if ( downloadTasks.count != 0 ) {
            for ( NSURLSessionTask * task in downloadTasks ) {
                OB_DEBUG(@"Canceling download task %lu with reference: %@",(unsigned long)task.taskIdentifier,[[self.transferTaskManager transferTaskForNSTask:task] description]);
                [task cancel];
            }
            
        }
        if ( completionBlockOrNil ) completionBlockOrNil();
    }];
}

-(void) cancelSessionTask: (NSUInteger) taskIdentifier completion: (void(^)())completionBlockOrNil
{
    OB_DEBUG(@"Canceling session task %lu",(unsigned long)taskIdentifier);
    [[self session] getTasksWithCompletionHandler: ^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        for ( NSURLSessionTask * task in [uploadTasks arrayByAddingObjectsFromArray:downloadTasks] ) {
            if ( task.taskIdentifier == taskIdentifier ) {
                OB_DEBUG(@"Canceling task identifier %lu",(unsigned long)taskIdentifier);
                [task cancel];
            }
        }
        if ( completionBlockOrNil ) completionBlockOrNil();
    }];
}

#pragma mark - Main API
// --------------
// Main API
// --------------

// This resets everything by cancelling all tasks and removing them from our task Manager
// Note that cancelSessionTasks is asynchronous
-(void) reset:(void(^)())completionBlockOrNil
{
    [self cancelSessionTasks: ^{
        self. timerEngaged = 0;
        [self.transferTaskManager reset];
        if ( completionBlockOrNil ) completionBlockOrNil();
    }];
}

// Upload the file at the indicated filePath to the remoteFileUrl (do not include target filename here!).
// Note that the params dictionary contains both parmetesr interpreted by the local transfer agent and those
// that are sent along with the file for uploading.  Local params start with the underscore.  Specifically:
//  FilenameParamKey: contains the uploaded filename. Default: it is pulled from the input filename
//  ContentTypeParamKey: contains the content type to use.  Default: it is extracted from the filename extension.
//  FormFileFieldNameParamKey: contains the field name containing the file. Default: file.
// Note that in some file stores some of these parameters may be meaningless.  For example, for S3, the Amazon API uses its
// own thing - we don't really care about the field name.

- (void) uploadFile:(NSString *)filePath to:(NSString *)remoteFileUrl withMarker:(NSString *)markerId withParams:(NSDictionary *) params
{
    [self processTransfer:markerId remote:remoteFileUrl local:filePath params:params upload:YES];
}

// Download the file from the remote URL to the provided filePath.
//
- (void) downloadFile:(NSString *)remoteFileUrl to:(NSString *)filePath withMarker: (NSString *)markerId withParams:(NSDictionary *) params
{
    [self processTransfer:markerId remote:remoteFileUrl local:filePath params:params upload:NO];
}

// Cancel a transfer with the indicated marker
-(void) cancelTransfer: (NSString *) marker
{
    OBFileTransferTask *obTask =[[self transferTaskManager] transferTaskWithMarker:marker];
    if (  obTask != nil ) {
        [self cancelSessionTask:obTask.nsTaskIdentifier completion: ^{
            [[self transferTaskManager] removeTaskWithMarker:marker];
        }];
    }
}

// Return the current state for the various tasks
-(NSArray *) currentState
{
    return [self.transferTaskManager currentState];
}

-(NSString *) pendingSummary
{
    NSInteger uploads=0,downloads=0;
    for ( OBFileTransferTask * task in [self.transferTaskManager pendingTasks] ) {
        if ( task.typeUpload) uploads++; else downloads++;
    }
    return [NSString stringWithFormat:@"%d up, %d down",(int)uploads,(int)downloads];
}

// Return the state for the indicated marker
-(NSDictionary *) stateForMarker: (NSString *)marker
{
    return [[self.transferTaskManager transferTaskWithMarker:marker] stateSummary];
}

// Retry all pending transfers - to be called externally
// Warning - this resets all the history on pending tasks and timers.  We want this because
//  we don't want the client to unwittingly mess up the retry counts and timers by launching the app
//  to make one more recording.  We can get more sophisticated by looking at reachability later one...
-(void) retryPending
{
    [[self transferTaskManager] resetRetries];
    [self retryPendingInternal];
}


// INTERNAL

// Retry all pending transfers
-(void) retryPendingInternal
{
    //    Cancel any timers because we are retrying everything.  Then if there is a failure, we re-engage the timer
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(retryPendingInternal) object:nil];
    self.timerEngaged = NO;
    
//    Not sure yet what the right thing to do is.... Even if we know the netowrk is not available, should we
//    go through the motions of retrying, or just reset the timer?
    if ( YES || [OBNetwork isInternetAvailable] ) {
        NSArray *pendingTasks = [self.transferTaskManager pendingTasks];
        if ( pendingTasks.count > 0 ) {
            OB_INFO(@"Retrying %lu pending tasks",(unsigned long)pendingTasks.count);
            for ( OBFileTransferTask * obTask in [self.transferTaskManager pendingTasks] ) {
                NSURLSessionTask * task = [self createNsTaskFromObTask: obTask];
                [self.transferTaskManager processing:obTask withNsTask:task];
                [task resume];
            }
        }
    } else {
        OB_INFO(@"Not retrying because network is not available");
        [self setupRetryTimer];
    }
}

#pragma mark -- Internal
-(void) processTransfer: (NSString *)marker remote: (NSString *)remoteFileUrl local:(NSString *)filePath params:(NSDictionary *)params upload:(BOOL) upload
{
    NSString *fullRemoteUrl = [self fullRemotePath:remoteFileUrl];
    NSString *localFilePath;

    OBFileTransferTask *obTask;
    if ( upload ) {
        localFilePath = [self normalizeLocalUploadPath:filePath];
        obTask = [self.transferTaskManager trackUploadTo:fullRemoteUrl fromFilePath:localFilePath withMarker:marker withParams:params];
    } else {
        localFilePath = [self normalizeLocalDownloadPath:filePath];
        obTask = [self.transferTaskManager trackDownloadFrom:fullRemoteUrl toFilePath:localFilePath withMarker:marker withParams:params];
    }
    
    NSURLSessionTask *task = [self createNsTaskFromObTask:obTask];
    [self.transferTaskManager processing:obTask withNsTask:task];
    [task resume];
}

// Create a NS Task from the OBTask info
// NOTE: FileTransferAgents have different behavrior as to whether they create a multipart body
//   For example, a standard server upload will do so as a multipart request, but the S3 agent does not.
//   Since the background file transfer manager expects a file, if there is a multipart body, we need to write the whole
//   thing to a file.  Once the file is written, we can just reuse this and in case there is a retry, we don't need
//   to go through the process of re-encoding this again.
-(NSURLSessionTask *) createNsTaskFromObTask: (OBFileTransferTask *) obTask
{
    NSURLSessionTask *task;
    OBFileTransferAgent * fileTransferAgent = [OBFileTransferAgentFactory fileTransferAgentInstance:obTask.remoteUrl];
    
    if ( obTask.typeUpload ) {
        
        NSError *error;
        NSMutableURLRequest *request;
        if ( ![self isLocalFile: obTask.localFilePath] ) {
            request = [fileTransferAgent uploadFileRequest:obTask.localFilePath to:obTask.remoteUrl withParams:obTask.params];
            NSString * tmpFile = [self temporaryFile:obTask.marker];
            //        If the file already exists, we should delete it...
            if ( [[NSFileManager defaultManager] fileExistsAtPath:tmpFile] ) {
                [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:&error];
                if ( error != nil )
                    OB_ERROR(@"Unable to delete existing temporary file %@",tmpFile);
                else
                    OB_DEBUG(@"Deleted existing tmp file %@",tmpFile);
                
                error = nil;
            }
            if ( fileTransferAgent.hasMultipartBody ) {
                if ( ![[request HTTPBody] writeToFile:tmpFile atomically:NO] ) {
//                    TODO: Replace with specific bundle for this module rather than mail bundle
                    error = [self createNSErrorForCode:OBFTMTmpFileCreateError];
                }
            } else {
                [[NSFileManager defaultManager] copyItemAtPath:obTask.localFilePath toPath:tmpFile error:&error];
                if ( error != nil )
                    OB_ERROR(@"Unable to copy file %@ to temporary file %@",obTask.localFilePath, tmpFile);
            }
            
            if ( error == nil ) {
                [self.transferTaskManager update:obTask withLocalFilePath:tmpFile];
            }
            
        } else {
            request = [fileTransferAgent uploadFileRequest:nil to:obTask.remoteUrl withParams:nil];
        }
        
        task = [[self session] uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:obTask.localFilePath]];
        
    } else {
        NSMutableURLRequest *request = [fileTransferAgent downloadFileRequest:obTask.remoteUrl withParams:obTask.params];
        task = [[self session] downloadTaskWithRequest:request];
    }
    return task;
}

// Returns if the file is owned by the file transfer manager
-(BOOL) isLocalFile: (NSString *)localFilePath
{
    return ( [localFilePath rangeOfString:[self tempDirectory]].location != NSNotFound );
}

#pragma mark - Delegates

// --------------
// Delegate Functions
// --------------


// ------
// Upload & Download Completion Handling
// ------

// NOTE::: This gets called for upload and download when the task is complete, possibly w/ framework or server error (server error has bad response code which we cast into an NSError)
- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    OBFileTransferTask * obtask = [[self transferTaskManager] transferTaskForNSTask:task];
    if ( obtask == nil ) {
        if ( error.code == NSURLErrorCancelled )
            OB_INFO(@"Unable to find reference for task Identifier %lu because it had been cancelled",(unsigned long)task.taskIdentifier);
        else
            OB_WARN(@"Unable to find reference for task Identifier %lu",(unsigned long)task.taskIdentifier);
        return;
    }
    NSString *marker = obtask.marker;
    NSHTTPURLResponse *response =   (NSHTTPURLResponse *)task.response;
    //    OB_DEBUG(@"File transfer %@ response = %@",marker, response);
    if ( task.state == NSURLSessionTaskStateCompleted ) {
        
//        Even though the URL connection may have been good, there may have been a server error or otherwise so let's create an internal error for this
        if ( error == nil ) {
            error = [self createErrorFromHttpResponse:response.statusCode];
            if ( error )
                OB_WARN(@"%@ File Transfer for %@ received status code %ld and error %@",obtask.typeUpload ? @"Upload" : @"Download", marker,(long)response.statusCode, error.localizedDescription);
        
        }
        
        if ( error == nil ) {
            if (obtask.typeUpload){
                [self uploadCompleted: obtask];
            } else if (obtask.status != FileTransferDownloadFileReady ) {
                error = [self createNSErrorForCode: OBFTMTmpDownloadFileCopyError];
            }
            [self handleCompleted:task obtask:obtask error:error];
            OB_INFO(@"%@ for %@ done", obtask.typeUpload ? @"Upload" : @"Download", marker);
        } else {
//            There was an error
            if ( self.maxAttempts != 0 && obtask.attemptCount >= self.maxAttempts ) {
                [self handleCompleted:task obtask:obtask error:error];
            } else {
//                OK, we're going to retry now. If have not yet set up a timer, let's do so now
                [[self transferTaskManager] queueForRetry:obtask];
                [self setupRetryTimer];
                [self.delegate fileTransferRetrying:marker attemptCount: obtask.attemptCount  withError:error];
            }
        }
    } else {
        OB_WARN(@"Indicated that task completed but state = %d", (int) task.state );
    }
}


// ------
// Upload
// ------

- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSString *marker = [[self transferTaskManager] markerForNSTask:task];
    NSUInteger percentDone = (NSUInteger)(100*totalBytesSent/totalBytesExpectedToSend);
    OB_DEBUG(@"Upload progress %@: %lu%% [sent:%llu, of:%llu]", marker, (unsigned long)percentDone, totalBytesSent, totalBytesExpectedToSend);
    if ( [self.delegate respondsToSelector:@selector(fileTransferProgress:percent:)] ) {
        NSString *marker = [[self transferTaskManager] markerForNSTask:task];
        [self.delegate fileTransferProgress: marker percent:percentDone];
    }
}

// --------
// Download
// --------

// Download progress
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSString *marker = [[self transferTaskManager] markerForNSTask:task];
    NSUInteger percentDone = (NSUInteger)(100*totalBytesWritten/totalBytesExpectedToWrite);
    OB_DEBUG(@"Download progress %@: %lu%% [received:%llu, of:%llu]", marker, (unsigned long)percentDone, totalBytesWritten, totalBytesExpectedToWrite);
    if ( [self.delegate respondsToSelector:@selector(fileTransferProgress:percent:)] ) {
        NSString *marker = [[self transferTaskManager] markerForNSTask:task];
        [self.delegate fileTransferProgress: marker percent:percentDone];
    }
}

// Completed the download
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    OBFileTransferTask * obtask = [[self transferTaskManager] transferTaskForNSTask:downloadTask];
    NSHTTPURLResponse *response =   (NSHTTPURLResponse *)downloadTask.response;
    if ( response.statusCode/100 == 2   ) {
        //        Now we need to copy the file to our downloads location...
        NSError * error;
        NSString *localFilePath = [[[self transferTaskManager] transferTaskForNSTask: downloadTask] localFilePath];
        
//        If the file already exists, remove it and overwrite it
        if ( [[NSFileManager defaultManager] fileExistsAtPath:localFilePath] ) {
            [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&error];
        }
        
        [[NSFileManager defaultManager] copyItemAtPath:location.path toPath:localFilePath  error:&error];
        if ( error != nil ) {
            OB_ERROR(@"Unable to copy downloaded file to '%@' due to error: %@",localFilePath,error.localizedDescription);
        } else {
            [self.transferTaskManager update:obtask withStatus: FileTransferDownloadFileReady];
            OB_DEBUG(@"Finished copying download file to %@",localFilePath);
        }
    } else {
        OB_ERROR(@"Download for %@ received status code %ld",obtask.marker,(long)response.statusCode);
    }
}

// Resumed the download
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    OB_WARN(@" Got download resume but haven't implemented it yet!");
}


// -------
// Session
// -------
/*
 If an application has received an -application:handleEventsForBackgroundURLSession:completionHandler: message, the session delegate will receive this message to indicate that all messages previously enqueued for this session have been delivered. We need to process all the completed tasks update the ui accordingly and invoke the completion handler so the os can take a picture of our app.
 */
- (void) URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    if ([session.configuration.identifier isEqualToString:OBFileTransferSessionIdentifier]){
        
        if (self.backgroundSessionCompletionHandler == nil){
            OB_ERROR(@"backgroundSessionCompletionHandler was not set. AppDelegate should set backgroundSessionCompletionHandler in handleEventsForBackgroundURLSession" );
        } else {
            self.backgroundSessionCompletionHandler();
            self.backgroundSessionCompletionHandler = nil;
            OB_INFO(@"Flushing session %@.", [self session].configuration.identifier);
            [[self session] flushWithCompletionHandler:^{
                OB_INFO(@"Flushed session should be using new socket.");
            }];
        }
    }
}

#pragma mark -- Internal

// ------
// Security for Testing w/ Charles (to track info going up and down)
// ------

// TODO : Remove these
-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    
    NSLog(@">>>>>Received authentication challenge");
    completionHandler(NSURLSessionAuthChallengeUseCredential,nil);
}

-(void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    
    NSLog(@">>>>>Received task-level authentication challenge");
    completionHandler(NSURLSessionAuthChallengeUseCredential,nil);
    
}


-(void) handleCompleted:(NSURLSessionTask *)task obtask:(OBFileTransferTask *)obtask error:(NSError *)error
{
    NSString *marker = obtask.marker;
    [[self transferTaskManager] removeTransferTaskForNsTask:task];
    [self updateBackground];
    [self.delegate fileTransferCompleted:marker withError:error];
}

-(NSError *) uploadCompleted: (OBFileTransferTask *)obTask;
{
    NSError * error;
    [[NSFileManager defaultManager] removeItemAtPath:obTask.localFilePath error:&error];
    if ( error != nil ) {
        OB_WARN(@"Unable to delete local file %@: %@",obTask.localFilePath,error.localizedDescription);
    }
    return error;
}

-(void) setupRetryTimer
{
    if ( !self.timerEngaged ) {
        self.timerEngaged = YES;
        [self.transferTaskManager updateRetryTimerCount];
        NSUInteger retryTimerValue;
        if ( [self.delegate respondsToSelector:@selector(retryTimeoutValue:)] )
            retryTimerValue = [self.delegate retryTimeoutValue:self.transferTaskManager.retryTimerCount];
        else
            retryTimerValue = [self retryTimeoutValue: self.transferTaskManager.retryTimerCount];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            OB_INFO(@"Setting up to retry pending tasks in %.2lu seconds",(unsigned long)retryTimerValue);
            [self requestBackground];
            [self performSelector:@selector(retryPendingInternal) withObject:nil afterDelay:retryTimerValue];
        });
    }
}


// -------
//  Background (only used for timer events, which only occurs if we have pending tasks)
// --------

-(void) requestBackground
{
    if ( self.backgroundTaskIdentifier == UIBackgroundTaskInvalid ) {
        self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            OB_INFO(@"Ending background tasks");
            [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }];
    }
}

-(void) updateBackground
{
    if (  self.backgroundTaskIdentifier != UIBackgroundTaskInvalid ) {
        if ( [self.transferTaskManager pendingTasks].count == 0 ) {
            OB_INFO(@"No pending tasks left so ending background tasks");
            [[self transferTaskManager] resetRetryTimerCount];
            [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }
}

#pragma mark - Private utility

// -------
// Private
// -------

-(NSString* )normalizeLocalDownloadPath: (NSString * )filePath
{
    if ( _downloadDirectory == nil || [filePath characterAtIndex:0] == '/')
        return filePath;
    else
        return [NSString pathWithComponents:@[_downloadDirectory,filePath ]];
}

-(NSString *) normalizeLocalUploadPath: (NSString *)filePath
{
    if ( _uploadDirectory == nil || [filePath characterAtIndex:0] == '/' )
        return filePath;
    else
        return [NSString pathWithComponents:@[_uploadDirectory,filePath ]];
}

-(NSString *) fullRemotePath: (NSString *)remotePath
{
    if ( remotePath == nil ) remotePath = @"";
    if ( self.remoteUrlBase == nil || [remotePath rangeOfString:@"://"].location != NSNotFound )
        return remotePath;
    else {
        if ( [remotePath hasPrefix:@"/"] )
            remotePath = [remotePath substringFromIndex:1];
    }
    return [self.remoteUrlBase stringByAppendingString:remotePath];
}

-(NSString *) tempDirectory
{
    static NSString * _tempDirectory;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //    Get a temporary directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([paths count]) {
            NSString *bundleName =[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
            _tempDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:bundleName];
        }
    });
    return _tempDirectory;
}

// A temporary file is super-temporary and used to create the full transmit package
-(NSString *) temporaryFile: (NSString *)marker
{
    return [[self tempDirectory] stringByAppendingPathComponent:marker];
}

-(NSError *) createErrorFromHttpResponse:(NSInteger) responseCode
{
    NSError *error = nil;
    if ( responseCode/100 != 2 ) {
        NSString *description  = [NSHTTPURLResponse localizedStringForStatusCode:responseCode];
        error = [NSError errorWithDomain:NSURLErrorDomain code:FileManageErrorBadHttpResponse userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return error;
}

-(NSError *) createNSErrorForCode: (OBFTMErrorCode) code
{
    return [NSError errorWithDomain:[OBFTMError errorDomain] code: code userInfo:@{NSLocalizedDescriptionKey:[OBFTMError localizedDescription:code]}];
}

// Returns the timer value in seconds...
-(NSTimeInterval) retryTimeoutValue: (NSUInteger)retryAttempt
{
//    return (NSTimeInterval)10.0;
    return (NSTimeInterval)10*(1<<(retryAttempt-1));
}

@end
