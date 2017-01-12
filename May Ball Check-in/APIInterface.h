//
//  APIInterface.h
//  May Ball Check-in
//
//  Created by Peter Birch on 11/05/2016.
//  Copyright © 2016 Peter Birch. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TKTR_HOST_URL @"uk.co.lightlogic.tktr.tktrhosturl"
#define CURRENT_TOKEN @"uk.co.lightlogic.tktr.currenttoken"

typedef void (^APIResponseBlock)(NSError * err, NSDictionary * data);

@interface APIInterface : NSObject

+ (id)instance;

+ (void)setHostURL:(NSString *)url;
+ (NSString *)hostURL;

- (void)setToken:(NSString *)token;
- (NSString *)token;

+ (NSMutableURLRequest *)apiGetRequestForRoute:(NSString *)route withToken:(NSString *)token;
+ (NSMutableURLRequest *)apiPostRequestForRoute:(NSString *)route withValues:(NSDictionary *)values andToken:(NSString *)token;

- (void)apiValidateAuthenticationTokenOnCompletion:(APIResponseBlock)block;
- (void)apiQueryByTicketID:(NSString *)ticket_id onCompletion:(APIResponseBlock)block;
- (void)apiEnactCheckIn:(NSArray *)ticket_ids onCompletion:(APIResponseBlock)block;

@end
