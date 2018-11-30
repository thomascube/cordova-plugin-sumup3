#import "CDVSumup.h"
#import <SumUpSDK/SumUpSDK.h>

@implementation CDVSumup

- (void)pluginInitialize
{
    [[NSBundle mainBundle] infoDictionary];
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    affiliateKey = [infoDict objectForKey:@"SUMUP_API_KEY"];

    if (affiliateKey == nil) {
        NSLog(@"CDVSumup: missing SUMUP_API_KEY preference key");
    }

    [SMPSumUpSDK setupWithAPIKey:affiliateKey];
}

- (void)prepareToPay:(CDVInvokedUrlCommand*)command
{
    [SMPSumUpSDK prepareForCheckout];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)pay:(CDVInvokedUrlCommand*)command
{
    SMPCheckoutRequest *request;
    NSString* amount = [command.arguments objectAtIndex:0];
    NSString* currency = nil;
    NSString* title = nil;

    if ([command.arguments count] > 1) {
        currency = [command.arguments objectAtIndex:1];
    } else {
        currency = [[SMPSumUpSDK currentMerchant] currencyCode];
    }
    if ([command.arguments count] > 2) {
        title = [command.arguments objectAtIndex:2];
    }

    if ([SMPSumUpSDK checkoutInProgress]) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Error 0x00251: Failed to start payment. Checkout already in progress"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    request = [SMPCheckoutRequest requestWithTotal:[NSDecimalNumber decimalNumberWithString:amount]
                                             title:title
                                      currencyCode:currency
                                    paymentOptions:SMPPaymentOptionAny];

    // set ForeignTransactionID
    if ([command.arguments count] > 3) {
        [request setForeignTransactionID:[command.arguments objectAtIndex:3]];
    }

    int skipSuccesScreen = 0;
    if ([command.arguments count] > 4) {
        skipSuccesScreen = ((NSNumber *)[command.arguments objectAtIndex:4]).intValue;
    }
    if (skipSuccesScreen > 0) {
        [request setSkipScreenOptions:SMPSkipScreenOptionSuccess];
    }

    // TODO: set receipt preferences with optional email and phone number arguments

    [SMPSumUpSDK checkoutWithRequest:request fromViewController:self.viewController completion:^(SMPCheckoutResult *result, NSError *error) {
        CDVPluginResult* pluginResult = nil;
        
        if (error != nil) {
            NSString *message = [NSString stringWithFormat:@"Error 0x002%02d: CheckoutWithRequest failed. %@", (int)error.code, [self getErrorMessage:error]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        }

        if (result.success) {
            // translate SMPCheckoutResult into a dict for returning
            NSMutableDictionary *info;
            if (result.additionalInfo != nil) {
                info = [NSMutableDictionary dictionaryWithDictionary:result.additionalInfo];
            } else {
                info = [NSMutableDictionary dictionaryWithCapacity:1];
            }
            [info setObject:result.transactionCode forKey:@"txcode"];
            NSLog(@"CDVSumup: checkoutWithRequest(): %@", info);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:info];
        } else if (pluginResult == nil) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Error 0x00210: CheckoutWithRequest failed with non-success result"];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)loginWithToken:(CDVInvokedUrlCommand*)command
{
    NSString* token = [command.arguments objectAtIndex:0];
    [SMPSumUpSDK loginWithToken:token completion:^(BOOL success, NSError *error) {
        CDVPluginResult* pluginResult = nil;

        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self getCurrentMerchantInfo]];
        } else {
            NSLog(@"CDVSumup: loginWithToken failed with error: %@", error);
            NSString *message = [NSString stringWithFormat:@"Error 0x000%02d: LoginWithToken failed. %@", (int)error.code, [self getErrorMessage:error]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)login:(CDVInvokedUrlCommand *)command
{
    [SMPSumUpSDK presentLoginFromViewController:self.viewController animated:YES completionBlock:^(BOOL success, NSError *error) {
        CDVPluginResult* pluginResult = nil;

        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self getCurrentMerchantInfo]];
        } else {
            NSLog(@"CDVSumup: login failed with error: %@", error);
            NSString *message = [NSString stringWithFormat:@"Error 0x000%02d: Login failed. %@", (int)error.code, [self getErrorMessage:error]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)logout:(CDVInvokedUrlCommand *)command
{
    [SMPSumUpSDK logoutWithCompletionBlock:^(BOOL success, NSError *error) {
        CDVPluginResult* pluginResult = nil;

        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
        } else {
            NSLog(@"CDVSumup: logout failed with error: %@", error);
            NSString *message = [NSString stringWithFormat:@"Error 0x001%02d: Logout failed. %@", (int)error.code, [self getErrorMessage:error]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)settings:(CDVInvokedUrlCommand*)command
{
    [SMPSumUpSDK presentCheckoutPreferencesFromViewController:self.viewController animated:YES completion:^(BOOL success, NSError *error) {
        CDVPluginResult* pluginResult = nil;
        
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
        } else {
            NSLog(@"CDVSumup: presentCheckoutPreferencesFromViewController failed with error: %@", error);
            NSString *message = [NSString stringWithFormat:@"Error 0x003%02d: CheckoutPreferences command failed. %@", (int)error.code, [self getErrorMessage:error]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (NSDictionary*)getCurrentMerchantInfo
{
    SMPMerchant *merchant = [SMPSumUpSDK currentMerchant];
    NSDictionary *info = @{
                           @"merchantCode": [merchant merchantCode],
                           @"currencyCode": [merchant currencyCode]
                           };
    
    return info;
}

- (NSString*)getErrorMessage:(NSError*)error
{
    switch (error.code) {
        case SMPSumUpSDKErrorActivationNeeded:
        return @"Activation needed";

        case SMPSumUpSDKErrorAccountGeneral:
        return @"General error with merchant account";

        case SMPSumUpSDKErrorAccountNotLoggedIn:
        return @"No active merchant account login";

        case SMPSumUpSDKErrorAccountIsLoggedIn:
        return @"Merchant already logged in";

        case SMPSumUpSDKErrorCheckoutGeneral:
        return @"General error during checkout";

        case SMPSumUpSDKErrorCheckoutInProgress:
        return @"Checkout already in progress";

        case SMPSumUpSDKErrorCheckoutCurrencyCodeMismatch:
        return @"Checkout currency code mismatch";

        default:
        return @"General error";
    }
}

@end
