//
//  OBFileTransferTaskManager.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/28/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "OBFileTransferTaskManager.h"
#import <OBLogger/OBLogger.h>

@interface OBFileTransferTaskManager()
@property (nonatomic,strong) NSMutableArray *  tasks;
@property (strong) NSLock * arrayLock;
@end

@implementation OBFileTransferTaskManager
static dispatch_queue_t myQueue;

@synthesize arrayLock = _arrayLock;

+(instancetype) instance
{
    static dispatch_once_t obfttmOnceToken;
    static OBFileTransferTaskManager * instance = nil;
    dispatch_once(&obfttmOnceToken, ^{
        instance = [[self alloc] init];
        myQueue = dispatch_queue_create("OBFileTransferTaskManagerQueue", NULL);
        [instance initialize];
    });
    return instance;
}

// Call this to initialize the state variables
-(void) initialize
{
    _arrayLock  =[NSLock new];
    _tasks = [[NSMutableArray alloc] init];
    [self restoreState];
}

// Stop tracking all tasks and reset to a virgin state
-(void) reset
{
    OB_DEBUG(@"Resetting OB Tasks state");
    [_arrayLock lock];
    [self.tasks removeAllObjects];
    self.retryTimerCount = 0;
    [_arrayLock unlock];
    [self saveState];
}

// Warning: do not provide the same nsTask with a different marker, or vice versa
-(OBFileTransferTask *) trackUploadTo: (NSString *)remoteUrl fromFilePath:(NSString *)filePath withMarker:(NSString *)marker withParams: (NSDictionary *)params
{
    OBFileTransferTask * obTask = [[OBFileTransferTask alloc] init];
    if ( obTask != nil ) {
        obTask.marker = marker;
        obTask.typeUpload = YES;
        obTask.localFilePath = filePath;
        obTask.remoteUrl = remoteUrl;
        obTask.status = FileTransferInProgress;
        obTask.params = params;
    }
    [self removeTaskWithMarker:marker];
    [self addTask: obTask];
    return obTask;
}

-(OBFileTransferTask *) trackDownloadFrom: (NSString *)remoteUrl toFilePath:(NSString *)filePath withMarker: (NSString *)marker withParams: (NSDictionary *)params
{
    OBFileTransferTask * obTask = [[OBFileTransferTask alloc] init];
    if ( obTask != nil ) {
        obTask.marker = marker;
        obTask.typeUpload = NO;
        obTask.localFilePath = filePath;
        obTask.remoteUrl = remoteUrl;
        obTask.status = FileTransferInProgress;
        obTask.params = params;
    }
    [self removeTaskWithMarker:marker];
    [self addTask: obTask];
    return obTask;
}

-(NSArray *) currentState
{
    NSMutableArray *taskStates = [NSMutableArray new];
    for ( OBFileTransferTask * task in [self tasksCopy] ) {
        [taskStates addObject:task.info];
    }
    return taskStates;
}

-(NSString *) tasksSummary
{
    NSMutableString *tasksDesc = [NSMutableString stringWithString:@""];
    for ( OBFileTransferTask * task in [self tasksCopy] ) {
        NSString * statusStr;
        switch (task.status) {
            case FileTransferInProgress:
                statusStr = @"P";
                break;
            case FileTransferPendingRetry:
                statusStr = @"W";
                break;
            case FileTransferDownloadFileReady:
                statusStr = @"D";
                break;
            default:
                break;
        }
        [tasksDesc appendString:[NSString stringWithFormat:@"%@%@-%@,", task.typeUpload ? @"U" : @"D", statusStr, task.marker]];
    }
    if ([tasksDesc hasSuffix:@","])
        tasksDesc = (NSMutableString *)[tasksDesc substringToIndex:(tasksDesc.length - 1)];
    return tasksDesc;
}

-(NSArray *)processingTasks
{
    NSMutableArray *processing = [NSMutableArray new];
    for ( OBFileTransferTask * task in [self tasksCopy] ) {
        if ( task.status == FileTransferInProgress )
            [processing addObject:task];
    }
    return processing;
}

-(NSArray *)pendingTasks
{
    NSMutableArray *pending = [NSMutableArray new];
    for ( OBFileTransferTask * task in [self tasksCopy] ) {
        if ( task.status == FileTransferPendingRetry )
            [pending addObject:task];
    }
    return pending;
}

-(NSArray *) allTasks
{
    return [self tasksCopy];
}

-(void) queueForRetry: (OBFileTransferTask *) obTask
{
    obTask.status = FileTransferPendingRetry;
    [self saveState];
}

-(void) processing: (OBFileTransferTask *) obTask withNsTask: (NSURLSessionTask *) nsTask
{
    obTask.status = FileTransferInProgress;
    obTask.attemptCount++;
    obTask.nsTaskIdentifier = nsTask.taskIdentifier;
    OB_INFO(@"%@",obTask.description);
    [self saveState];
}

// TODO - replace with KVO at some point
-(void) update: (OBFileTransferTask *)obTask  withStatus: (OBFileTransferTaskStatus) status
{
    obTask.status = status;
    [self saveState];
}

// TODO - replace with KVO at some point
-(void) update: (OBFileTransferTask *)obTask  withLocalFilePath: (NSString *) localFilePath
{
    obTask.localFilePath = localFilePath;
    [self saveState];
}

