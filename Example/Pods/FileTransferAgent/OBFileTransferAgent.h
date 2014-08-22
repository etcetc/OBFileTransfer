//
//  OBFileTransferAgentBase.h
//  FileTransferPlay
//
//  Created by Farhad on 6/27/14.
//  Copyright (c) 2014 NoPlanBees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OBLogger.h"
#import "OBFileTransferAgentProtocol.h"

// These are special parameters that are used in the construction of the POST request
//  FilenameParamKey: contains the uploaded filename. Default: it is pulled from the input filename
//  ContentTypeParamKey: contains the content type to use.  Default: it is extracted from the filename extension.
//  FormFileFieldNameParamKey: contains the field name containing the file. Default: file.
extern NSString * const FilenameParamKey;
extern NSString * const ContentTypeParamKey;
extern NSString * const FormFileFieldNameParamKey;

typedef NS_ENUM(NSUInteger, OBFileStore) {
    OBStandardServer,
    OBS3
};


@interface OBFileTransferAgent : NSObject <OBFileTransferAgentProtocol>
@property (nonatomic) OBFileStore fileStore;

// Derive the mime type from the filename type extension
-(NSString *)mimeTypeFromFilename: (NSString *)filename;
-(NSDictionary *)removeSpecialParams: (NSDictionary *)params;
-(NSString *)serializeParams:(NSDictionary *)params;

@end
