//
//  TicketInfoViewController.h
//  May Ball Check-in
//
//  Created by Peter Birch on 11/05/2016.
//  Copyright © 2016 Peter Birch. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TicketInfoViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>

- (void)setLookupDetails:(NSString *)qr_code;

@end
