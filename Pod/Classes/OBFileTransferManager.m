//  Test
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
{
@private
    
    OBFileTransferTaskManager * _transferTaskManager;
}

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic,strong) OBFileTransferTaskManager * transferTaskManager;
@property (nonatomic,strong) NSDictionary * configParams;
@property BOOL timerEngaged;
@end


NSString * const OBFTMMaxRetriesParam = @"MaxRetries";                               // Set maximum number of retries
NSString * const OBFTMFileStoreConfigParam = @"FileStoreParams";                     // Configurations for the file store
NSString * const OBFTMDownloadDirectoryParam = @"DownloadDirectoryPath";             // FilePath for the default download directory
NSString * const OBFTMUploadDirectoryParam = @"UploadDirectoryPath";                 // FilePath for the default upload directory
NSString * const OBFTMRemoteBaseUrlParam = @"RemoteBaseUrl";                         // Default remote base URL (only valid for private file stores - for S3, Google cloud, etc these are predetermined)
NSString * const OBFTMOnlyForegroundTransferParam = @"OnlyForeground";               // Boolean to specify if we should liimit to foreground transfers

@implementation OBFileTransferManager

static NSString * const OBFileTransferSessionIdentifier = @"com.onebeat.fileTransferSession";


#define INFINITE_ATTEMPTS 0

//--------------
// Instantiation
//--------------

