//
//  TicketInfoViewController.m
//  May Ball Check-in
//
//  Created by Peter Birch on 11/05/2016.
//  Copyright © 2016 Peter Birch. All rights reserved.
//

#import "TicketInfoViewController.h"
#import "APIInterface.h"

@interface TicketInfoViewController ()

@property (strong, nonatomic) NSString * lookup_code;
@property (strong, nonatomic) NSDictionary * fetched_data;

@property (weak, nonatomic) IBOutlet UIView *loading_overlay;
@property (weak, nonatomic) IBOutlet UILabel *loading_text;
@property (weak, nonatomic) IBOutlet UIButton *loading_cancel_button;
@property (weak, nonatomic) IBOutlet UILabel *ticket_id;
@property (weak, nonatomic) IBOutlet UILabel *fullname;
@property (weak, nonatomic) IBOutlet UILabel *dob;
@property (weak, nonatomic) IBOutlet UILabel *ticket_type;
@property (weak, nonatomic) IBOutlet UILabel *ticket_paid;
@property (weak, nonatomic) IBOutlet UITextView *notes;
@property (weak, nonatomic) IBOutlet UIButton *checkin_button;

@property (strong, nonatomic) UIAlertView * confirm_alert;
@property (strong, nonatomic) UIAlertView * error_alert;

- (IBAction)runCheckIn:(id)sender;
- (IBAction)cancelLookup:(id)sender;
- (IBAction)reloadDetails:(id)sender;

@end

@implementation TicketInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.ticket_id setText:@""];
    [self.fullname setText:@""];
    [self.dob setText:@""];
    [self.ticket_type setText:@""];
    [self.ticket_paid setText:@""];
    [self.notes setText:@""];
    [self.loading_overlay setHidden:NO];
    [self.loading_text setText:@"Requesting Details"];
    [self.loading_cancel_button setHidden:NO];
    [self.loading_cancel_button setEnabled:YES];
    [self.notes setTextContainerInset:UIEdgeInsetsZero];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self enactDetailLookup];
}

