//
//  OBFileTransferAgentBase.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/27/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBFileTransferAgent.h"

@implementation OBFileTransferAgent

NSString *const FilenameParamKey = @"_filename";
NSString *const ContentTypeParamKey = @"_contentType";
NSString *const kOBFileTransferMetadataKey = @"_metadata";

- (instancetype)initWithConfig:(NSDictionary *)configParams
{
    return [self init];
}

//-------------------------------------
// Methods to be overridden by subclass
//-------------------------------------
- (NSMutableURLRequest *)downloadFileRequest:(NSString *)sourcefileUrl withParams:(NSDictionary *)params
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Please override method %@ in your subclass",
                       NSStringFromSelector(_cmd)];
    return nil;
}

- (NSMutableURLRequest *)uploadFileRequest:(NSString *)filePath
                                        to:(NSString *)targetFileUrl
                                withParams:(NSDictionary *)params
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Please override method %@ in your subclass",
                       NSStringFromSelector(_cmd)];
    return nil;
}

- (NSError *)deleteFile:(NSString *)targetFileUrl
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Please override method %@ in your subclass",
                       NSStringFromSelector(_cmd)];
    return nil;
}

// By default the transfer agent is not encoding a body - the file is what it is
- (BOOL)hasMultipartBody
{
    return NO;
}


- (NSDictionary *)removeSpecialParams:(NSDictionary *)params
{
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:params];
    [p removeObjectForKey:FilenameParamKey];
    [p removeObjectForKey:ContentTypeParamKey];
    return p;
}

- (NSString *)filenameFromFilepath:(NSString *)filePath
{
    return [[filePath componentsSeparatedByString:@"/"] lastObject];
}

- (NSString *)mimeTypeFromFilename:(NSString *)filename
{
    NSString *extension = [[filename componentsSeparatedByString:@"."] lastObject];
    return [self mimeTypes][extension];
}

- (NSDictionary *)mimeTypes
{
    static NSDictionary *mimeTypes;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error;
        NSString *mimeTypesPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"mimeTypes" ofType:@"txt"];
        // read everything from text
        NSString *fileContents = [NSString stringWithContentsOfFile:mimeTypesPath
                                                           encoding:NSUTF8StringEncoding
                                                              error:&error];

        if (error != nil)
        {
            [NSException raise:@"Unable to read file mimeTypes.txt" format:@""];
        }

        NSArray *lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        NSMutableDictionary *types = [NSMutableDictionary new];
        for (NSString *line in lines)
        {
            NSArray *split = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (split.count == 2)
            {
                types[split[0]] = split[1];
            }
            else
            {
                OB_WARN(@"Noncomformat line in mimeTypes.txt: %@", line);
            }
        }
        mimeTypes = [NSDictionary dictionaryWithDictionary:types];
    });
    return mimeTypes;
}

// Serializes parameters
// Courtesy of http://stackoverflow.com/questions/718429/creating-url-query-parameters-from-nsdictionary-objects-in-objectivec
- (NSString *)serializeParams:(NSDictionary *)params
{
    NSMutableArray *pairs = NSMutableArray.array;
    for (NSString *key in params.keyEnumerator)
    {
        id value = params[key];
        if ([value isKindOfClass:[NSDictionary class]])
            for (NSString *subKey in value)
                [pairs addObject:[NSString stringWithFormat:@"%@[%@]=%@",
                                                            key,
                                                            subKey,
                                                            [self escapeValueForURLParameter:[value objectForKey:subKey]]]];

        else if ([value isKindOfClass:[NSArray class]])
            for (NSString *subValue in value)
                [pairs addObject:[NSString stringWithFormat:@"%@[]=%@",
                                                            key,
                                                            [self escapeValueForURLParameter:subValue]]];

        else
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [self escapeValueForURLParameter:value]]];

    }
    return [pairs componentsJoinedByString:@"&"];
}

- (NSString *)escapeValueForURLParameter:(NSString *)valueToEscape
{
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)valueToEscape,
            NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
}

@end
