//
//  APIInterface.m
//  May Ball Check-in
//
//  Created by Peter Birch on 11/05/2016.
//  Copyright © 2016 Peter Birch. All rights reserved.
//

#import "APIInterface.h"

@interface APIInterface ()

@property (nonatomic, retain) NSString * auth_token;

@end

@implementation APIInterface

static APIInterface * _instance;

+ (id)instance {
    if(!_instance) {
        _instance = [[APIInterface alloc] init];
        // Load up token from user defaults
        [_instance setToken:[[NSUserDefaults standardUserDefaults] valueForKey:CURRENT_TOKEN]];
    }
    return _instance;
}

#pragma mark - Host URL Management

+ (void)setHostURL:(NSString *)url {
    [[NSUserDefaults standardUserDefaults] setValue:url forKey:TKTR_HOST_URL];
}

+ (NSString *)hostURL {
    return [[NSUserDefaults standardUserDefaults] valueForKey:TKTR_HOST_URL];
}

#pragma mark - Authentication Token Management

- (void)setToken:(NSString *)token {
    self.auth_token = token;
    if(!token) return;
    [[NSUserDefaults standardUserDefaults] setValue:token forKey:CURRENT_TOKEN];
}

- (void)clearToken {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CURRENT_TOKEN];
    self.auth_token = nil;
}

- (NSString *)token {
    return self.auth_token;
}

#pragma mark - API Base Request Construction

+ (NSURLSession *)apiSession {
    static NSURLSession *session;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        session = [NSURLSession sessionWithConfiguration:config];
    });
    
    return session;
}

+ (NSMutableURLRequest *)apiGetRequestForRoute:(NSString *)route withToken:(NSString *)token {
    
    NSString * route_url_str = [[APIInterface hostURL] stringByAppendingFormat:@"/api/%@", route];
    NSURL * route_url = [NSURL URLWithString:route_url_str];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:route_url];
    request.HTTPMethod = @"GET";
    
    if(token) {
        [request setValue:token forHTTPHeaderField:@"Authorization"];
    }
    
    return request;
    
}

+ (NSMutableURLRequest *)apiPostRequestForRoute:(NSString *)route withValues:(NSDictionary *)values andToken:(NSString *)token {
    
    NSString * route_url_str = [[APIInterface hostURL] stringByAppendingFormat:@"/api/%@", route];
    NSURL * route_url = [NSURL URLWithString:route_url_str];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:route_url];
    request.HTTPMethod = @"POST";
    
    if(token) {
        [request setValue:token forHTTPHeaderField:@"Authorization"];
    }
    
    // Build the query parameters
    if(values && values.count > 0) {
        NSMutableArray * param_pairs = [NSMutableArray array];
        for(NSString * key in values) {
            id value = [values objectForKey:key];
            if([value isKindOfClass:[NSString class]]) {
                NSString * safe_key = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString * safe_value = [(NSString *)value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString * pair = [NSString stringWithFormat:@"%@=%@", safe_key, safe_value];
                [param_pairs addObject:pair];
                
            } else {
                NSString * safe_key = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString * safe_value = [[value stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString * pair = [NSString stringWithFormat:@"%@=%@", safe_key, safe_value];
                [param_pairs addObject:pair];
                
            }
        }
        
        NSString * query_str = [param_pairs componentsJoinedByString:@"&"];
        NSData * query_data = [query_str dataUsingEncoding:NSUTF8StringEncoding];
        request.HTTPBody = query_data;
    }
    
    return request;
}

#pragma mark - API Functions

- (void)apiValidateAuthenticationTokenOnCompletion:(APIResponseBlock)block {
    NSMutableURLRequest * request = [APIInterface apiGetRequestForRoute:@"token/verify" withToken:[self token]];
    NSURLSessionDataTask * task =
    [[APIInterface apiSession] dataTaskWithRequest:request
                                 completionHandler:
     ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
         NSError * err = nil;
         @try {
             NSDictionary * parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
             block(err, parsed);
         } @catch (NSException *exception) {
             block([NSError errorWithDomain:@"parseerror" code:0 userInfo:nil], nil);
         }
         
     }];
    [task resume];
}

- (void)apiQueryByTicketID:(NSString *)ticket_id onCompletion:(APIResponseBlock)block {
    NSMutableURLRequest * request =
        [APIInterface apiPostRequestForRoute:@"checkin/query"
                                  withValues:@{ @"query_type": @"ticket_id",
                                                @"query_value": ticket_id }
                                    andToken:[self token]];
    NSURLSessionDataTask * task =
        [[APIInterface apiSession] dataTaskWithRequest:request
                                     completionHandler:
         ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
             NSError * err = nil;
             @try {
                 NSDictionary * parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                 block(err, parsed);
                 if (err) NSLog(@"An error occurred: %@", err);
             } @catch (NSException *exception) {
                 block([NSError errorWithDomain:@"parseerror" code:0 userInfo:nil], nil);
                 NSLog(@"An error occurred: %@", exception);
             }
         }];
    [task resume];
}

- (void)apiEnactCheckIn:(NSArray *)ticket_ids onCompletion:(APIResponseBlock)block {
    NSError * err = nil;
    NSData * json = [NSJSONSerialization dataWithJSONObject:ticket_ids options:0 error:&err];
    if(err) {
        block(err, nil);
        return;
    }
    NSString * json_str = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSMutableURLRequest * request =
        [APIInterface apiPostRequestForRoute:@"checkin/enact"
                                  withValues:@{ @"ticket_ids": json_str }
                                    andToken:[self token]];
    NSURLSessionDataTask * task =
        [[APIInterface apiSession] dataTaskWithRequest:request
                                     completionHandler:
         ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
             NSError * err = nil;
             @try {
                 NSDictionary * parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                 block(err, parsed);
             } @catch (NSException *exception) {
                 block([NSError errorWithDomain:@"parseerror" code:0 userInfo:nil], nil);
             }
         }];
    [task resume];
}

@end