-(instancetype)init{
    self = [super init];
    if (self){
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    return self;
}

// Right now we just return a single instance but in the future I could return multiple instances
// if I want to have different delegates for each
+(instancetype) instance
{
    static OBFileTransferManager * instance = nil;
    static dispatch_once_t obftmOnceToken;
    dispatch_once(&obftmOnceToken, ^{
        instance = [[self alloc] init];
        instance.maxAttempts = INFINITE_ATTEMPTS;
        [instance initSession];
        //        And set up the transfer task manager here - was previously using lazy instantiation but set it up cuz we know we'll need it.
        [instance setupTransferTaskManager];
        OB_DEBUG(@"Created OBFileTransferManager instance");
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

-(void) configure: (NSDictionary *)configuration
{
    self.configParams = configuration;
    
    if ( configuration[OBFTMOnlyForegroundTransferParam] )
        self.foregroundTransferOnly = [configuration[OBFTMOnlyForegroundTransferParam] boolValue];
    
    if ( configuration[OBFTMDownloadDirectoryParam] )
        self.downloadDirectory = configuration[OBFTMDownloadDirectoryParam];
    
    if ( configuration[OBFTMUploadDirectoryParam] )
        self.uploadDirectory = configuration[OBFTMUploadDirectoryParam];
    
    if ( configuration[OBFTMRemoteBaseUrlParam] )
        self.remoteUrlBase = configuration[OBFTMRemoteBaseUrlParam];
    
}

// ---------------
// Lazy Instantiators for key helper objects
// ---------------


// This is a lazy instantiator for the transfer task manager that keeps track of ongoing transfers
-(OBFileTransferTaskManager *)transferTaskManager
{
    if ( _transferTaskManager == nil )
        @synchronized(self) {
            if ( _transferTaskManager == nil )
                _transferTaskManager = [OBFileTransferTaskManager instance];
        }
    return _transferTaskManager;
}

// ---------------
// Session methods
// ---------------

// Initialize the instance - since session had a lazy instantiator we want to call this if we want
// to do this deterministically
-(void) initSession
{
    [self session];
}

-(NSURLSession *) session{
    static NSURLSession *backgroundSession = nil;
    static dispatch_once_t sessionCreationOnceToken;
    // Create a single session and make it be thread-safe
    dispatch_once(&sessionCreationOnceToken, ^{
        OB_INFO(@"Creating a %@ URLSession",self.foregroundTransferOnly ? @"foreground" : @"background");
        NSURLSessionConfiguration *configuration = self.foregroundTransferOnly ? [NSURLSessionConfiguration defaultSessionConfiguration] :
        [NSURLSessionConfiguration backgroundSessionConfiguration:OBFileTransferSessionIdentifier];
        configuration.HTTPMaximumConnectionsPerHost = 10;
        // Hardcoded
        configuration.allowsCellularAccess = YES;
        configuration.networkServiceType = NSURLNetworkServiceTypeBackground;
        
        backgroundSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        
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

-(void) checkInternalTaskConsistency
{
    [[self session] getTasksWithCompletionHandler: ^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        NSArray *runningTasks = [uploadTasks arrayByAddingObjectsFromArray:downloadTasks];
        NSArray *markedAsPorcessingTasks = [self.transferTaskManager processingTasks];
        if ( runningTasks.count != markedAsPorcessingTasks.count )
            OB_ERROR(@"There are %lu tasks processing but %lu marked as processing", (unsigned long)runningTasks.count, (unsigned long)markedAsPorcessingTasks.count);
        for ( NSURLSessionTask * task in runningTasks ) {
            OBFileTransferTask *obTask = [self.transferTaskManager transferTaskForNSTask:task];
            if ( obTask == nil ) {
                OB_WARN(@"Unable to find OBTask for NS Task with identifier %lu",(unsigned long)task.taskIdentifier);
            }
        }
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

// This may be used if the app was suspended or terminated, and there were
// tasks that were pending.
-(void) restartAllTasks:(void(^)())completionBlockOrNil
{
    for ( OBFileTransferTask * obTask in self.transferTaskManager.allTasks ) {
        [self restartTransferTask:obTask];
    }
}

// Upload the file at the indicated filePath to the remoteFileUrl (do not include target filename here!).
// Note that the params dictionary contains both parmeters interpreted by the local transfer agent and those
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
// If the filePath is relative, we prepend the download directory if specified
- (void) downloadFile:(NSString *)remoteFileUrl to:(NSString *)filePath withMarker: (NSString *)markerId withParams:(NSDictionary *) params
{
    [self processTransfer:markerId remote:remoteFileUrl local:filePath params:params upload:NO];
}

- (NSError *) deleteFile:(NSString *)remoteUrl{
    NSString *fullPath = [self fullRemotePath:remoteUrl];
    OBFileTransferAgent * fileTransferAgent = [OBFileTransferAgentFactory fileTransferAgentInstance:fullPath
                                                                                         withConfig:self.configParams];
    return [fileTransferAgent deleteFile:fullPath];
}

// Cancel a transfer with the indicated marker.  When cancel is completed, call the callback if provided
-(void) cancelTransfer: (NSString *) marker onComplete:(void(^)())completionBlockOrNil
{
    OBFileTransferTask *obTask =[[self transferTaskManager] transferTaskWithMarker:marker];
    if (  obTask != nil ) {
        [self cancelSessionTask:obTask.nsTaskIdentifier completion: ^{
            [[self transferTaskManager] removeTaskWithMarker:marker];
            if ( completionBlockOrNil )
                completionBlockOrNil();
        }];
    }
}

// Cancel the transfer and restart it.  Return to the caller the information about the task that was just created.
-(void) restartTransfer: (NSString *) marker onComplete:(void(^)(NSDictionary *))completionBlockOrNil
{
    OBFileTransferTask *obTask =[[self transferTaskManager] transferTaskWithMarker:marker];
    if (  obTask != nil ) {
        [self restartTransferTask:obTask];
        if ( completionBlockOrNil )
            completionBlockOrNil([obTask info]);
    }
}

// Return the current state for the various tasks
-(NSArray *) currentState
{
    return [self.transferTaskManager currentState];
}

-(void)currentTransferStateWithCompletionHandler:(void (^)(NSArray *ftState))handler{
    [[self session] getTasksWithCompletionHandler: ^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        NSMutableArray *state = [[NSMutableArray alloc] init];
        for ( NSURLSessionTask * task in [uploadTasks arrayByAddingObjectsFromArray:downloadTasks] ) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

            OBFileTransferTask * obTask = [[self transferTaskManager] transferTaskForNSTask:task];
            if (obTask != nil){
                NSDictionary *info = [obTask info];
                [dict addEntriesFromDictionary:info];
            } else {
                OB_WARN(@"FTM: currentTransferStateWithCompletionHandler: got no obtask for transfer task: %@", task);
            }
            dict[CountOfBytesExpectedToReceiveKey] = [NSNumber numberWithLongLong: [task countOfBytesExpectedToReceive]];
            dict[CountOfBytesReceivedKey] = [NSNumber numberWithLongLong:[task countOfBytesReceived]];
            dict[CountOfBytesExpectedToSendKey] = [NSNumber numberWithLongLong: [task countOfBytesExpectedToSend]];
            dict[CountOfBytesSentKey] = [NSNumber numberWithLongLong: [task countOfBytesSent]];
            [state addObject:dict];
        }
        handler(state);
    }];
}

// Just a helpful status description, returning how many are pending
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
    return [[self.transferTaskManager transferTaskWithMarker:marker] info];
}

// Retry all pending transfers - to be called externally
// Warning - this resets all the history on pending tasks and timers.  We want this because
//  we don't want the client to unwittingly mess up the retry counts and timers by launching the app
//  to make one more recording.  We can get more sophisticated by looking at reachability later on...
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
                [self processObTask: obTask];
            }
        }
    } else {
        OB_INFO(@"Not retrying because network is not available");
        [self setupRetryTimer];
    }
}

#pragma mark -- Internal

// Kill the transfer wherever it is and restart it from scratch, but
// up the attemptCount
-(void) restartTransferTask: (OBFileTransferTask *)obTask
{
    if (  obTask != nil ) {
        [self cancelSessionTask:obTask.nsTaskIdentifier completion: ^{
            [self processObTask: obTask];
        }];
    }
}


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
    [self processObTask: obTask];
}

// given an obTask, create a native file transfer task and process it
-(void) processObTask: (OBFileTransferTask *)obTask
{
    NSURLSessionTask *task = [self createNsTaskFromObTask:obTask];
    [self.transferTaskManager processing:obTask withNsTask:task];
    [task resume];
}

// Create a NS Task from the OBTask info
// NOTE: FileTransferAgents have different behavrior as to whether they create a multipart body
//   For example, a standard server upload will do so as a multipart request, but the S3 agent does not.
//   Since the background file transfer manager expects a file, if there is a multipart body, we need to write the whole
//   thing to a file.  Once the file is written, we can just reuse this and in case there is a retry, we don't need
//   to go through the process of re-encoding the request with the file again.  Note that we still create the request
//   but without the file body.
// WARN: above optimization will not work if the creation of the request headers depends on the file.
-(NSURLSessionTask *) createNsTaskFromObTask: (OBFileTransferTask *) obTask
{
    NSURLSessionTask *task;
    OBFileTransferAgent * fileTransferAgent = [OBFileTransferAgentFactory fileTransferAgentInstance:obTask.remoteUrl withConfig:self.configParams] ;
    
    if ( obTask.typeUpload ) {
        
        NSError *error;
        NSMutableURLRequest *request;
        // We create the file that needs to be transmitted in a local directory
        if ( ![self isLocalFile: obTask.localFilePath] ) {
            request = [fileTransferAgent uploadFileRequest:obTask.localFilePath to:obTask.remoteUrl withParams:obTask.params];
            NSString * tmpFile = [self temporaryFile:obTask.marker];
            // If the file already exists, we should delete it...
            if ( [[NSFileManager defaultManager] fileExistsAtPath:tmpFile] ) {
                [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:&error];
                if ( error != nil )
                    OB_ERROR(@"FTM: createNsTaskFromObTask: Unable to delete existing temporary file %@",tmpFile);
                else
                    OB_DEBUG(@"FTM: createNsTaskFromObTask: Deleted existing tmp file %@",tmpFile);
                
                error = nil;
            }
            if ( fileTransferAgent.hasMultipartBody ) {
                if ( ![[request HTTPBody] writeToFile:tmpFile atomically:NO] ) {
                    error = [self createNSErrorForCode:OBFTMTmpFileCreateError];
                }
            } else {
                [[NSFileManager defaultManager] copyItemAtPath:obTask.localFilePath toPath:tmpFile error:&error];
                if ( error != nil )
                    OB_ERROR(@"FTM: createNsTaskFromObTask: Unable to copy file %@ to temporary file %@",obTask.localFilePath, tmpFile);
            }
            
            if ( error == nil ) {
                [self.transferTaskManager update:obTask withLocalFilePath:tmpFile];
            } else {
                OB_ERROR(@"FTM: createNsTaskFromObTask: Unable to create transfer task because of error: %@", error.localizedDescription );
                return nil;
            }
            
        } else {
            // Create the request w/o the file - just an optimization.
            request = [fileTransferAgent uploadFileRequest:nil to:obTask.remoteUrl withParams:obTask.params];
        }
        if ( !self.foregroundTransferOnly )
            request.networkServiceType = NSURLNetworkServiceTypeBackground;
        // For now hardcode this!
        request.allowsCellularAccess = YES;
        task = [[self session] uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:obTask.localFilePath]];
        
    } else {
        NSMutableURLRequest *request = [fileTransferAgent downloadFileRequest:obTask.remoteUrl withParams:obTask.params];
        if ( !self.foregroundTransferOnly )
            request.networkServiceType = NSURLNetworkServiceTypeBackground;
        // For now hardcode this!
        request.allowsCellularAccess = YES;
        
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

// ------
// Upload & Download Completion Handling
// ------

//------
// Error
//------
// NOTE::: This gets called for upload and download when the task is complete, possibly w/ framework or server error (server error has bad response code which we cast into an NSError).
// NOTE: Server errors are not reported through the error parameter. The only errors your delegate receives through the error parameter are client-side errors, such as being unable to resolve the hostname or connect to the host. Server errors need to be discerned from the response.
- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)clientError
{
    OBFileTransferTask * obtask = [[self transferTaskManager] transferTaskForNSTask:task];
    if ( obtask == nil ) {
        if ( clientError.code == NSURLErrorCancelled )
            OB_INFO(@"Unable to find reference for task Identifier %lu because it had been cancelled",(unsigned long)task.taskIdentifier);
        else
            OB_ERROR(@"Unable to find reference for task Identifier %lu",(unsigned long)task.taskIdentifier);
        return;
    }
    
    
    NSString *marker = obtask.marker;
    NSHTTPURLResponse *response =   (NSHTTPURLResponse *)task.response;
    NSError *serverError = [self createErrorFromHttpResponse:response.statusCode];
    
    if ( task.state != NSURLSessionTaskStateCompleted ) {
        OB_ERROR(@"Indicated that task completed but state = %d", (int) task.state );
        return;
    }
    
    NSError *error = nil;
    NSString *transferType = obtask.typeUpload ? @"Upload" : @"Download";
    
    // No error.
    if (serverError == nil && clientError == nil){
        if (obtask.typeUpload){
            [self uploadCompleted: obtask];
        } else if (obtask.status != FileTransferDownloadFileReady ) {
            error = [self createNSErrorForCode: OBFTMTmpDownloadFileCopyError];
        }
        [self handleCompleted:task obtask:obtask error:error];
        OB_INFO(@"%@ for %@ done", transferType, marker);
        return;
    }
    
    // Error. (More readable than nested else statments.)
    if (serverError != nil || clientError != nil) {
        if (clientError != nil){
            OB_WARN(@"%@ File Transfer for %@ received client error: %@", transferType, marker, clientError);
            error = clientError;
        }
        
        
        if (serverError != nil){
            OB_WARN(@"%@ File Transfer for %@ received server error %@",transferType, marker, serverError);
            error = serverError;
        }
        
        BOOL shouldRetry =  ( [self isRetryableClientError:clientError] && [self isRetryableServerError:serverError] ) &&
        ( self.maxAttempts == 0 ||  obtask.attemptCount < self.maxAttempts);
        
        if ( shouldRetry ) {
            [[self transferTaskManager] queueForRetry:obtask];
            [self setupRetryTimer];
            [self.delegate fileTransferRetrying:marker attemptCount: obtask.attemptCount  withError:error];
        } else {
            [self handleCompleted:task obtask:obtask error:error];
            OB_WARN(@"%@ for %@ done with error %@", transferType, marker, error);
        }
    }
}

// Note this is correct handling for S3 errors. If we find that various agents are different with respect to determining permanent failures
// then we probably need to move this method in the agent.
- (BOOL) isRetryableServerError:(NSError *)error{
    if (error == nil)
        return YES;
    
    if (error.code/100 == 4)
        return NO;
    
    if (error.code == 501)
        return NO;
    
    if (error.code == 301)
        return NO;
    
    return YES;
}

- (BOOL) isRetryableClientError:(NSError *)error{
    switch (error.code) {
            // Retry these
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorDataLengthExceedsMaximum:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorHTTPTooManyRedirects:
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorRedirectToNonExistentLocation:
        case NSURLErrorBadServerResponse:
        case NSURLErrorUserCancelledAuthentication:
        case NSURLErrorUserAuthenticationRequired:
        case NSURLErrorZeroByteResource:
        case NSURLErrorCannotDecodeRawData:
        case NSURLErrorCannotDecodeContentData:
        case NSURLErrorCannotParseResponse:
        case NSURLErrorInternationalRoamingOff:
        case NSURLErrorCallIsActive:
        case NSURLErrorDataNotAllowed:
        case NSURLErrorRequestBodyStreamExhausted:
        case NSURLErrorNoPermissionsToReadFile:
        case NSURLErrorSecureConnectionFailed:
        case NSURLErrorServerCertificateHasBadDate:
        case NSURLErrorServerCertificateUntrusted:
        case NSURLErrorServerCertificateHasUnknownRoot:
        case NSURLErrorServerCertificateNotYetValid:
        case NSURLErrorClientCertificateRejected:
        case NSURLErrorClientCertificateRequired:
        case NSURLErrorCannotLoadFromNetwork:
        case NSURLErrorCannotCreateFile:
        case NSURLErrorCannotOpenFile:
        case NSURLErrorCannotCloseFile:
        case NSURLErrorCannotWriteToFile:
        case NSURLErrorCannotRemoveFile:
        case NSURLErrorCannotMoveFile:
        case NSURLErrorDownloadDecodingFailedMidStream:
        case NSURLErrorDownloadDecodingFailedToComplete:
            return YES;
            
            // Dont Retry these
        case NSURLErrorResourceUnavailable:
        case NSURLErrorFileDoesNotExist:
        case NSURLErrorFileIsDirectory:
            return NO;
            
        default:
            return YES;
    }
    return YES;
}



// ------
// Upload
// ------

- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSString *marker = [[self transferTaskManager] markerForNSTask:task];
    double percentDone = 100*totalBytesSent/totalBytesExpectedToSend;
    OB_DEBUG(@"Upload progress %@: %lu%% [sent:%llu, of:%llu]", marker, (unsigned long)percentDone, totalBytesSent, totalBytesExpectedToSend);
    if ( [self.delegate respondsToSelector:@selector(fileTransferProgress:progress:)] ) {
        NSString *marker = [[self transferTaskManager] markerForNSTask:task];
        OBTransferProgress progress = {
            .bytesWritten = totalBytesSent,
            .totalBytes = totalBytesExpectedToSend,
            .percentDone = percentDone
        };
        
        [self.delegate fileTransferProgress: marker progress:progress];
    }
}

