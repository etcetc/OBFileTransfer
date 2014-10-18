//
//  OBViewController.h
//  FileTransferPlay
//
//  Created by Farhad Farzaneh on 6/20/14.
//  Copyright (c) 2014 OneBeat. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OBFileTransfer/OBFileTransferManager.h>

@interface OBViewController : UIViewController <OBFileTransferDelegate>

@property (nonatomic,weak) IBOutlet UIImageView * image;
@property (nonatomic,weak) IBOutlet UIView * transferViewArea;
@property (weak, nonatomic) IBOutlet UITextField *baseUrlInput;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UILabel *pendingInfo;
@property (weak, nonatomic) IBOutlet UISegmentedControl *fileStoreControl;

- (IBAction)changedFileStore:(id)sender;
- (IBAction)changedFileStoreUrl:(id)sender;
- (IBAction)retryPending:(id)sender;
- (IBAction)reset:(id)sender;
- (IBAction)showLog:(id)sender;


@end
