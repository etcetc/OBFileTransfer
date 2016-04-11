/*
 * Copyright 2010-2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "AmazonKeyChainWrapper.h"
#import "KeychainItemWrapper.h"

NSString *kKeychainAccessKeyIdentifier;
NSString *kKeychainSecretKeyIdentifier;
NSString *kKeychainSecrutiyTokenIdentifier;
NSString *kKeychainExpirationDateIdentifier;

NSString *kKeychainUidIdentifier;
NSString *kKeychainKeyIdentifier;


@implementation AmazonKeyChainWrapper

+(void)initialize
{
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    
    kKeychainAccessKeyIdentifier = [NSString stringWithFormat:@"%@.AWSAccessKey", bundleID];
    kKeychainSecretKeyIdentifier= [NSString stringWithFormat:@"%@.AWSSecretKey", bundleID];
    kKeychainSecrutiyTokenIdentifier  = [NSString stringWithFormat:@"%@.AWSSecurityToken", bundleID];
    kKeychainExpirationDateIdentifier = [NSString stringWithFormat:@"%@.AWSExpirationDate", bundleID];
    
    kKeychainUidIdentifier = [NSString stringWithFormat:@"%@.UID", bundleID] ;
    kKeychainKeyIdentifier = [NSString stringWithFormat:@"%@.KEY", bundleID] ;
}

+(NSString *)keychainAccessKeyIdentifier{
    return kKeychainAccessKeyIdentifier;
}
+(NSString *)keychainSecretKeyIdentifier{
    return kKeychainSecretKeyIdentifier;
}
+(NSString *)keychainSecrutiyTokenIdentifier{
    return kKeychainSecrutiyTokenIdentifier;
}


+(bool)areCredentialsExpired
{
//    AMZLogDebug(@"areCredentialsExpired");

    NSString *expiration = [AmazonKeyChainWrapper getValueFromKeyChain:kKeychainExpirationDateIdentifier];
    if (expiration == nil || expiration.length == 0) {
    AMZLog(@"Credentials are expired");
        return YES;
    }
    else {
        NSDate *expirationDate = [AmazonKeyChainWrapper convertStringToDate:expiration];

        AMZLogDebug(@"expirationDate : %@, %@", expiration, expirationDate);

        return [AmazonKeyChainWrapper isExpired:expirationDate];
    }
}

+(void)registerDeviceId:(NSString *)uid andKey:(NSString *)key
{
    [AmazonKeyChainWrapper storeValueInKeyChain:uid forKey:kKeychainUidIdentifier];
    [AmazonKeyChainWrapper storeValueInKeyChain:key forKey:kKeychainKeyIdentifier];
}

+(NSString *)getKeyForDevice
{
    return [AmazonKeyChainWrapper getValueFromKeyChain:kKeychainKeyIdentifier];
}

+(NSString *)getUidForDevice
{
    return [AmazonKeyChainWrapper getValueFromKeyChain:kKeychainUidIdentifier];
}

+(NSString *)securityToken
{
    return[AmazonKeyChainWrapper getValueFromKeyChain:kKeychainSecrutiyTokenIdentifier];
}

+(AmazonCredentials *)getCredentialsFromKeyChain
{
    NSString *accessKey     = [AmazonKeyChainWrapper getValueFromKeyChain:kKeychainAccessKeyIdentifier];
    NSString *secretKey     = [AmazonKeyChainWrapper getValueFromKeyChain:kKeychainSecretKeyIdentifier];
    NSString *securityToken = [AmazonKeyChainWrapper getValueFromKeyChain:kKeychainSecrutiyTokenIdentifier];

    if ((accessKey != nil) && (secretKey != nil) && (securityToken != nil)) {
        if (![AmazonKeyChainWrapper areCredentialsExpired]) {
            AmazonCredentials *credentials = [[AmazonCredentials alloc] initWithAccessKey:accessKey withSecretKey:secretKey];
            credentials.securityToken = securityToken;

            return credentials;
        }
    }

    return nil;
}

+(void)storeCredentialsInKeyChain:(NSString *)theAccessKey secretKey:(NSString *)theSecretKey securityToken:(NSString *)theSecurityToken expiration:(NSString *)theExpirationDate
{
    [AmazonKeyChainWrapper storeValueInKeyChain:theAccessKey forKey:kKeychainAccessKeyIdentifier];
    [AmazonKeyChainWrapper storeValueInKeyChain:theSecretKey forKey:kKeychainSecretKeyIdentifier];
    [AmazonKeyChainWrapper storeValueInKeyChain:theSecurityToken forKey:kKeychainSecrutiyTokenIdentifier];
    [AmazonKeyChainWrapper storeValueInKeyChain:theExpirationDate forKey:kKeychainExpirationDateIdentifier];
}

+(bool)isExpired:(NSDate *)date
{
    NSDate *soon = [NSDate dateWithTimeIntervalSinceNow:(15 * 60)];  // Fifteen minutes from now.

    if ( [soon compare:date] == NSOrderedDescending) {
        return YES;
    }
    else {
        return NO;
    }
}

+(NSDate *)convertStringToDate:(NSString *)expiration
{
    if (expiration != nil)
    {
        long long exactSecondOfExpiration = (long long)([expiration longLongValue] / 1000);
        return [[NSDate alloc] initWithTimeIntervalSince1970:exactSecondOfExpiration];
    }
    else
    {
        return nil;
    }
}

+(void)storeValueInKeyChain:(NSString *)value forKey:(NSString *)key
{
    KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:key accessGroup:nil];
    [keychain setObject:value forKey:(__bridge id)kSecValueData];
    AMZLogDebug(@"Stored value:[%@] in KeyChain as key:[%@]", value, key);
}


+(NSString *) getValueFromKeyChain:(NSString *)key
{
    KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:key accessGroup:nil];
    NSString *value = [keychain objectForKey:(__bridge id)kSecValueData];
    AMZLogDebug(@"Got value:[%@] in KeyChain for key:[%@]", value, key);
    return value;
}


//TODO - error management
+(OSStatus)wipeCredentialsFromKeyChain
{
    [[[KeychainItemWrapper alloc]initWithIdentifier:kKeychainAccessKeyIdentifier accessGroup:nil] removeFromKeychain];
    [[[KeychainItemWrapper alloc]initWithIdentifier:kKeychainSecretKeyIdentifier accessGroup:nil] removeFromKeychain];
    [[[KeychainItemWrapper alloc]initWithIdentifier:kKeychainSecrutiyTokenIdentifier accessGroup:nil] removeFromKeychain];
    [[[KeychainItemWrapper alloc]initWithIdentifier:kKeychainExpirationDateIdentifier accessGroup:nil] removeFromKeychain];
    return noErr;
}

// TODO - erro rmanagement
+(OSStatus)wipeKeyChain
{
    [self wipeCredentialsFromKeyChain];
    [[[KeychainItemWrapper alloc]initWithIdentifier:kKeychainUidIdentifier accessGroup:nil] removeFromKeychain];
    [[[KeychainItemWrapper alloc]initWithIdentifier:kKeychainKeyIdentifier accessGroup:nil] removeFromKeychain];
    return noErr;
}

/******************
 * OBSOLETE 
 ******************/