// --------
// Download
// --------

// Download progress
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSString *marker = [[self transferTaskManager] markerForNSTask:task];
    double percentDone = 100*totalBytesWritten/totalBytesExpectedToWrite;
    OB_DEBUG(@"Download progress %@: %lu%% [received:%llu, of:%llu]", marker, (unsigned long)percentDone, totalBytesWritten, totalBytesExpectedToWrite);
    if ( [self.delegate respondsToSelector:@selector(fileTransferProgress:progress:)] ) {
        NSString *marker = [[self transferTaskManager] markerForNSTask:task];
        OBTransferProgress progress = {
            .bytesWritten = totalBytesWritten,
            .totalBytes = totalBytesExpectedToWrite,
            .percentDone = percentDone
        };
        [self.delegate fileTransferProgress: marker progress:progress];
    }
}

// Completed the download
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    OBFileTransferTask * obtask = [[self transferTaskManager] transferTaskForNSTask:downloadTask];
    NSHTTPURLResponse *response =   (NSHTTPURLResponse *)downloadTask.response;
    if ( response.statusCode/100 == 2   ) {
        // Now we need to copy the file to our downloads location...
        NSError * error;
        NSString *localFilePath = [[[self transferTaskManager] transferTaskForNSTask: downloadTask] localFilePath];
        
        // If the file already exists, remove it and overwrite it
        if ( [[NSFileManager defaultManager] fileExistsAtPath:localFilePath] ) {
            [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&error];
        }
        
        [[NSFileManager defaultManager] copyItemAtPath:location.path toPath:localFilePath  error:&error];
        if ( error != nil ) {
            OB_ERROR(@"Unable to copy downloaded file to '%@' due to error: %@",localFilePath,error.localizedDescription);
        } else {
            [self.transferTaskManager update:obtask withStatus: FileTransferDownloadFileReady];
        }
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
    completionHandler(NSURLSessionAuthChallengeUseCredential,challenge.proposedCredential);
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
            /*
             The apple docs say you should terminate the background task you requested when they call the expiration handler or before or they will terminate your app. I have found through testing however that if you dont terminate and if the usage of the phone is low by other apps they will let your app run in the background indefinitely even after the backgroundTimeRemaining has long gone to 0. This allows retries to continue for longer than the single background period of a max of 10 minutes in the case of poor coverage. If the line below is not commented out we are only able to retry for the span of a single backgroundTask duration which is 180seconds to start with then 10minutes as your app gains reputation.
             
             [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];
             */
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }];
    }
}