- (void)enactDetailLookup {
    if(self.lookup_code) {
        [self.loading_overlay setHidden:NO];
        [[APIInterface instance] apiQueryByTicketID:self.lookup_code
                                       onCompletion:
         ^(NSError *err, NSDictionary *data) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if(err) {
                     UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Error Looking Up Ticket"
                                                                                     message:@"Please try again..."
                                                                              preferredStyle:UIAlertControllerStyleAlert];
                     [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                         [self.navigationController popViewControllerAnimated:YES];
                     }]];
                     [self presentViewController:alert animated:YES completion:nil];
                 } else if([data[@"result"] isEqualToString:@"error"]) {
                     if([data[@"error"] isEqualToString:@"Insufficient privilege level"]) {
                         UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Insufficient Privileges"
                                                                                         message:@"You are not permitted to lookup tickets"
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                         [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                             [self.navigationController popViewControllerAnimated:YES];
                         }]];
                         [self presentViewController:alert animated:YES completion:nil];
                     } else if([data[@"error"] isEqualToString:@"Check-in is not active"]) {
                         UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Check-In Disabled"
                                                                                         message:@"Check in has not been enabled on the server, please ask an administrator to enable it."
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                         [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                             [self.navigationController popViewControllerAnimated:YES];
                         }]];
                         [self presentViewController:alert animated:YES completion:nil];
                     } else {
                         UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"An Unknown Error Occurred"
                                                                                         message:@"Please try again..."
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                         [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                             [self.navigationController popViewControllerAnimated:YES];
                         }]];
                         [self presentViewController:alert animated:YES completion:nil];
                     }
                 } else {
                     NSLog(@"%@", data);
                     self.fetched_data = data;
                     NSArray * tickets = [data objectForKey:@"tickets"];
                     [self.loading_overlay setHidden:YES];
                     
                     if(tickets.count == 1) {
                         NSDictionary * ticket = [tickets objectAtIndex:0];
                         NSDictionary * guest = [ticket objectForKey:@"guest_details"];
                         [self.ticket_id setText:ticket[@"ticket_id"]];
                         [self.fullname setText:[NSString stringWithFormat:@"%@ %@ %@", guest[@"title"], guest[@"forename"], guest[@"surname"]]];
                         
                         // Setup parsing date formatter
                         NSString * format_str = @"yyyy-MM-dd";
                         NSDateFormatter * utc_format = [[NSDateFormatter alloc] init];
                         [utc_format setDateFormat:format_str];
                         [utc_format setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_GB"]];
                         // Setup output date formatter
                         NSString * dob_format_str = @"dd/MM/yyyy";
                         NSDateFormatter * dob_format = [[NSDateFormatter alloc] init];
                         [dob_format setDateFormat:dob_format_str];
                         [dob_format setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_GB"]];
                         
                         // Parse the date
                         NSArray * parts = (guest[@"dob"] != nil) ? [guest[@"dob"] componentsSeparatedByString:@"T"] : nil;
                         NSString * part_one = (parts != nil && parts.count >= 2) ? parts[0] : @"";
                         NSDate * dob_date = [utc_format dateFromString:part_one];
                         
                         [self.dob setText:[dob_format stringFromDate:dob_date]];
                         NSArray * addons = ticket[@"addons"];
                         if(addons != nil && [addons count] > 0) {
                             [self.ticket_type setText:[addons componentsJoinedByString:@", "]];
                         } else {
                             [self.ticket_type setText:[NSString stringWithFormat:@"Standard"]];
                         }
                         
                         [self.ticket_paid setText:([data[@"paid"] integerValue] == 1) ? @"Yes" : @"No"];
                         
                         // Concatenate the notes fields
                         NSString * payment_notes = data[@"notes"];
                         NSString * owner_notes = data[@"owner"][@"notes"];
                         NSString * ticket_notes = ticket[@"notes"];
                         NSString * style = @"<style>body,html,h3,p { font-family:Arial; padding:0; margin:0; }</style>";
                         NSArray * all_notes = @[style, @"<h3>Payment Notes</h3>", payment_notes, @"<br /><h3>Owner Notes</h3>", owner_notes, @"<br /><h3>Ticket Notes</h3>", ticket_notes];
                         
                         NSError * err = nil;
                         NSAttributedString * attr_notes = [[NSAttributedString alloc] initWithData:[[all_notes componentsJoinedByString:@""] dataUsingEncoding:NSUnicodeStringEncoding]
                                                                                            options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType }
                                                                                 documentAttributes:nil
                                                                                              error:&err];
                         if(err) {
                             NSLog(@"Error rendering notes: %@", err);
                         }
                         [self.notes setAttributedText:attr_notes];
                         
                         // Check if already checked in
                         if(ticket[@"checked_in"] != nil && [ticket[@"checked_in"] integerValue] == 1) {
                             [self.checkin_button setTitle:@"Already Checked In!" forState:UIControlStateNormal];
                             [self.checkin_button setBackgroundColor:[UIColor redColor]];
                         } else {
                             [self.checkin_button setTitle:@"Check Guest In" forState:UIControlStateNormal];
                             [self.checkin_button setBackgroundColor:[UIColor colorWithRed:0 green:(128.0f / 255.0f) blue:1.0f alpha:1.0f]];
                         }
                     }
                 }
             });
         }];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)runCheckIn:(id)sender {
    // Get ticket
    NSArray * tickets = [self.fetched_data objectForKey:@"tickets"];
    [self.loading_overlay setHidden:YES];
    
    if(tickets.count == 1) {
        NSDictionary * ticket = [tickets objectAtIndex:0];
        NSDictionary * guest = [ticket objectForKey:@"guest_details"];
        // Check if already checked in
        if(ticket[@"checked_in"] != nil && [ticket[@"checked_in"] integerValue] == 1) {
            NSDictionary * checkin_data = ticket[@"checkin_details"];
            NSString * date_str = (checkin_data != nil) ? checkin_data[@"date"] : @"";
            NSString * user_str = (checkin_data != nil) ? checkin_data[@"enacted_by"] : @"";
            NSString * checkin_str = [NSString stringWithFormat:@"Check-in occurred at %@, enacted by %@. Please seek assistance from a committee member.", date_str, user_str];
            
            if([UIAlertController class]) {
                UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Guest Already Checked In"
                                                                                message:checkin_str
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Guest Already Checked In"
                                                                 message:checkin_str
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                [alert show];
            }
        } else {
            if([UIAlertController class]) {
                UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Confirmation"
                                                                                message:[NSString stringWithFormat:@"Are you sure you wish to proceed with check in for %@ %@ %@", guest[@"title"], guest[@"forename"], guest[@"surname"]]
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"No, Cancel" style:UIAlertActionStyleDestructive handler:nil]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Yes, Check-In" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self.loading_overlay setHidden:NO];
                    [self.loading_text setText:@"Checking Guest In"];
                    [self.loading_cancel_button setHidden:YES];
                    [self.loading_cancel_button setEnabled:NO];
                    
                    // Actuate check-in
                    [[APIInterface instance] apiEnactCheckIn:@[ticket[@"ticket_id"]]
                                                onCompletion:
                     ^(NSError *err, NSDictionary *data) {
                         dispatch_async(dispatch_get_main_queue(), ^{
                             NSLog(@"%@ %@", err, data);
                             if([data[@"result"] isEqualToString:@"success"]) {
                                 UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Check-In Was Successful"
                                                                                                 message:@"Guest has been successfully checked in"
                                                                                          preferredStyle:UIAlertControllerStyleAlert];
                                 [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                     [self.navigationController popViewControllerAnimated:YES];
                                 }]];
                                 [self presentViewController:alert animated:YES completion:nil];
                             } else if ([data[@"result"] isEqualToString:@"error"] && [data[@"error"] isEqualToString:@"Some tickets are already checked-in"]) {
                                 UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Guest Already Checked In"
                                                                                                 message:@"It appears that this guest has already been checked in"
                                                                                          preferredStyle:UIAlertControllerStyleAlert];
                                 [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:nil]];
                                 [self presentViewController:alert animated:YES completion:nil];
                                 [self enactDetailLookup];
                             } else {
                                 UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Error Occurred During Check-in"
                                                                                                 message:((err != nil) ? [err localizedDescription] : @"Unknown Error")
                                                                                          preferredStyle:UIAlertControllerStyleAlert];
                                 [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:nil]];
                                 [self presentViewController:alert animated:YES completion:nil];
                                 [self enactDetailLookup];
                             }
                         });
                     }];
                }]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                self.confirm_alert = [[UIAlertView alloc] initWithTitle:@"Confirmation"
                                                                message:[NSString stringWithFormat:@"Are you sure you wish to proceed with check in for %@ %@ %@", guest[@"title"], guest[@"forename"], guest[@"surname"]]
                                                               delegate:self
                                                      cancelButtonTitle:@"No, Cancel"
                                                      otherButtonTitles:@"Yes, Check-In", nil];
                [self.confirm_alert show];
            }
        }
    } else {
        if([UIAlertController class]) {
            UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Unable to Check-In Guest"
                                                                            message:@"Please try again..."
                                                                     preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self.navigationController popViewControllerAnimated:YES];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Unable to Check-In Guest"
                                                             message:@"Please try again..."
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (IBAction)cancelLookup:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)reloadDetails:(id)sender {
    [self enactDetailLookup];
}

