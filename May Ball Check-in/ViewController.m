//
//  ViewController.m
//  May Ball Check-in
//
//  Created by Peter Birch on 11/05/2016.
//  Copyright © 2016 Peter Birch. All rights reserved.
//

#import "ViewController.h"
#import "AuthenticationViewController.h"
#import "HostConfigurationViewController.h"
#import "TicketInfoViewController.h"
#import "APIInterface.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIView *cameraView;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

- (BOOL)startScanning;
- (BOOL)stopScanning;
- (IBAction)settings:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if(![[APIInterface instance] token]) {
        AuthenticationViewController * auth = [self.storyboard instantiateViewControllerWithIdentifier:@"authentication"];
        [self.navigationController pushViewController:auth animated:YES];
    } else {
        // Initiate validating the token
        [[APIInterface instance] apiValidateAuthenticationTokenOnCompletion:^(NSError *err, NSDictionary *data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(err) {
                    NSLog(@"Error: %@", err);
                    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Error Authenticating"
                                                                                    message:@"Please try again..."
                                                                             preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                        AuthenticationViewController * auth = [self.storyboard instantiateViewControllerWithIdentifier:@"authentication"];
                        [self.navigationController pushViewController:auth animated:YES];
                    }]];
                    [self presentViewController:alert animated:YES completion:nil];
                } else {
                    if(data[@"token_status"] != nil && ![data[@"token_status"] isEqualToString:@"valid"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            AuthenticationViewController * auth = [self.storyboard instantiateViewControllerWithIdentifier:@"authentication"];
                            [self.navigationController pushViewController:auth animated:YES];
                        });
                    }
                }
            });
        }];
        // Start up the scanner
        [self startScanning];
        NSLog(@"Got token handed back: %@", [[APIInterface instance] token]);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopScanning];
}

#pragma mark - Scanning Control Functions

- (BOOL)startScanning {
    // Construct device & input
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError * err = nil;
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
    
    if(!input || err) {
        NSLog(@"Error occurred starting camera: %@", err);
        return false;
    }
    
    // Create the capture session
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:input];
    
    // Create the output
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc] init];
    [self.captureSession addOutput:output];
    
    // Give the session its own dispatch queue
    dispatch_queue_t captureQueue = dispatch_queue_create("uk.co.lightlogic.tktr.capture", NULL);
    [output setMetadataObjectsDelegate:self queue:captureQueue];
    [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode]];
    
    // Create the video output
    self.videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.videoPreviewLayer setFrame:self.cameraView.bounds];
    [self.cameraView.layer addSublayer:self.videoPreviewLayer];
    
    // Start capturing
    [self.captureSession startRunning];
    
    return true;
}

- (BOOL)stopScanning {
    if(self.captureSession == nil) return false;
    if(self.captureSession.isRunning) [self.captureSession stopRunning];
    [self.videoPreviewLayer removeFromSuperlayer];
    self.videoPreviewLayer = nil;
    self.captureSession = nil;
    return true;
}

- (IBAction)settings:(id)sender {
    [[APIInterface instance] clearToken];
    HostConfigurationViewController * config = [self.storyboard instantiateViewControllerWithIdentifier:@"host_config"];
    [self.navigationController pushViewController:config animated:YES];
}

#pragma mark - Delegate Callbacks for AVCapture

// See: http://stackoverflow.com/questions/3056757/how-to-convert-an-nsstring-to-hex-values
+ (NSString *) stringFromHex:(NSString *)str {
    NSMutableData *stringData = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [str length] / 2; i++) {
        byte_chars[0] = [str characterAtIndex:i*2];
        byte_chars[1] = [str characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [stringData appendBytes:&whole_byte length:1];
    }
    
    return [[NSString alloc] initWithData:stringData encoding:NSASCIIStringEncoding];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection {
    
    if(metadataObjects && metadataObjects.count > 0) {
        AVMetadataMachineReadableCodeObject * obj = metadataObjects.firstObject;
        if([obj.type isEqualToString:AVMetadataObjectTypeAztecCode]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Got QR code data: %@", obj.stringValue);
                [self stopScanning];
                
                // Decode the passed text
                NSString * raw_txt = obj.stringValue;
                // Separate the last 4 characters
                NSString * hex_ticket = [raw_txt substringToIndex:(raw_txt.length - 4)];
                NSString * check_hex = [raw_txt substringWithRange:NSMakeRange((raw_txt.length - 4), 4)];
                
                NSLog(@"RAW: %@", raw_txt);
                NSLog(@"Hex Ticket: %@, Check Hex: %@", hex_ticket, check_hex);
                
                NSString * ticket_id = [ViewController stringFromHex:hex_ticket];
                NSData * data = [ticket_id dataUsingEncoding:NSUTF8StringEncoding];
                uint8_t * bytes = (uint8_t *)[data bytes];
                int sum = 0;
                for(int i = 0; i < [data length]; i++) {
                    sum += bytes[i];
                }
                
                NSArray * hex_chars = @[@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"A",@"B",@"C",@"D",@"E",@"F"];
                NSString * mod_16 = hex_chars[(sum % 16)];
                NSString * mod_23 = hex_chars[(sum % 23) % 16];
                NSString * mod_27 = hex_chars[(sum % 27) % 16];
                NSString * mod_31 = hex_chars[(sum % 31) % 16];
                NSString * calc_check_hex = [@[mod_16, mod_23, mod_27, mod_31] componentsJoinedByString:@""];
                
                NSLog(@"Ticket ID: %@, Calc Check: %@: %i", ticket_id, calc_check_hex, sum);
                
                if([[check_hex uppercaseString] isEqualToString:calc_check_hex]) {
                    NSLog(@"Got a check match!");
                    TicketInfoViewController * info = [self.storyboard instantiateViewControllerWithIdentifier:@"ticketinfo"];
                    [info setLookupDetails:ticket_id];
                    [self.navigationController pushViewController:info animated:YES];
                } else {
                    NSLog(@"Got a check mismatch!");
                    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Ticket Is Invalid"
                                                                                    message:@"The ticket scanned is invalid, please try again."
                                                                             preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                    [self startScanning];
                }
            });
        }
    }
    
}

@end
