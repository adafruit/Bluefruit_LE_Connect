//
//  UserFilesTableViewCell.h
//  BluefruitUpdater
//
//  Created by Antonio García on 22/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <UIKit/UIKit.h>

@protocol UserFilesTableViewCellDelegate <NSObject>
- (void)onUserFilesClick:(NSInteger)tag;
@end

@interface UserFilesTableViewCell : UITableViewCell

@property id<UserFilesTableViewCellDelegate> delegate;

@end
