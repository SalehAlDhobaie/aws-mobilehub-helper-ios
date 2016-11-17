//
//  AWSQuickbooksAuthorizationManager.m
//
// Copyright 2016 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSQuickbooksAuthorizationManager.h"
#import <AWSCore/AWSCore.h>

#import <SafariServices/SafariServices.h>
#import <CommonCrypto/CommonHMAC.h>

static NSString *const AWSQuickbooksAuthorizationManagerRequestTokenURLString = @"https://oauth.intuit.com/oauth/v1/get_request_token";
static NSString *const AWSQuickbooksAuthorizationManagerAccessTokenURLString = @"https://oauth.intuit.com/oauth/v1/get_access_token";
static NSString *const AWSSalesforceAuthorizationManagerAuthorizationURLString = @"https://appcenter.intuit.com/Connect/Begin";

@interface AWSQuickbooksAuthorizationManager() <SFSafariViewControllerDelegate>

typedef void (^AWSCompletionBlock)(id result, NSError *error);

- (void)completeLoginWithResult:(id)result error:(NSError *)error;

@property (strong, nonatomic) SFSafariViewController *safariVC;
@property (assign, nonatomic) BOOL dismissOnLoad;

@property (strong, nonatomic) AWSCompletionBlock loginCompletionHandler;
@property (strong, nonatomic) AWSCompletionBlock logoutCompletionHandler;
@property (strong, nonatomic) AWSCompletionBlock refreshCompletionHandler;

@property (strong, nonatomic) NSString *redirectURI;
@property (strong, nonatomic) NSString *key;
@property (strong, nonatomic) NSString *secret;
@property (strong, nonatomic) NSString *token;
@property (strong, nonatomic) NSString *tokenSecret;
@property (strong, nonatomic) NSString *realmID;
@property (strong, nonatomic) NSString *intermediateTokenSecret;

@end

@implementation AWSQuickbooksAuthorizationManager

+ (instancetype)sharedInstance {
    static AWSQuickbooksAuthorizationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [AWSQuickbooksAuthorizationManager new];
    });
    
    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSDictionary *config = [[[AWSInfo defaultAWSInfo].rootInfoDictionary objectForKey:@"SaaS"] objectForKey:@"Quickbooks"];
        [self configureWithAPIKey:[config objectForKey:@"APIKey"]
                      redirectURI:[config objectForKey:@"RedirectURI"]];
        return self;
    }
    return nil;
}

#pragma mark - External API

- (void)configureWithAPIKey:(NSString *)key
                redirectURI:(NSString *)redirectURI {
    self.key = key ?: @"";
    self.redirectURI = redirectURI ?: @"";
}

- (void)setAPISecret:(NSString *)secret {
    self.secret = secret;
}

- (NSString *)getAPIKey {
    return self.key;
}

- (NSString *)getAPISecret {
    return self.secret;
}

- (NSString *)getAccessToken {
    return self.token;
}

- (NSString *)getAccessTokenSecret {
    return self.tokenSecret;
}

- (NSString *)getRealmID {
    return _realmID;
}

- (void)authorizeWithView:(UIViewController * _Nonnull)authorizeViewController
        completionHandler:(void (^_Nullable)(id _Nullable, NSError * _Nullable))completionHandler {
    self.loginCompletionHandler = completionHandler;
    
    [self generateOAuthRequestToken:^(NSError *error, NSDictionary *responseParams) {
        if (error) {
            [self completeLoginWithResult:nil error:error];
        }
        
        self.intermediateTokenSecret = responseParams[@"oauth_token_secret"];
        NSString *oauth_token = responseParams[@"oauth_token"];
        
        if (self.intermediateTokenSecret && oauth_token) {
            NSString *authenticationUrl = [NSString stringWithFormat:@"%@?oauth_token=%@", AWSSalesforceAuthorizationManagerAuthorizationURLString, oauth_token];
            
            self.safariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:authenticationUrl]
                                                entersReaderIfAvailable:NO];
            self.safariVC.delegate = self;
            self.dismissOnLoad = NO;
            [authorizeViewController presentViewController:self.safariVC animated:YES completion:nil];
        } else {
            [self completeLoginWithResult:nil error:nil];
        }
    }];
}