- (void)setLookupDetails:(NSString *)query {
    self.lookup_code = query;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if(alertView == self.confirm_alert && buttonIndex == 1) {
        NSArray * tickets = [self.fetched_data objectForKey:@"tickets"];
        [self.loading_overlay setHidden:YES];
        self.confirm_alert = nil;
        
        if(tickets.count == 1) {
            NSDictionary * ticket = [tickets objectAtIndex:0];
            [self.loading_overlay setHidden:NO];
            [self.loading_text setText:@"Checking Guest In"];
            [self.loading_cancel_button setHidden:YES];
            [self.loading_cancel_button setEnabled:NO];
            
            // Actuate check-in
            [[APIInterface instance] apiEnactCheckIn:@[ticket[@"ticket_id"]]
                                        onCompletion:
             ^(NSError *err, NSDictionary *data) {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     NSLog(@"%@ %@", err, data);
                     if([data[@"result"] isEqualToString:@"success"]) {
                         UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Check In Was Successful"
                                                                          message:@"Guest has been successfully checked in"
                                                                         delegate:nil
                                                                cancelButtonTitle:@"OK"
                                                                otherButtonTitles:nil];
                         [alert show];
                         [self.navigationController popViewControllerAnimated:YES];
                     } else {
                         UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error Occurred During Checkin"
                                                                          message:((err != nil) ? [err localizedDescription] : @"Unknown Error")
                                                                         delegate:nil
                                                                cancelButtonTitle:@"OK"
                                                                otherButtonTitles:nil];
                         [alert show];
                         [self.navigationController popViewControllerAnimated:YES];
                     }
                 });
             }];
        }
    } else if(alertView == self.error_alert) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Table Management

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"test"];
    if(!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"test"];
    [cell setLayoutMargins:UIEdgeInsetsZero];
    [cell.textLabel setText:@"Hello"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
