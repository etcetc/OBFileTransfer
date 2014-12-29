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

NSString * const CreatedOnKey = @"created_on";
NSString * const TypeUploadKey = @"upload";
NSString * const MarkerKey = @"marker";
NSString * const NSTaskIdentifierKey = @"nsTaskIdentifier";
NSString * const RemoteUrlKey = @"remoteUrl";
NSString * const LocalFilePathKey = @"localFilePath";
NSString * const ParamsKey = @"params";
NSString * const AttemptsKey = @"attempts";
NSString * const StatusKey = @"status";
NSString * const CountOfBytesExpectedToReceiveKey = @"CountOfBytesExpectedToReceiveKey";
NSString * const CountOfBytesReceivedKey  = @"CountOfBytesReceivedKey";
NSString * const CountOfBytesExpectedToSendKey  = @"CountOfBytesExpectedToSendKey";
NSString * const CountOfBytesSentKey  = @"CountOfBytesSentKey";

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
    [aCoder encodeObject:self.createdOn forKey:CreatedOnKey];
    [aCoder encodeBool:self.typeUpload forKey:TypeUploadKey];
    [aCoder encodeObject:self.marker forKey:MarkerKey];
    [aCoder encodeInteger:self.nsTaskIdentifier forKey:NSTaskIdentifierKey];
    [aCoder encodeObject:self.remoteUrl forKey:RemoteUrlKey];
    [aCoder encodeObject:self.localFilePath forKey:LocalFilePathKey];
    [aCoder encodeObject:self.params forKey:ParamsKey];
    [aCoder encodeInteger:self.attemptCount forKey:AttemptsKey];
    [aCoder encodeInteger:self.status forKey:StatusKey];
}

// WARNING - not used right now but keep around just in case....
-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
    if ( self = [super init] ) {
        self.createdOn = [aDecoder decodeObjectForKey:CreatedOnKey];
        self.typeUpload = [aDecoder decodeBoolForKey:TypeUploadKey];
        self.marker = [aDecoder decodeObjectForKey:MarkerKey];
        self.nsTaskIdentifier = [aDecoder decodeIntegerForKey:NSTaskIdentifierKey];
        self.remoteUrl = [aDecoder decodeObjectForKey:RemoteUrlKey];
        self.localFilePath = [aDecoder decodeObjectForKey:LocalFilePathKey];
        self.params = [aDecoder decodeObjectForKey:ParamsKey];
        self.attemptCount = [aDecoder decodeIntegerForKey:AttemptsKey];
        self.status = [aDecoder decodeIntegerForKey:StatusKey];
    }
    return self;
}

// Simplify the object so we can save it as a dictionary and restore it appropriately
-(NSDictionary *) asDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[CreatedOnKey] = self.createdOn;
    dict[TypeUploadKey] = [NSNumber numberWithBool:self.typeUpload];
    dict[MarkerKey] = self.marker;
    dict[NSTaskIdentifierKey] = [NSNumber numberWithInteger:self.nsTaskIdentifier];
    dict[RemoteUrlKey] = self.remoteUrl;
    dict[LocalFilePathKey] = self.localFilePath;
    if ( self.params !=  nil ) dict[ParamsKey] = self.params;
    dict[AttemptsKey] = [NSNumber numberWithInteger:self.attemptCount];
    dict[StatusKey] = [NSNumber numberWithInteger:self.status];
    return dict;
}

-(instancetype) initFromDictionary:(NSDictionary *)dict
{
    if ( [self init] ) {
        self.createdOn = dict[CreatedOnKey];
        self.typeUpload = [dict[TypeUploadKey] boolValue];
        self.marker = dict[MarkerKey];
        self.nsTaskIdentifier = [dict[NSTaskIdentifierKey] integerValue];
        self.remoteUrl = dict[RemoteUrlKey];
        self.localFilePath = dict[LocalFilePathKey];
        self.params = dict[ParamsKey];
        self.attemptCount = [dict[AttemptsKey] integerValue];
        self.status = [dict[StatusKey] integerValue];
    }
    
    return self;
}

@end