#pragma mark - Internal use

- (void)generateOAuthRequestToken:(void (^)(NSError *error, NSDictionary *responseParams))completion {
    NSMutableString *formString = [NSMutableString new];
    [formString appendFormat:@""];
    [formString appendFormat:@"oauth_callback=%@", [self escape:self.redirectURI]];
    [formString appendFormat:@"&oauth_consumer_key=%@", self.key];
    [formString appendFormat:@"&oauth_nonce=%u", arc4random_uniform(UINT32_MAX)];
    [formString appendFormat:@"&oauth_signature_method=%@", @"HMAC-SHA1"];
    [formString appendFormat:@"&oauth_timestamp=%d", (int) [[NSDate date] timeIntervalSince1970]];
    [formString appendFormat:@"&oauth_version=%@", @"1.0"];
    
    NSString *message = [NSString stringWithFormat:@"GET&%@&%@", [self escape:AWSQuickbooksAuthorizationManagerRequestTokenURLString], [self escape:formString]];
    NSString *secret = [NSString stringWithFormat:@"%@&", self.secret];
    NSString *signature = [self sha1HMacWithData:[message dataUsingEncoding:NSUTF8StringEncoding]
                                         withKey:[secret dataUsingEncoding:NSUTF8StringEncoding]];
    
    [formString appendFormat:@"&oauth_signature=%@", [self escape:signature]];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", AWSQuickbooksAuthorizationManagerRequestTokenURLString, formString];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        if(connectionError) {
            completion(connectionError, nil);
            return;
        }
        AWSLogVerbose(@"Completed Quickbooks first leg.");
        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        completion(nil, [AWSAuthorizationManager constructParametersWithURI:responseString]);
    }];
}

- (NSString *)sha1HMacWithData:(NSData *)data withKey:(NSData *)key {
    CCHmacContext context;
    
    CCHmacInit(&context, kCCHmacAlgSHA1, [key bytes], [key length]);
    CCHmacUpdate(&context, [data bytes], [data length]);
    
    unsigned char digestRaw[CC_SHA1_DIGEST_LENGTH];
    NSInteger digestLength = CC_SHA1_DIGEST_LENGTH;
    
    CCHmacFinal(&context, digestRaw);
    
    return [[NSData dataWithBytes:digestRaw length:digestLength] base64EncodedStringWithOptions:kNilOptions];
}

