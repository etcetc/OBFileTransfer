//
//  OBTransferView.h
//  FileTransferPlay
//
//  Created by Farhad on 6/24/14.
//  Copyright (c) 2014 NoPlanBees. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, TransferStatus) {
    Transferring,
    Success,
    Error,
    PendingRetry
};

typedef NS_ENUM(NSUInteger, TransferDirection) {
    Upload,
    Download
};


@interface OBTransferView : UIView

@property (nonatomic,weak) IBOutlet UIImageView * direction;
@property (nonatomic,weak) IBOutlet UIImageView * status;
@property (nonatomic,weak) IBOutlet UIProgressView * progressBar;
@property (nonatomic,weak) IBOutlet UILabel * filename;

-(id) initInRow: (NSUInteger) row;

-(void) updateStatus: (TransferStatus) status;
-(void) updateProgress: (NSUInteger) percent;
-(void) startTransfer: (NSString *)title upload: (TransferDirection) direction;

@end
