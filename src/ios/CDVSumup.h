#import <Cordova/CDVPlugin.h>

@interface CDVSumup : CDVPlugin
{
    NSString *affiliateKey;
}

- (void)pay:(CDVInvokedUrlCommand*)command;
- (void)loginWithToken:(CDVInvokedUrlCommand*)command;
- (void)login:(CDVInvokedUrlCommand*)command;
- (void)logout:(CDVInvokedUrlCommand*)command;
- (void)isLoggedIn:(CDVInvokedUrlCommand*)command;
- (void)settings:(CDVInvokedUrlCommand*)command;
- (void)prepareToPay:(CDVInvokedUrlCommand*)command;

@end
