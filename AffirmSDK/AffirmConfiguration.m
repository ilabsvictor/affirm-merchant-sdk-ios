//
//  AffirmConfiguration.m
//  AffirmSDK
//
//  Created by Victor Zhu on 2019/3/18.
//  Copyright © 2019 Affirm, Inc. All rights reserved.
//

#import "AffirmConfiguration.h"
#import "AffirmUtils.h"
#import "AffirmLogger.h"

@interface AffirmConfiguration ()

@property (nonatomic, copy, readwrite) NSString *publicKey;
@property (nonatomic, readwrite) AffirmEnvironment environment;
@property (nonatomic, copy, readwrite, nullable) NSString *merchantName;

@end

@implementation AffirmConfiguration

+ (instancetype)sharedInstance
{
    static AffirmConfiguration *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _environment = AffirmEnvironmentSandbox;
    }
    return self;
}

- (void)configureWithPublicKey:(NSString *)publicKey
                   environment:(AffirmEnvironment)environment
{
    [self configureWithPublicKey:publicKey
                     environment:environment
                    merchantName:nil];
}

- (void)configureWithPublicKey:(NSString *)publicKey
                   environment:(AffirmEnvironment)environment
                  merchantName:(NSString * _Nullable )merchantName
{
    self.publicKey = [publicKey copy];
    self.environment = environment;
    self.merchantName = [merchantName copy];
    [self deleteAffirmCookies];
}

- (BOOL)isProductionEnvironment
{
    return self.environment == AffirmEnvironmentProduction;
}

- (NSString *)publicKey
{
    if (_publicKey == nil) {
        return @"";
    }
    return _publicKey;
}

+ (NSString *)affirmSDKVersion
{
    return [[NSBundle resourceBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
}

- (NSString *)environmentDescription
{
    switch(self.environment) {
        case AffirmEnvironmentProduction:
            return @"production";
        case AffirmEnvironmentSandbox:
            return @"sandbox";
    }
}

- (void)deleteAffirmCookies
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in cookieStorage.cookies) {
        NSString *domain = cookie.domain;
        if ([domain hasSuffix:@"affirm.com"] || [domain hasSuffix:@"affirm-stage.com"] || [domain hasSuffix:@"affirm-dev.com"]) {
            [cookieStorage deleteCookie:cookie];
        }
    }
}

@end