// Finds a task which has the nsTask provided in the argument and returns its marker
-(NSString *)markerForNSTask:(NSURLSessionTask *)nsTask
{
    return [[self transferTaskForNSTask: nsTask] marker];
}

// We can remove a given task form the list of tasks that are being tracked
-(void) removeTransferTaskForNsTask:(NSURLSessionTask *)nsTask
{
    [self removeTask:[self transferTaskForNSTask:nsTask]];
}

// Removes a task with the indicated marker value
-(void) removeTaskWithMarker: (NSString *)marker
{
//    OB_DEBUG(@"Looking to remove task for marker %@ if it exists",marker);
    [self removeTask: [self transferTaskWithMarker:marker]];
}


-(OBFileTransferTask *) transferTaskForNSTask:(NSURLSessionTask *)nsTask
{
    for ( OBFileTransferTask * task in [self tasksCopy] ) {
        if ( task.nsTaskIdentifier == nsTask.taskIdentifier )
            return task;
    }
    OB_DEBUG(@"Unable to find OB Task for NS Task with identifier %lu",(unsigned long)nsTask.taskIdentifier);
    return nil;
}

-(OBFileTransferTask *) transferTaskWithMarker:(NSString *)marker
{
    for ( OBFileTransferTask * task in [self tasksCopy] ) {
        if ( [task.marker isEqualToString:marker] )
            return task;
    }
//    OB_DEBUG(@"Unable to find OB Task for marker %@",marker);
    return nil;
}

-(void) addTask: (OBFileTransferTask *) task
{
    [self.arrayLock lock];
    [self.tasks addObject:task];
    [self.arrayLock unlock];
    [self saveState];
}

-(void) removeTask: (OBFileTransferTask *) task
{
    if ( task != nil ) {
        [self.arrayLock lock];
        [[self tasks] removeObject:task];
        [self.arrayLock unlock];
        [self saveState];
    }
}

// Save and restore the current state of the tasks in a thread-safe manner by using a serial queue
// We want to make sure that saves occur chronologically, that a later thread doesnt save before a first thread
-(void) saveState
{
    dispatch_async(myQueue, ^{
        //    OB_DEBUG(@"Starting to save OBTasks state");
        NSMutableArray *tasksToSave = [[NSMutableArray alloc] init];
        for ( OBFileTransferTask *task in [self tasksCopy] ) {
            [tasksToSave addObject:[task asDictionary]];
        }
        NSDictionary *stateDictionary = @{@"tasks": tasksToSave, @"retryTimerCount": [NSNumber numberWithInteger:self.retryTimerCount]};
        BOOL wroteToFile = [stateDictionary writeToFile:self.statePlistFile atomically:YES];
        if ( !wroteToFile ) {
            OB_ERROR(@"Could not save tasks to %@",self.statePlistFile);
        } else {
            OB_DEBUG(@"Saved %lu tracked tasks: %@",(unsigned long)tasksToSave.count, [self tasksSummary] );
        }
    });
}

// This doesn't stricltly have to be synchronized because we only read it once when we initialize the object
-(void) restoreState
{
    @synchronized(self) {
    //    OB_DEBUG(@"Starting to restore OBTasks state");
        NSDictionary *stateDictionary;
        [self removeAllTasks];
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:self.statePlistFile] ) {
            OB_DEBUG(@"OBTasks file does not exist so saving current state");
            [self saveState];
        } else {
            stateDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:self.statePlistFile];
        }
        self.retryTimerCount = [stateDictionary[@"retryTimerCount"] integerValue];
        for ( NSDictionary *taskInfo in stateDictionary[@"tasks"] ) {
            [self.tasks addObject:[[OBFileTransferTask alloc] initFromDictionary:taskInfo]];
        }
        OB_DEBUG(@"Restored %lu tracked tasks: %@",(unsigned long)self.tasks.count, [self tasksSummary] );
    }
}

-(NSString *) statePlistFile
{
    static dispatch_once_t onceToken;
    static NSString * StatePlistFile;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory ,NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        StatePlistFile = [documentsDirectory stringByAppendingPathComponent:@"FileTransferTaskManager.plist"];
        NSLog(@"FileTransferTaskManager Plist File = %@", StatePlistFile);
    });
    return StatePlistFile;
}

-(void)  updateRetryTimerCount
{
    self.retryTimerCount++;
    [self saveState];
}

-(void) resetRetryTimerCount
{
    self.retryTimerCount=0;
    [self saveState];
}

-(void) resetRetries
{
    [self.arrayLock lock];
    for ( OBFileTransferTask *task in self.tasks ) {
        task.attemptCount = 0;
    }
    self.retryTimerCount = 0;
    [self.arrayLock unlock];
    [self saveState];
}

// Create an immutable copy of the tasks array
-(NSArray *) tasksCopy
{
    [self.arrayLock lock];
    NSArray *copy = [NSArray arrayWithArray:self.tasks];
    [self.arrayLock unlock];
    return copy;
}

- (void) removeAllTasks{
    [self.arrayLock lock];
    [self.tasks removeAllObjects];
    [self.arrayLock unlock];
}
@end

