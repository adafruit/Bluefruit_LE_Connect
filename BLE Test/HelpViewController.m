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
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 480.0);
    }
    return self;
}


- (void)viewDidLoad{
    
    [super viewDidLoad];
    
    if (IS_IPAD)
        self.contentSizeForViewInPopover = self.view.frame.size;
    
    else if (IS_IPHONE) {
        self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    }
	
    //Set the app version # in the About view
    if (self.versionLabel != nil) {
        NSString* versionString = [NSString stringWithFormat:
                                   @"%@", [[[NSBundle mainBundle] infoDictionary]
                                           objectForKey:@"CFBundleVersion"]];
        _versionLabel.text = [NSString stringWithFormat:@"Bluefruit Connect v%@", versionString];
    }
    
}


- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (IS_IPHONE) {
        [self.textView flashScrollIndicators];
    }
    
}


- (void)didReceiveMemoryWarning{
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Actions


- (IBAction)done:(id)sender{
    
    [self.delegate helpViewControllerDidFinish:self];
}


- (void)viewDidUnload {
    [self setVersionLabel:nil];
    [super viewDidUnload];
}

@end
