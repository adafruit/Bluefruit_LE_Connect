//
//  UserFilesTableViewCell.m
//  BluefruitUpdater
//
//  Created by Antonio García on 22/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "UserFilesTableViewCell.h"

@implementation UserFilesTableViewCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (IBAction)onClickButton:(id)sender {
    if (_delegate)
    {
        [_delegate onUserFilesClick:self.tag];
    }
}

@end
