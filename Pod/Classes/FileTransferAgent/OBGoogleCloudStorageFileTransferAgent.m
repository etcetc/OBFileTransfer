//
//  OBGoogleCloudStorageFileTransferAgent.m
//  Pods
//
//  Created by Farhad Farzaneh on 10/3/14.
//
// Required configuration data
//  ApiKey
//  Project ID
// Required upload data
//   file
//   name
//

#import "OBGoogleCloudStorageFileTransferAgent.h"
#import "GTLJSONParser.h"

NSString *const OBGoogleCloudStorageApiKey = @"GoogleCloudStorageApiKey";
NSString *const OBGoogleCloudStorageProjectId = @"GoogleCloudStorageProjectId";
NSString *const OBGoogleCloudStorageProtocol = @"gs";

@interface OBGoogleCloudStorageFileTransferAgent ()
@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *projectId;
@end

@implementation OBGoogleCloudStorageFileTransferAgent

NSString *const kBaseCloudUrl = @"https://www.googleapis.com";
NSString *const OBGSFTAHttpFormBoundary = @"some_unlikely_string";

- (instancetype)initWithConfig:(NSDictionary *)configParams
{
    if ([self init])
    {
        self.apiKey = configParams[OBGoogleCloudStorageApiKey];
        self.projectId = configParams[OBGoogleCloudStorageProjectId];
    }
    [self validateSetup];
    return self;
}

// We can use either simple upload or multipart method.

#define SIMPLE_UPLOAD 0

// Note that the sourceFileURL must be of form myPrefix://bucket_name/folder_name(s)/filename
- (NSMutableURLRequest *)downloadFileRequest:(NSString *)sourcefileUrl withParams:(NSDictionary *)params
{
    NSString *fullSourceFileUrl = [self createDownloadUrl:sourcefileUrl];
    if (params.count > 0)
    {
        fullSourceFileUrl = [NSString stringWithFormat:@"%@&%@", sourcefileUrl, [self serializeParams:params]];
    }
    OB_INFO(@"Setting up Google Cloud Storage download from %@", fullSourceFileUrl);

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:fullSourceFileUrl]];
    [request setHTTPMethod:@"GET"];
    return request;
}

