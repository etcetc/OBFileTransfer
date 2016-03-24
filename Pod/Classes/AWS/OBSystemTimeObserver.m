//
//  OBSystemTimeObserver.m
//  Pods
//
//  Created by Rinat on 24/03/16.
//
//

#import "OBSystemTimeObserver.h"
#import "AmazonClientManager.h"
#import "OBLogger.h"

@implementation OBSystemTimeObserver

- (void)startObserving
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dateChanged)
                                                 name:NSSystemClockDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dateChanged
{
    OB_EVENT(@"System clock changed. Resetting Amazon clock offset");
    [AmazonClientManager setTimeOffset:0];
}

@end
