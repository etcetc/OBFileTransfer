//
//  OBTransferView.m
//  FileTransferPlay
//
//  Created by Farhad on 6/24/14.
//  Copyright (c) 2014 NoPlanBees. All rights reserved.
//

#import "OBTransferView.h"

@implementation OBTransferView

-(id) initInRow: (NSUInteger) row
{
    NSArray *nibs = [[NSBundle mainBundle] loadNibNamed:@"OBTransferView" owner:self options:nil];
    if ( self = [super init] ) {
        self = nibs[0];
        self.frame = CGRectMake(0, self.bounds.size.height * row, self.bounds.size.width, self.bounds.size.height);
    }
    return self;
}

-(void) updateStatus: (TransferStatus) status
{
    switch (status) {
        case Transferring:
            self.status.image = nil;
            break;
            
        case Success:
            [self updateProgress:100];
            self.status.image = [UIImage imageNamed:@"ok.png"];
            break;
            
        case Error:
            self.status.image = [UIImage imageNamed:@"nok.png"];
            break;
            
        case PendingRetry:
            self.status.image = [UIImage imageNamed:@"retry.png"];
            break;
            
        default:
            self.status.image = nil;
    }
        
}

-(void) updateProgress: (NSUInteger) percent
{
    self.progressBar.progress = percent/100.0;
}

-(void) startTransfer: (NSString *)title upload: (TransferDirection) direction
{
    self.filename.text = title;
    self.progressBar.progress = 0.0f;
    self.direction.image = [UIImage imageNamed:direction == Upload ? @"upload" : @"download"];
}

@end
