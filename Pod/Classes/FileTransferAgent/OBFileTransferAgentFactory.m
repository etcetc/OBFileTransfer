//
//  OBFileTransferAgentFactory.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/18/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBFileTransferAgentFactory.h"
#import "OBS3FileTransferAgent.h"
#import "OBServerFileTransferAgent.h"

@implementation OBFileTransferAgentFactory

+(OBFileTransferAgent *)fileTransferAgentInstance:(NSString *)remoteUrl
{
    if ( [remoteUrl rangeOfString:@"s3://"].location == 0 )
        return [OBS3FileTransferAgent new];
    else if ([remoteUrl rangeOfString:@"http://"].location == 0 || [remoteUrl rangeOfString:@"https://"].location == 0 )
        return [OBServerFileTransferAgent new];
    else
        return nil;
}

@end
