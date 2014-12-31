//
//  OBFileTransferAgentProtocol.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/27/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol OBFileTransferAgentProtocol <NSObject>
- (instancetype) initWithConfig: (NSDictionary *)configParams;
- (NSMutableURLRequest *) downloadFileRequest:(NSString *)sourcefileUrl withParams: (NSDictionary *)params;
- (NSMutableURLRequest *) uploadFileRequest:(NSString *)filePath to:(NSString *)targetFileUrl withParams: (NSDictionary *)params;
/**
 * deleteFile is synchronous and returns an http response code.
 */
- (NSError *) deleteFile:(NSString *)targetFileUrl;
- (BOOL) hasMultipartBody;
@end
