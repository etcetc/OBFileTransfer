//
//  OBFileTransferTaskManager.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/28/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OBFileTransferTask.h"

@interface OBFileTransferTaskManager : NSObject

-(OBFileTransferTask *) trackUploadTo: (NSString *)remoteUrl fromFilePath:(NSString *)filePath withMarker:(NSString *)marker withParams: (NSDictionary *)params;
-(OBFileTransferTask *) trackDownloadFrom: (NSString *)remoteUrl toFilePath:(NSString *)filePath withMarker: (NSString *)marker withParams: (NSDictionary *)params;

-(NSString *) markerForNSTask:(NSURLSessionTask *)task;
-(OBFileTransferTask *) transferTaskForNSTask: (NSURLSessionTask *)task;
-(OBFileTransferTask *) transferTaskWithMarker:(NSString *)marker;
-(void) removeTransferTaskForNsTask:(NSURLSessionTask *)nsTask;
-(void) removeTaskWithMarker:(NSString *)marker;

-(void)  updateRetryTimerCount;
-(void)  resetRetryTimerCount;

// Reset all the retry history for all pending tasks
-(void) resetRetries;
-(void) queueForRetry: (OBFileTransferTask *) obTask;

// Change the task state
-(void) processing: (OBFileTransferTask *) obTask withNsTask: (NSURLSessionTask *) nsTask;
-(void) update: (OBFileTransferTask *)obTask  withStatus: (OBFileTransferTaskStatus) status;
-(void) update: (OBFileTransferTask *)obTask  withLocalFilePath: (NSString *) localFilePath;

-(void) reset;
-(void) restoreState;

-(NSArray *) currentState;
-(NSArray *) pendingTasks;

//This is a bit of a hack, put here because it makes it easier to perist.  However, the task manager is not responsible
//for the retry timer, so it's just storing this value for its client.
@property (nonatomic) NSInteger retryTimerCount;

@end
