//
//  AuthenticationViewController.m
//  May Ball Check-in
//
//  Created by Peter Birch on 11/05/2016.
//  Copyright © 2016 Peter Birch. All rights reserved.
//

#import "AuthenticationViewController.h"
#import "AppDelegate.h"
#import "APIInterface.h"
#import "HostConfigurationViewController.h"

@interface AuthenticationViewController ()

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation AuthenticationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationItem setHidesBackButton:YES];
    if (self.navigationItem.leftBarButtonItem == nil) {
        UIBarButtonItem * config_button = [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(configureHostURL:)];
        [self.navigationItem setLeftBarButtonItem:config_button];
    }
    if (![APIInterface hostURL]) {
        [self configureHostURL:nil];
    } else {
        [self reload];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)configureHostURL:(id)sender {
    HostConfigurationViewController * config = [self.storyboard instantiateViewControllerWithIdentifier:@"host_config"];
    [self.navigationController pushViewController:config animated:YES];
}

- (void)reload {
    NSString * auth_route = [[APIInterface hostURL] stringByAppendingString:@"/api/login"];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:auth_route]]];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {
    NSString * current_path = self.webView.request.URL.absoluteString;
    NSArray * parts = [current_path componentsSeparatedByString:[APIInterface hostURL]];
    if(parts.count > 1 && [[parts objectAtIndex:1] rangeOfString:@"/api/token/issue"].location != NSNotFound) {
        NSString *source = [self.webView stringByEvaluatingJavaScriptFromString: @"document.documentElement.innerText"];
        NSError *err = nil;
        NSDictionary * parsed = [NSJSONSerialization JSONObjectWithData:[source dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&err];
        //NSLog(@"%@", parsed);
        if(err) {
            NSLog(@"JSON parse error: %@", err);
            return;
        }
        NSString * token = [parsed objectForKey:@"token"];
        //NSLog(@"Got token: %@", token);
        [[APIInterface instance] setToken:token];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"Error occurred loading authentication page: %@", error);
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Load Failed"
                                                                    message:@"Could not load login page, please check that the address of your Tktr instance is correct!"
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Try Again"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [self reload];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Settings"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [self configureHostURL:nil];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
