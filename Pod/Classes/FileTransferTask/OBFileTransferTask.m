//
//  OBFileTransferTask.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/28/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBFileTransferTask.h"

@interface OBFileTransferTask()
@end

NSString * const OBFTMCreatedOnKey = @"created_on";
NSString * const OBFTMTypeUploadKey = @"upload";
NSString * const OBFTMMarkerKey = @"marker";
NSString * const OBFTMNSTaskIdentifierKey = @"nsTaskIdentifier";
NSString * const OBFTMRemoteUrlKey = @"remoteUrl";
NSString * const OBFTMLocalFilePathKey = @"localFilePath";
NSString * const OBFTMParamsKey = @"params";
NSString * const OBFTMAttemptsKey = @"attempts";
NSString * const OBFTMStatusKey = @"status";
NSString * const OBFTMCountOfBytesExpectedToReceiveKey = @"CountOfBytesExpectedToReceiveKey";
NSString * const OBFTMCountOfBytesReceivedKey  = @"CountOfBytesReceivedKey";
NSString * const OBFTMCountOfBytesExpectedToSendKey  = @"CountOfBytesExpectedToSendKey";
NSString * const OBFTMCountOfBytesSentKey  = @"CountOfBytesSentKey";



@implementation OBFileTransferTask

-(instancetype) init
{
    if ( self = [super init] ) {
        self.createdOn = [NSDate date];
        self.attemptCount = 0;
    }
    return self;
}

#pragma mark - Descriptors
-(NSString *) statusDescription
{
    switch (self.status) {
        case FileTransferInProgress:
            return @"Processing";
            break;
        case FileTransferPendingRetry:
            return @"Pending";
            break;
        case FileTransferDownloadFileReady:
            return @"Downloaded";
            break;
        default:
            break;
    }
    return @"WTF! ";
}

-(NSString *)transferDirection
{
    return self.typeUpload ? @"Upload" : @"Download";
}

-(NSString *) description {
    return [NSString stringWithFormat:@"%@ %@ task '%@' id %lu remote:%@ local:%@ [%ld]", [self statusDescription],self.transferDirection, self.marker, (unsigned long)self.nsTaskIdentifier, self.remoteUrl, self.localFilePath,(long)self.attemptCount];
}

-(NSDictionary *) info
{
    return [self asDictionary];
}


#pragma mark - Encoding/Serialization

// Some methods to help w/ archiving the state
// WARNING - not used right now but keep around just in case....
-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.createdOn forKey:OBFTMCreatedOnKey];
    [aCoder encodeBool:self.typeUpload forKey:OBFTMTypeUploadKey];
    [aCoder encodeObject:self.marker forKey:OBFTMMarkerKey];
    [aCoder encodeInteger:self.nsTaskIdentifier forKey:OBFTMNSTaskIdentifierKey];
    [aCoder encodeObject:self.remoteUrl forKey:OBFTMRemoteUrlKey];
    [aCoder encodeObject:self.localFilePath forKey:OBFTMLocalFilePathKey];
    [aCoder encodeObject:self.params forKey:OBFTMParamsKey];
    [aCoder encodeInteger:self.attemptCount forKey:OBFTMAttemptsKey];
    [aCoder encodeInteger:self.status forKey:OBFTMStatusKey];
}

// WARNING - not used right now but keep around just in case....
-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
    if ( self = [super init] ) {
        self.createdOn = [aDecoder decodeObjectForKey:OBFTMCreatedOnKey];
        self.typeUpload = [aDecoder decodeBoolForKey:OBFTMTypeUploadKey];
        self.marker = [aDecoder decodeObjectForKey:OBFTMMarkerKey];
        self.nsTaskIdentifier = [aDecoder decodeIntegerForKey:OBFTMNSTaskIdentifierKey];
        self.remoteUrl = [aDecoder decodeObjectForKey:OBFTMRemoteUrlKey];
        self.localFilePath = [aDecoder decodeObjectForKey:OBFTMLocalFilePathKey];
        self.params = [aDecoder decodeObjectForKey:OBFTMParamsKey];
        self.attemptCount = [aDecoder decodeIntegerForKey:OBFTMAttemptsKey];
        self.status = [aDecoder decodeIntegerForKey:OBFTMStatusKey];
    }
    return self;
}

// Simplify the object so we can save it as a dictionary and restore it appropriately
-(NSDictionary *) asDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[OBFTMCreatedOnKey] = self.createdOn;
    dict[OBFTMTypeUploadKey] = [NSNumber numberWithBool:self.typeUpload];
    dict[OBFTMMarkerKey] = self.marker;
    dict[OBFTMNSTaskIdentifierKey] = [NSNumber numberWithInteger:self.nsTaskIdentifier];
    dict[OBFTMRemoteUrlKey] = self.remoteUrl;
    dict[OBFTMLocalFilePathKey] = self.localFilePath;
    if ( self.params !=  nil ) dict[OBFTMParamsKey] = self.params;
    dict[OBFTMAttemptsKey] = [NSNumber numberWithInteger:self.attemptCount];
    dict[OBFTMStatusKey] = [NSNumber numberWithInteger:self.status];
    
    return dict;
}

-(instancetype) initFromDictionary:(NSDictionary *)dict
{
    if ( [self init] ) {
        self.createdOn = dict[OBFTMCreatedOnKey];
        self.typeUpload = [dict[OBFTMTypeUploadKey] boolValue];
        self.marker = dict[OBFTMMarkerKey];
        self.nsTaskIdentifier = [dict[OBFTMNSTaskIdentifierKey] integerValue];
        self.remoteUrl = dict[OBFTMRemoteUrlKey];
        self.localFilePath = dict[OBFTMLocalFilePathKey];
        self.params = dict[OBFTMParamsKey];
        self.attemptCount = [dict[OBFTMAttemptsKey] integerValue];
        self.status = [dict[OBFTMStatusKey] integerValue];
    }
    
    return self;
}

@end