+(NSString *)getValueFromKeyChainOld:(NSString *)key
{
    
    NSMutableDictionary *queryDictionary = [[NSMutableDictionary alloc] init];
    
    [queryDictionary setObject:[key dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecAttrGeneric];
    [queryDictionary setObject:(id) kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    [queryDictionary setObject:(__bridge id) kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [queryDictionary setObject:(id) kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [queryDictionary setObject:(__bridge id) kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    NSDictionary *returnedDictionary = [[NSMutableDictionary alloc] init];
    CFTypeRef dict = (__bridge CFTypeRef )returnedDictionary;
    OSStatus     keychainError       = SecItemCopyMatching((__bridge CFDictionaryRef)queryDictionary, &dict);
    if (keychainError == errSecSuccess)
    {
        NSData *rawData = [returnedDictionary objectForKey:(__bridge id)kSecValueData];
        NSString *value = [[NSString alloc] initWithBytes:[rawData bytes] length:[rawData length] encoding:NSUTF8StringEncoding];
        if ( rawData.length != 0 ) {
            AMZLogDebug(@"Got Value [%@] for KeyChain key:[%@]", value, key);
            return value;
        } else {
            AMZLogDebug(@"Read nil data for key:[%@]", key);
            return nil;
        }
    }
    else
    {
        AMZLogDebug(@"Unable to fetch value for keychain key '%@', Error Code: %ld", key, (long)keychainError);
        return nil;
    }
}

+(void)storeValueInKeyChainOld:(NSString *)value forKey:(NSString *)key
{
    
    NSMutableDictionary *keychainDictionary = [[NSMutableDictionary alloc] init];
    [keychainDictionary setObject:[key dataUsingEncoding:NSUTF8StringEncoding]      forKey:(__bridge id)kSecAttrGeneric];
    [keychainDictionary setObject:(__bridge id) kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [keychainDictionary setObject:[value dataUsingEncoding:NSUTF8StringEncoding]    forKey:(__bridge id)kSecValueData];
    [keychainDictionary setObject:[key dataUsingEncoding:NSUTF8StringEncoding]      forKey:(__bridge id)kSecAttrAccount];
    [keychainDictionary setObject:(__bridge id) kSecAttrAccessibleWhenUnlockedThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
    
    OSStatus keychainError = SecItemAdd((__bridge CFDictionaryRef)keychainDictionary, NULL);
    if (keychainError == errSecDuplicateItem) {
        SecItemDelete((__bridge CFDictionaryRef)keychainDictionary);
        keychainError = SecItemAdd((__bridge CFDictionaryRef)keychainDictionary, NULL);
    }
    
    if (keychainError != errSecSuccess) {
        AMZLogDebug(@"Error saving value to keychain key '%@', Error Code: %ld", key, (long)keychainError);
    } else {
        AMZLogDebug(@"Stored value:[%@] in KeyChain as key:[%@]", value, key);
    }
}

+(OSStatus)wipeKeyChainOld
{
    OSStatus keychainError = [AmazonKeyChainWrapper wipeCredentialsFromKeyChain];
    
    if(keychainError != errSecSuccess)
    {
        return keychainError;
    }
    
    keychainError = SecItemDelete((__bridge CFDictionaryRef)[AmazonKeyChainWrapper createKeychainDictionaryForKey:kKeychainUidIdentifier]);
    
    if(keychainError != errSecSuccess && keychainError != errSecItemNotFound)
    {
        AMZLogDebug(@"Keychain Key: kKeychainUidIdentifier, Error Code: %ld", (long)keychainError);
        return keychainError;
    }
    
    keychainError = SecItemDelete((__bridge CFDictionaryRef)[AmazonKeyChainWrapper createKeychainDictionaryForKey : kKeychainKeyIdentifier]);
    if(keychainError != errSecSuccess && keychainError != errSecItemNotFound)
    {
        AMZLogDebug(@"Keychain Key: kKeychainKeyIdentifier, Error Code: %ld", (long)keychainError);
        return keychainError;
    }
    
    return errSecSuccess;
}

+(OSStatus)wipeCredentialsFromKeyChainOld
{
    OSStatus keychainError = SecItemDelete((__bridge CFDictionaryRef)[AmazonKeyChainWrapper createKeychainDictionaryForKey : kKeychainAccessKeyIdentifier]);
    
    if(keychainError != errSecSuccess && keychainError != errSecItemNotFound)
    {
        AMZLogDebug(@"Keychain Key: kKeychainAccessKeyIdentifier, Error Code: %ld", (long)keychainError);
        return keychainError;
    }
    
    keychainError = SecItemDelete((__bridge CFDictionaryRef)[AmazonKeyChainWrapper createKeychainDictionaryForKey : kKeychainSecretKeyIdentifier]);
    
    if(keychainError != errSecSuccess && keychainError != errSecItemNotFound)
    {
        AMZLogDebug(@"Keychain Key: kKeychainSecretKeyIdentifier, Error Code: %ld", (long)keychainError);
        return keychainError;
    }
    
    keychainError = SecItemDelete((__bridge CFDictionaryRef)[AmazonKeyChainWrapper createKeychainDictionaryForKey : kKeychainSecrutiyTokenIdentifier]);
    
    if(keychainError != errSecSuccess && keychainError != errSecItemNotFound)
    {
        AMZLogDebug(@"Keychain Key: kKeychainSecrutiyTokenIdentifier, Error Code: %ld", (long)keychainError);
        return keychainError;
    }
    
    keychainError = SecItemDelete((__bridge CFDictionaryRef)[AmazonKeyChainWrapper createKeychainDictionaryForKey : kKeychainExpirationDateIdentifier]);
    
    if(keychainError != errSecSuccess && keychainError != errSecItemNotFound) 
    {
        AMZLogDebug(@"Keychain Key: kKeychainExpirationDateIdentifier, Error Code: %ld", (long)keychainError);
        return keychainError;
    }
    
    return errSecSuccess;
}

+(NSMutableDictionary *)createKeychainDictionaryForKey:(NSString *)key
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    [dictionary setObject:[key dataUsingEncoding:NSUTF8StringEncoding]      forKey:(__bridge id)kSecAttrGeneric];
    [dictionary setObject:(__bridge id) kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [dictionary setObject:[key dataUsingEncoding:NSUTF8StringEncoding]      forKey:(__bridge id)kSecAttrAccount];
    [dictionary setObject:(__bridge id) kSecAttrAccessibleWhenUnlockedThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];

    return dictionary;
}

@end