-(void) updateBackground
{
    if (  self.backgroundTaskIdentifier != UIBackgroundTaskInvalid ) {
        if ( [self.transferTaskManager pendingTasks].count == 0 ) {
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

// This sets up the transfer task manager so it's ready and not created lazily
-(void) setupTransferTaskManager
{
    [self transferTaskManager];
}


// If the downloads are always going to a particular directory, you can just set
// the downloadDirectory property and from then on pass the filename only
-(NSString* )normalizeLocalDownloadPath: (NSString * )filePath
{
    if ( _downloadDirectory == nil || [filePath characterAtIndex:0] == '/')
        return filePath;
    else
        return [NSString pathWithComponents:@[_downloadDirectory,filePath ]];
}

// If the uploads are always coming from a particular directory, you can just set
// the uploadDirectory property and from then on pass the filename only
-(NSString *) normalizeLocalUploadPath: (NSString *)filePath
{
    if ( _uploadDirectory == nil || [filePath characterAtIndex:0] == '/' )
        return filePath;
    else
        return [NSString pathWithComponents:@[_uploadDirectory,filePath ]];
}

// Add the remote path base to the remote path that is provided if necessary.  If the
// remote path is already fully formed, that is, includes the protocol, then no need
// to do anything
// Note that it is possible for the client to just provide a path and not have set the baseUrl - this will
// generate an error
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
            //            If directory doesn't exist, create it
            if ( ![[NSFileManager defaultManager] fileExistsAtPath:_tempDirectory] ) {
                NSError *error;
                if ( ![[NSFileManager defaultManager] createDirectoryAtPath:_tempDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
                    OB_ERROR(@"Unable to create temporary directory %@ with error %@", _tempDirectory, error.localizedDescription);
                }
            }
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
        error = [NSError errorWithDomain:NSURLErrorDomain code:responseCode userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return error;
}

-(NSError *) createNSErrorForCode: (OBFTMErrorCode) code
{
    return [NSError errorWithDomain:[OBFTMError errorDomain] code: code userInfo:@{NSLocalizedDescriptionKey:[OBFTMError localizedDescription:code]}];
}

// Returns the timer value (in seconds) given the retry attempt
-(NSTimeInterval) retryTimeoutValue: (NSUInteger)retryAttempt
{
    //    return (NSTimeInterval)10.0;
    return (NSTimeInterval)10*(1<<(retryAttempt-1));
}

@end
