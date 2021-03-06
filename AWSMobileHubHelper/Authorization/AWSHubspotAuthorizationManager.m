//
//  AWSHubspotAuthorizationManager.m
//
// Copyright 2016 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSHubspotAuthorizationManager.h"
#import <AWSCore/AWSCore.h>

static NSString *const AWSHubspotAuthorizationManagerAuthorizeURLString = @"https://app.hubspot.com/oauth/authorize";
static NSString *const AWSHubspotAuthorizationManagerAuthenticateURLString = @"https://app.hubspot.com/auth/authenticate";

@interface AWSAuthorizationManager()

- (void)completeLoginWithResult:(id)result
                          error:(NSError *)error;
- (void)clearAccessToken;

@end

@interface AWSHubspotAuthorizationManager()

@property (strong, nonatomic) NSString *clientID;
@property (strong, nonatomic) NSString *portalID;
@property (strong, nonatomic) NSString *clientSecret;
@property (strong, nonatomic) NSString *redirectURI;
@property (strong, nonatomic) NSString *scope;

@property (strong, nonatomic) NSDictionary *valuesFromResponse;

@end

@implementation AWSHubspotAuthorizationManager

+ (instancetype)sharedInstance {
    static AWSHubspotAuthorizationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[AWSHubspotAuthorizationManager alloc] init];
    });
    
    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSDictionary *config = [[[AWSInfo defaultAWSInfo].rootInfoDictionary objectForKey:@"SaaS"] objectForKey:@"HubSpot"];
        [self configureWithClientID:[config objectForKey:@"ClientID"]
                           portalID:[config objectForKey:@"PortalID"]
                        redirectURI:[config objectForKey:@"RedirectURI"]];
        
        return self;
    }
    return nil;
}

- (void)configureWithClientID:(NSString *)clientID
                     portalID:(NSString *)portalID
                  redirectURI:(NSString *)redirectURI {
    self.clientID = clientID;
    self.portalID = portalID;
    self.redirectURI = redirectURI;
}

#pragma mark - Override Custom Methods

- (BOOL)usesImplicitGrant {
    return YES;
}

- (NSURL *)generateAuthURL {
    NSMutableString *missingParams = [NSMutableString new];
    
    if ([self.clientID length] == 0) {
        [missingParams appendString:@"clientID "];
    }
    
    if ([self.portalID length] == 0) {
        [missingParams appendString:@"portalID "];
    }
    
    if ([self.redirectURI length] == 0) {
        [missingParams appendString:@"redirectURI "];
    }
    
    if ([self.scope length] == 0) {
        [missingParams appendString:@"scope "];
    }
    
    if ([missingParams length] > 0) {
        NSString *message = [NSString stringWithFormat:@"Missing parameter(s): %@", missingParams];
        [self completeLoginWithResult:nil error:[NSError errorWithDomain:AWSAuthorizationManagerErrorDomain
                                                                    code:AWSAuthorizationErrorMissingRequiredParameter
                                                                userInfo:@{@"message": message}]];
    }
    
    NSDictionary *params = @{
                             @"client_id" : self.clientID,
                             @"portalId" : self.portalID,
                             @"redirect_uri" : [self.redirectURI stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                             @"scope" : [self.scope stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]
                             };
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", AWSHubspotAuthorizationManagerAuthenticateURLString, [AWSAuthorizationManager constructURIWithParameters:params]];
    NSLog(@"generated %@", urlString);
    return [NSURL URLWithString:urlString];
}

- (BOOL)isAcceptedURL:(NSURL *)url {
    return [[url absoluteString] hasPrefix:self.redirectURI];
}

- (NSString *)findAccessCode:(NSURL *)url {
    NSLog(@"findAccessCode %@", [url absoluteString]);
    NSString *prefix = [NSString stringWithFormat:@"%@?", self.redirectURI];
    NSString *formString = [[url absoluteString] stringByReplacingOccurrencesOfString:prefix withString:@""];
    self.valuesFromResponse = [AWSAuthorizationManager constructParametersWithURI:formString];
    return [self.valuesFromResponse objectForKey:@"access_token"];
}

// Keep as reference code, when this flow is actually supported from Hubspot
- (void)getAccessTokenUsingAuthorizationCode:(NSString *)authorizationCode {
    NSDictionary *params = @{@"grant_type" : @"authorization_code",
                             @"code" : authorizationCode,
                             @"client_id" : self.clientID,
                             @"redirect_uri" : self.redirectURI,
                             };
    
    NSString *post = [AWSAuthorizationManager constructURIWithParameters:params];
    
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"https://app.hubspot.com/oauth/v1/token"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    __weak AWSHubspotAuthorizationManager *weakSelf = self;
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [weakSelf completeLoginWithResult:nil error:error];
            return;
        }
        
        weakSelf.valuesFromResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        [weakSelf completeLoginWithResult:[self.valuesFromResponse objectForKey:@"access_token"] error:nil];
    }];
    [task resume];
}

- (NSURL *)generateLogoutURL {
    return nil;
}

- (void)clearAccessToken {
    [super clearAccessToken];
    self.valuesFromResponse = nil;
}

@end