- (NSString *)escape:(NSString *)string {
    string = [string stringByReplacingOccurrencesOfString:@"%" withString:@"%25"];
    string = [string stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
    string = [string stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    string = [string stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
    string = [string stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
    return string;
}

- (BOOL)handleURL:(NSURL *)url {
    if (![self isAcceptedURL:url]) {
        return NO;
    }
    AWSLogVerbose(@"Completed Quickbooks second leg.");
    NSDictionary *params =  [AWSAuthorizationManager constructParametersWithURI:[url query]];
    self.realmID = params[@"realmId"];
    
    NSMutableString *formString = [NSMutableString new];
    [formString appendFormat:@"oauth_consumer_key=%@", self.key];
    [formString appendFormat:@"&oauth_nonce=%u", arc4random_uniform(UINT32_MAX)];
    [formString appendFormat:@"&oauth_signature_method=%@", @"HMAC-SHA1"];
    [formString appendFormat:@"&oauth_timestamp=%d", (int) [[NSDate date] timeIntervalSince1970]];
    [formString appendFormat:@"&oauth_token=%@", params[@"oauth_token"]];
    [formString appendFormat:@"&oauth_verifier=%@", params[@"oauth_verifier"]];
    [formString appendFormat:@"&oauth_version=%@", @"1.0"];
    
    NSString *message = [NSString stringWithFormat:@"GET&%@&%@",
                         [self escape:AWSQuickbooksAuthorizationManagerAccessTokenURLString], [self escape:formString]];
    NSString *secret = [NSString stringWithFormat:@"%@&%@", self.secret, self.intermediateTokenSecret];
    NSString *signature = [self sha1HMacWithData:[message dataUsingEncoding:NSUTF8StringEncoding]
                                         withKey:[secret dataUsingEncoding:NSUTF8StringEncoding]];
    
    [formString appendFormat:@"&oauth_signature=%@",[self escape:signature]];
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", AWSQuickbooksAuthorizationManagerAccessTokenURLString, formString];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:urlString]];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        if (connectionError) {
            AWSLogVerbose(@"Error: %@", connectionError.description);
            [self completeLoginWithResult:nil error:connectionError];
            return;
        }
        AWSLogVerbose(@"Completed Quickbooks third leg.");
        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSDictionary *oauthTokens = [AWSAuthorizationManager constructParametersWithURI:responseString];
        self.token = oauthTokens[@"oauth_token"];
        self.tokenSecret = oauthTokens[@"oauth_token_secret"];
        [self completeLoginWithResult:@{@"api_key": self.key,
                                        @"api_secret": self.secret,
                                        @"access_token": self.token,
                                        @"access_token_secret": self.tokenSecret,
                                        @"realm_id": self.realmID}
                                error:nil];
    }];
    
    return YES;
}

- (BOOL)isAcceptedURL:(NSURL *)url {
    return [[url absoluteString] hasPrefix:self.redirectURI];
}

- (void)completeLoginWithResult:(id)result
                          error:(NSError *)error {
    AWSLogVerbose(@"completeLoginWithResult called");
    
    NSError *surfacedError = result ? nil : (error ?: [NSError errorWithDomain:AWSAuthorizationManagerErrorDomain
                                                                          code:AWSAuthorizationErrorFailedToRetrieveAccessToken
                                                                      userInfo:nil]);
    if (surfacedError) {
        AWSLogError(@"Error: %@", surfacedError);
    }
    
    if (self.loginCompletionHandler) {
        self.loginCompletionHandler(result, surfacedError);
        self.loginCompletionHandler = nil;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.safariVC) {
            [self.safariVC dismissViewControllerAnimated:YES completion: nil];
            self.safariVC = nil;
        }
    });
}

- (NSURL *)generateLogoutURL {
    return nil;
}

- (void)destroyAccessToken {
    self.token = nil;
    self.tokenSecret = nil;
}

#pragma mark - SFSafariViewControllerDelegate

-(void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    // Load finished
    if (self.dismissOnLoad) {
        if (self.logoutCompletionHandler) {
            self.logoutCompletionHandler(@{@"didSucceed" : @YES}, nil);
            self.logoutCompletionHandler = nil;
        }
        [controller dismissViewControllerAnimated:true completion: nil];
    }
}

-(void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    if (self.dismissOnLoad && self.logoutCompletionHandler) {
        self.logoutCompletionHandler(@{@"didSucceed" : @NO}, [NSError errorWithDomain:AWSAuthorizationManagerErrorDomain
                                                                                 code:AWSAuthorizationErrorUserCancelledFlow
                                                                             userInfo:@{@"message": @"User login cookies may not have been cleared."}]);
        self.logoutCompletionHandler = nil;
    } else if (!self.dismissOnLoad && self.loginCompletionHandler) {
        [self completeLoginWithResult:nil error:[NSError errorWithDomain:AWSAuthorizationManagerErrorDomain
                                                                    code:AWSAuthorizationErrorUserCancelledFlow
                                                                userInfo:@{@"message": @"User cancelled authorization flow."}]];
    }
}

@end
