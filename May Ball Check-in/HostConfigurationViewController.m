//
//  HostConfigurationViewController.m
//  TktrApp
//
//  Created by Peter Birch on 12/01/2017.
//  Copyright © 2017 Peter Birch. All rights reserved.
//

#import "HostConfigurationViewController.h"
#import "APIInterface.h"

@interface HostConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UITextField *host_url;
- (IBAction)done:(id)sender;

@end

@implementation HostConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationItem setHidesBackButton:YES];
    if([APIInterface hostURL] != nil) [self.host_url setText:[APIInterface hostURL]];
    [self.host_url becomeFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)done:(id)sender {
    if (
        ![self.host_url.text.lowercaseString containsString:@"http://"] &&
        ![self.host_url.text.lowercaseString containsString:@"https://"]
    ) {
        UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Invalid URL"
                                                                        message:@"Your URL must contain 'http://' or 'https://'."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [APIInterface setHostURL:self.host_url.text];
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self done:textField];
    return NO;
}

@end
