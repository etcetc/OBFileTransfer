//
//  OBFileTransferAgentFactory.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/18/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBFileTransferAgentFactory.h"

NSString * const kAgentsPlistFile = @"FileTransferAgents";

@interface OBFileTransferAgentFactory ()
@end

@implementation OBFileTransferAgentFactory

// Return an instance of the fileStore file transfer agent
// This reads the Class names from the fileStoreAgents.plist
// Config Params is a hash that contains the configuration params for all the protocols, so it's indexed by strings such as "s3", "http", etc.
+(OBFileTransferAgent *)fileTransferAgentInstance:(NSString *)remoteUrl withConfig: (NSDictionary *)configParams
{
    NSString *protocol;
    NSRange r = [remoteUrl rangeOfString:@"://"];
    if ( r.location == NSNotFound )
        [[NSException exceptionWithName:@"OBFTMRemoteProtocolNotFound" reason:@"Remote URL must contain protocol" userInfo:nil] raise];
    protocol = [remoteUrl substringToIndex:r.location];
    NSString * agentClassName = [self agents][protocol];
    if ( agentClassName == nil )
        [[NSException exceptionWithName:@"OBFTMProtocolAgentNotFound" reason:[NSString stringWithFormat:@"Agent for protocol %@ not found", protocol] userInfo:nil] raise];
    id agentClass = NSClassFromString(agentClassName);
    if ( agentClass == nil )
        [[NSException exceptionWithName:@"OBFTMProtocolAgentClassNotFound" reason:[NSString stringWithFormat:@"Class %@ not loaded", agentClassName] userInfo:nil] raise];
    return [[agentClass alloc ] initWithConfig:configParams];
}

+(NSDictionary *)agents
{
    static NSDictionary * _agents;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _agents = [self readPlistFile];
    });
    return _agents;
}

+(NSDictionary *) readPlistFile
{
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:kAgentsPlistFile ofType:@"plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ( filePath == nil || ![fileManager fileExistsAtPath: filePath] )
        [[NSException exceptionWithName:@"OBFTMAgentsPlistFileMissing" reason:@"Error: Unable to find the file transfer agents plist file" userInfo:nil] raise];
    
    return [NSDictionary dictionaryWithContentsOfFile:filePath];
}


@end