// Note that the sourceFileURL will be of form myPrefix://bucket_name/folder_name(s)
// Note that per Google spec, the parameters have to come before the file body and the type is multipart/relative
- (NSMutableURLRequest *)uploadFileRequest:(NSString *)filePath
                                        to:(NSString *)targetUrl
                                withParams:(NSDictionary *)params
{
    NSString *fullTargetUrl = [self createUploadUrl:targetUrl];
    NSString *filename = params[FilenameParamKey];
    if (filename == nil || filename.length == 0)
    {
        filename = [self filenameFromFilepath:filePath];
    }

    NSString *queryString = [NSString stringWithFormat:@"&name=%@", filename];
    fullTargetUrl = [fullTargetUrl stringByAppendingString:queryString];
    OB_INFO(@"Setting up Google Cloud Storage upload to %@", fullTargetUrl);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:fullTargetUrl]];

    [request setHTTPMethod:@"POST"];

    [request setValue:@"Keep-Alive" forHTTPHeaderField:@"Connection"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    [request setValue:@"926360415491" forHTTPHeaderField:@"x-goog-project-id"];

    NSMutableData *body = [[NSMutableData alloc] init];

#if SIMPLE_UPLOAD

    NSString *contentType =params[ContentTypeParamKey] ? params[ContentTypeParamKey] : [self mimeTypeFromFilename:filePath];
    [request setValue: contentType forHTTPHeaderField:@"Content-Type"];

    [body appendData:[NSData dataWithContentsOfFile:filePath]];

#else
    [request setValue:[NSString stringWithFormat:@"multipart/related;boundary=%@", OBGSFTAHttpFormBoundary]
   forHTTPHeaderField:@"Content-Type"];

    NSMutableDictionary *coreParams = [NSMutableDictionary dictionaryWithDictionary:[self removeSpecialParams:params]];

    coreParams[@"name"] = params[FilenameParamKey];

    NSError *error;
    NSString *coreParamsJson = [GTLJSONParser stringWithObject:coreParams
                                                 humanReadable:YES
                                                         error:&error];
    if (error)
    {
        OB_ERROR(@"OBGoogleCloudStorageFileTransferAgent Unable to convert params to JSON");
    }

    NSMutableString *paramsString = [NSMutableString new];
    [paramsString appendString:[NSString stringWithFormat:@"--%@\r\n", OBGSFTAHttpFormBoundary]];
    [paramsString appendString:[NSString stringWithFormat:@"Content-Type: application/json;\r\n"]];
    [paramsString appendString:@"\r\n"];
    [paramsString appendString:coreParamsJson];
    [paramsString appendString:@"\r\n"];

    [body appendData:[paramsString dataUsingEncoding:NSUTF8StringEncoding]];

    if (filePath != nil)
    {
//        NSString *formFileInputName = params[FormFileFieldNameParamKey] == nil ? @"file" : params[FormFileFieldNameParamKey];
//        NSString *filename = params[FilenameParamKey] == nil ? [[filePath pathComponents] lastObject] : params[FilenameParamKey];
        NSString *contentType = params[ContentTypeParamKey] ? params[ContentTypeParamKey] : [self mimeTypeFromFilename:filePath];

        NSMutableString *preString = [[NSMutableString alloc] init];
        [preString appendString:[NSString stringWithFormat:@"\r\n--%@\r\n", OBGSFTAHttpFormBoundary]];
        [preString appendString:[NSString stringWithFormat:@"Content-Type: %@\r\n", contentType]];
        [preString appendString:@"\r\n"];


        [body appendData:[preString dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[NSData dataWithContentsOfFile:filePath]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }

    NSString *postString = [NSString stringWithFormat:@"--%@--\r\n", OBGSFTAHttpFormBoundary];
    [body appendData:[postString dataUsingEncoding:NSUTF8StringEncoding]];
#endif

//    Now add the content length to the header
//    [request setValue:[NSString stringWithFormat:@"%lu",(unsigned long)body.length] forKey:@"Content-Length"];

    [request setHTTPBody:body];

    return request;
}

- (BOOL)hasMultipartBody
{
#if SIMPLE_UPLOAD
    return NO;
#else
    return YES;
#endif
}

// Returns an NSDictionary with the following keys:
// bucketName: the name of the bucket
// filePath: the file path in the bucket
// Input: of form protocol://bucket-name/file-path or just bucket-name/file-path
- (NSDictionary *)urlToComponents:(NSString *)url
{
    NSString *path;
    if ([url rangeOfString:[OBGoogleCloudStorageProtocol stringByAppendingString:@"://"]].location == 0)
    {
        path = [url substringFromIndex:OBGoogleCloudStorageProtocol.length + 3];
    }
    else
    {
        path = url;
    }
    //    This'll throw up if there are no /s in the input
    NSInteger firstSlash = [path rangeOfString:@"/"].location;
    return @{@"bucketName" : [path substringToIndex:firstSlash], @"filePath" : [path substringFromIndex:firstSlash + 1]};
}

- (NSString *)createUploadUrl:(NSString *)url
{
    NSDictionary *urlComponents = [self urlToComponents:url];
    NSString *uploadType = @"";
#if SIMPLE_UPLOAD
    uploadType = @"uploadType=media&";
#else
    uploadType = @"uploadType=multipart&";
#endif
    return [NSString stringWithFormat:@"%@/upload/storage/v1/b/%@/o?%@key=%@",
                                      kBaseCloudUrl,
                                      urlComponents[@"bucketName"],
                                      uploadType,
                                      self.apiKey];
}

- (NSString *)createDownloadUrl:(NSString *)url
{
    NSDictionary *urlComponents = [self urlToComponents:url];
    return [NSString stringWithFormat:@"%@/download/storage/v1/b/%@/o/%@?key=%@&alt=media",
                                      kBaseCloudUrl,
                                      urlComponents[@"bucketName"],
                                      urlComponents[@"filePath"],
                                      self.apiKey];
}

- (void)validateSetup
{
    NSAssert(self.apiKey != nil, @"API Key not specified for Google Cloud Storage");
}

@end
