//
//  OBViewController.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/20/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBViewController.h"
#import <OBLogger/OBLogger.h>
#import "OBTransferView.h"
#import "OBS3FileTransferAgent.h"
#import <OBFileTransfer/OBServerFileTransferAgent.h>
#import <OBFileTransfer/OBGoogleCloudStorageFileTransferAgent.h>
#import <OBFileTransfer/OBS3FileTransferAgent.h>

typedef enum : NSUInteger {
    OBServerFileStore = 0,
    OBS3FileStore = 1,
    OBGCloudFileSTore = 2
} OBMyFileStore;


@interface OBViewController ()
@property (nonatomic) NSMutableDictionary * transferViews;
@property (nonatomic) OBFileTransferManager * fileTransferManager;
@property (nonatomic,strong) NSString * baseUrl;
@property (nonatomic) OBMyFileStore targetFileStore;
@property (nonatomic,strong) NSDictionary * configParams;
@end

// IMPORTANT - set these values here or in a file called config.plist
// Make sure to look @ the config values required by the file transfer agents of interest as well
#define SERVER_URL @"ENTER VALUE HERE"
#define SERVER_DOWNLOAD_PATH @"ENTER VALUE HERE/"
#define SERVER_UPLOAD_PATH @"ENTER VALUE HERE/"

#define AWS_TVM_SERVER_URL @"ENTER VALUE HERE"
#define AWS_REGION @"ENTER VALUE HERE"
#define S3_BUCKET_NAME @"ENTER VALUE HERE"

#define GS_PROJECT_ID @"ENTER VALUE HERE"
#define GS_API_KEY @"ENTER VALUE HERE"
#define GS_BUCKET_NAME @"ENTER VALUE HERE.onebeat.com"

// Make sure to put a slash at the end of the directory path here

NSString * const OBServerUrlParam = @"ServerUrl";
NSString * const OBServerUploadPath = @"ServerUploadPath";
NSString * const OBServerDownloadPath = @"ServerDownloadPath";
NSString * const OBS3BucketNameParam = @"S3BucketName";
NSString * const OBGSBucketNameParam = @"GoogleCloudStorageBucketName";

@implementation OBViewController


// --------------
// Lazy instantiations
// --------------
-(NSMutableDictionary *) transferViews
{
    if ( _transferViews == nil )
        _transferViews =  [NSMutableDictionary new];
    return _transferViews;
}

-(OBFileTransferManager *) fileTransferManager
{
    if ( _fileTransferManager == nil ) {
        _fileTransferManager =[OBFileTransferManager instance];
        [_fileTransferManager configure: self.configParams];
        _fileTransferManager.delegate = self;
        
        _fileTransferManager.remoteUrlBase = self.baseUrl;

        //    Set the download directory to be the documents directory if it has not been set
        if ( self.configParams[OBFTMDownloadDirectoryParam] == nil )
            _fileTransferManager.downloadDirectory = [self documentDirectory];
        
//        Other possible configurations:
//        Set the maximum number of retries to 2 (else it is infinited by default)
//        _fileTransferManager.maxAttempts = 2;
        
    }
    return _fileTransferManager;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setup];
    OB_INFO(@"START");
}

-(void) setup
{
    [self setupConfigFromPlist];
    if ( self.configParams == nil ) {
        OB_INFO(@"Setting configuration parameters from constants");
        self.configParams = @{
                              OBS3TvmServerUrlParam:AWS_TVM_SERVER_URL,
                              OBS3RegionParam: AWS_REGION,
                              OBS3BucketNameParam: S3_BUCKET_NAME,

                              OBGoogleCloudStorageProjectId: GS_PROJECT_ID,
                              OBGoogleCloudStorageApiKey: GS_API_KEY,
                              OBGSBucketNameParam: GS_BUCKET_NAME,
                              
                              OBServerUrlParam: SERVER_URL,
                              OBServerDownloadPath: SERVER_DOWNLOAD_PATH,
                              OBServerUploadPath: SERVER_UPLOAD_PATH
                              };

    }
    [self setFileStore: OBServerFileStore];
    [self displayPending];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UI Actions

// NOTE: these are files that we know are there!
//       Downloaded files may have to be seeded to the directories where they are read from
-(IBAction)start:(id)sender
{
    [self clearTransferViews];
    [self.fileTransferManager reset:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
            [self displayPending];
//            [self uploadFile: @"uploadtest_vsmall.jpg"];
//            [self uploadFile: @"uploadtest_medium.jpg"];
//            [self downloadFile:@"downloadtest_large.jpg"];
//            [self downloadFile:@"downloadtest_medium.jpg"];
            [self deleteFile:@"test6054.jpg"];
//            [self downloadFile:@"test9062_nothere.jpg"];
        }];
    }];
}

-(IBAction)retryPending:(id)sender
{
    [self clearTransferViews];
    for ( NSDictionary * taskInfo in [self.fileTransferManager currentState] ) {
        NSString * filename;
        if ( [taskInfo[TypeUploadKey] boolValue] ) {
             filename = taskInfo[ParamsKey][FilenameParamKey];
        } else
            filename = [taskInfo[LocalFilePathKey] lastPathComponent];
        
        [self addTransferView: filename isUpload:[taskInfo[TypeUploadKey] boolValue]];
    }
    [self.fileTransferManager retryPending];
    [self displayPending];
}

// Change the file store and appropriate URL
- (IBAction)changedFileStore:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0:
            [ self setFileStore:OBServerFileStore];
            break;
        case 1:
            [ self setFileStore:OBS3FileStore];
            break;
            
        case 2:
            [ self setFileStore:OBGCloudFileSTore];
            break;
            
        default:
            break;
    }
}

