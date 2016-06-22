//
//  OBFileTransferAgentFactory.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 7/18/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OBFileTransferAgent.h"
#import "OBS3FileTransferAgent.h"
#import "OBServerFileTransferAgent.h"
#import "OBGoogleCloudStorageFileTransferAgent.h"

@interface OBFileTransferAgentFactory : NSObject

+ (OBFileTransferAgent *)fileTransferAgentInstance:(NSString *)remoteUrl withConfig:(NSDictionary *)configParams;

@end
