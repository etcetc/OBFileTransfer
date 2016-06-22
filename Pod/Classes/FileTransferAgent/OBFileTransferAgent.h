//
//  OBFileTransferAgentBase.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/27/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OBLogger/OBLogger.h>
#import "OBFileTransferAgentProtocol.h"

// These are special parameters that are used in the construction of the POST request
//  FilenameParamKey: contains the uploaded filename. Default: it is pulled from the input filename
//  ContentTypeParamKey: contains the content type to use.  Default: it is extracted from the filename extension.
//  FormFileFieldNameParamKey: contains the field name containing the file. Default: file.
extern NSString *const FilenameParamKey;
extern NSString *const ContentTypeParamKey;
extern NSString *const kOBFileTransferMetadataKey;


@interface OBFileTransferAgent : NSObject <OBFileTransferAgentProtocol>

@property (nonatomic, strong) NSDictionary *configParams;

// Default initializer
- (instancetype)initWithConfig:(NSDictionary *)configParams;

// Derive the mime type from the filename type extension
- (NSString *)filenameFromFilepath:(NSString *)filePath;

- (NSString *)mimeTypeFromFilename:(NSString *)filename;

- (NSDictionary *)removeSpecialParams:(NSDictionary *)params;

- (NSString *)serializeParams:(NSDictionary *)params;

@end
