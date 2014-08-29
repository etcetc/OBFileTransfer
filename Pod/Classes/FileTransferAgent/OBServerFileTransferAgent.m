//
//  OBServerFileTransferAgent.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/26/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBServerFileTransferAgent.h"

@implementation OBServerFileTransferAgent

NSString * const OBHttpFormBoundary = @"--------sdfllkjkjkli98ijj";

// Create a GET request to a standard URL.  Note that any parameters may be passed in the params
// structure or else be in the sourceFileUrl
- (NSMutableURLRequest *) downloadFileRequest:(NSString *)sourcefileUrl withParams:(NSDictionary *)params
{
    NSString *fullSourceFileUrl = sourcefileUrl;
    if ( params.count > 0 ) {
        if ( [sourcefileUrl rangeOfString:@"?"].location ==  NSNotFound )
            fullSourceFileUrl = [NSString stringWithFormat:@"%@?%@",sourcefileUrl,[self serializeParams:params]];
        else
            fullSourceFileUrl = [NSString stringWithFormat:@"%@&%@",sourcefileUrl,[self serializeParams:params]];
    }
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:fullSourceFileUrl]];
    [request setHTTPMethod:@"GET"];
    return request;
}

// Create a multipart/form-data POST request to upload the file to the indicated URL
// Special internal parameters as well as other passed-on params can be added.  See OBFileTransferAgent.h/m
-(NSMutableURLRequest *) uploadFileRequest:(NSString *)filePath to:(NSString *)targetUrl withParams:(NSDictionary *)params
{
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:targetUrl]];

    [request setHTTPMethod:@"POST"];
    
    [request setValue:@"Keep-Alive" forHTTPHeaderField:@"Connection"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data;boundary=%@", OBHttpFormBoundary ] forHTTPHeaderField:@"Content-Type"];
    
    
    NSMutableData *body = [[NSMutableData alloc] init];

    if ( filePath != nil ) {
        NSString *formFileInputName = params[FormFileFieldNameParamKey] == nil ? @"file" : params[FormFileFieldNameParamKey];
        NSString *filename = params[FilenameParamKey] == nil ? [[filePath pathComponents] lastObject] : params[FilenameParamKey];
        NSString *contentType =params[ContentTypeParamKey] ? params[ContentTypeParamKey] : [self mimeTypeFromFilename:filePath];

        NSMutableString *preString =  [[NSMutableString alloc] init];
        [preString appendString:[NSString stringWithFormat:@"--%@\r\n", OBHttpFormBoundary]];
        [preString appendString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n",formFileInputName,filename]];
        [preString appendString:[NSString stringWithFormat:@"Content-Type: %@\r\n",contentType]];
        [preString appendString:@"Content-Transfer-Encoding: binary\r\n"];
        [preString appendString:@"\r\n"];


        [body appendData:[preString dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[NSData dataWithContentsOfFile:filePath]];
        [body appendData:[@"\r\n"dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSDictionary * coreParams = [self removeSpecialParams:params];
    if ( coreParams.count > 0 ) {
        NSMutableString *paramsString = [NSMutableString new];
        
        // add params (all params are strings)
        for (NSString *param in [coreParams allKeys]) {
            [paramsString appendString:[NSString stringWithFormat:@"--%@\r\n", OBHttpFormBoundary]];
            [paramsString appendString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param]];
            [paramsString appendString:[NSString stringWithFormat:@"%@\r\n", coreParams[param]]];
        }
        
        [body appendData:[paramsString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSString *postString =  [NSString stringWithFormat:@"--%@--\r\n", OBHttpFormBoundary];
    
    [body appendData:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    return request;
}

-(BOOL) hasMultipartBody
{
    return YES;
}

@end
