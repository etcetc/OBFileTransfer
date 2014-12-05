//
//  OBAppDelegate.m
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/20/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import "OBAppDelegate.h"
#import <OBLogger/OBLogger.h>
#import <OBFileTransfer/OBFileTransferManager.h>

@implementation OBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [OBLogger instance].writeToConsole = YES;
    [[OBLogger instance] reset];
    [[OBLogger instance] logEvent:OBLogEventAppStarted];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[OBLogger instance] logEvent:OBLogEventAppBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [[OBLogger instance] logEvent:OBLogEventAppForeground];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[OBLogger instance] logEvent:OBLogEventAppActive];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[OBLogger instance] logEvent:OBLogEventAppTerminate];
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler{
    OB_INFO(@"handleEventsForBackgroundURLSession: for sessionId=%@",identifier);
    OBFileTransferManager *ftm = [OBFileTransferManager instance];
    ftm.backgroundSessionCompletionHandler = completionHandler;
}

@end