- (IBAction)changedFileStoreUrl:(id)sender {
    self.baseUrl = self.baseUrlInput.text;
    self.fileTransferManager.remoteUrlBase = self.baseUrl;
}


-(void) setFileStore: (OBMyFileStore) fileStore
{
    self.targetFileStore = fileStore;
//    A bit of a hack mapping the enum values to the UI segmented index
    self.fileStoreControl.selectedSegmentIndex = fileStore;
    [self setDefaultURLs];
    self.fileTransferManager.remoteUrlBase = self.baseUrl;
}

#pragma mark - FileTransferDelegate Protocol

-(void)fileTransferCompleted:(NSString *)markerId withError:(NSError *)error
{
    OB_INFO(@"Completed file transfer with marker %@ and error %@",markerId,error.localizedDescription);
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [(OBTransferView *)self.transferViews[markerId] updateStatus:error == nil ? Success : Error];
        [self displayPending];
    }];
    
}

-(void)fileTransferRetrying:(NSString *)markerId attemptCount: (NSUInteger)attemptCount withError:(NSError *)error
{
    OB_INFO(@"File transfer with marker %@ pending retry",markerId);
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [(OBTransferView *)self.transferViews[markerId] updateProgress:0.0];
        [(OBTransferView *)self.transferViews[markerId] updateStatus:PendingRetry retryCount:attemptCount-1];
        [self displayPending];
    }];
}

-(void) fileTransferProgress: (NSString *)markerId progress:(OBTransferProgress)progress
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [(OBTransferView *)self.transferViews[markerId] updateProgress:progress.percentDone];
    }];
}

//-(NSTimeInterval) retryTimeoutValue:(NSInteger)retryAttempt
//{
//    return (NSTimeInterval) 3;
//}
//
#pragma mark - Utility

-(void) displayPending
{
    self.pendingInfo.text = [self.fileTransferManager pendingSummary];
}

-(void) uploadFile: (NSString *)filename
{
    NSString * uploadPath =@"";
    if ( self.targetFileStore == OBServerFileStore )
        uploadPath = self.configParams[OBServerUploadPath];
    
    NSString * localFilePath = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
    NSString *targetFilename = [NSString stringWithFormat:@"test%d.jpg", arc4random_uniform(10000)];
    [self.fileTransferManager uploadFile:localFilePath to:uploadPath withMarker:targetFilename withParams:@{FilenameParamKey: targetFilename}];
    [self addTransferView:targetFilename isUpload:YES];
    
}

-(void) downloadFile: (NSString *)filename
{
    NSString * downloadPath=@"";
    if ( self.targetFileStore == OBServerFileStore )
        downloadPath = self.configParams[OBServerDownloadPath];
    
    [self.fileTransferManager downloadFile:[downloadPath stringByAppendingString:filename] to:filename withMarker:filename withParams:nil];
    [self addTransferView:filename isUpload:NO];
}

- (void) deleteFile: (NSString *)filename{
    OB_INFO(@"deleteFile: %@", [self.fileTransferManager deleteFile:@"test9857.jpg"]);
}

-(void) addTransferView: (NSString *) fileName isUpload: (BOOL) isUpload
{
    OBTransferView *transferView = [[OBTransferView alloc] initInRow: self.transferViews.count];
    [transferView startTransfer:fileName upload:isUpload ? Upload : Download];
    [self.transferViewArea addSubview:transferView];
    self.transferViews[fileName] = transferView;
}

-(void) clearTransferViews
{
    for ( UIView * view in self.transferViewArea.subviews )
        [view removeFromSuperview];
    [self.transferViews removeAllObjects];
}

-(void) setDefaultURLs
{
    if ( self.targetFileStore == OBS3FileStore )
        self.baseUrl = [NSString stringWithFormat:@"s3://%@",self.configParams[OBS3BucketNameParam]];
    else if ( self.targetFileStore == OBGCloudFileSTore )
        self.baseUrl = [NSString stringWithFormat:@"gs://%@",self.configParams[OBGSBucketNameParam]];
    else if ( self.targetFileStore == OBServerFileStore )
        self.baseUrl = self.configParams[OBServerUrlParam];
    else
        [NSException exceptionWithName:@"OBFileStoreError" reason:@"Unknown file store" userInfo:nil];
    self.baseUrlInput.text = self.baseUrl;
}

// Put files in document directory
-(NSString *) documentDirectory
{
    NSArray * urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                            inDomains:NSUserDomainMask];
    if ( urls.count > 0 ) {
        return [(NSURL *)urls[0] URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]].path;
    } else
        return nil;
}


- (IBAction)reset:(id)sender {
    [self.fileTransferManager reset: ^{
        [self displayPending];
        [self clearTransferViews];
    }];
}

- (IBAction)showLog:(id)sender {
    OBLogViewController *logViewer = [OBLogViewController instance];
    [self presentViewController:logViewer animated:YES completion:nil];
}

- (IBAction)restart:(id)sender {
    [[self fileTransferManager] restartAllTasks:^{
        OB_INFO(@"Finished restarting the tasks");
    }];
}

//
//
-(NSDictionary *) setupConfigFromPlist
{
    NSString *plistFile = [[NSBundle mainBundle] pathForResource:@"config" ofType:@"plist"];
    if ( plistFile != nil ) {
        OB_INFO(@"Reading configuration parameters from config.plist ");
        self.configParams = [NSDictionary dictionaryWithContentsOfFile:plistFile];
    }
    return nil;
}

@end
