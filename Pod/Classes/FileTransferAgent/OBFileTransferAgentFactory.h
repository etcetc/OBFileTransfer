//
//  OBFileTransferAgentFactory.h
//  FileTransferPlay
//
//  Created by Farhad on 7/18/14.
//  Copyright (c) 2014 NoPlanBees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OBFileTransferAgent.h"

@interface OBFileTransferAgentFactory : NSObject

+(OBFileTransferAgent *) fileTransferAgentInstance: (NSString *) remoteUrl;

@end
