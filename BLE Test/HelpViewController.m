//
//  HelpViewController.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/10/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "HelpViewController.h"

@interface HelpViewController ()

@end

@implementation HelpViewController


- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil{
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.preferredContentSize = CGSizeMake(320.0, 480.0);   //popover size on iPad
    }
    return self;
}


- (void)viewDidLoad{
    
    [super viewDidLoad];
    
    if (IS_IPAD)
        self.preferredContentSize = self.view.frame.size;   //popover size on iPad
    
    else if (IS_IPHONE) {
        self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    }
	
    //Set the app version # in the Help/Info view
    if (self.versionLabel != nil) {
        NSString* versionString = [NSString stringWithFormat:
                                   @"%@", [[[NSBundle mainBundle] infoDictionary]
                                           objectForKey:@"CFBundleVersion"]];
        _versionLabel.text = [NSString stringWithFormat:@"v%@", versionString];
    }
    
}


- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (IS_IPHONE) {
        [self.textView flashScrollIndicators];  //indicate add'l content below screen
    }
    
}


- (void)didReceiveMemoryWarning{
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Actions


- (IBAction)done:(id)sender{
    
    //done button tapped
    
    [self.delegate helpViewControllerDidFinish:self];
    
}


- (void)viewDidUnload{
    
    [self setVersionLabel:nil];
    
    [super viewDidUnload];

}


@end
