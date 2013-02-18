//
//  PSUpdateApp.m
//  PSUpdateApp
//
//  Created by iBo on 18/02/13.
//  Copyright (c) 2013 D-Still. All rights reserved.
//

#import "PSUpdateApp.h"
#import <AFNetworking/AFNetworking.h>

#define APPLE_URL @"http://itunes.apple.com/lookup?"

#define kCurrentAppVersion [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]

@interface PSUpdateApp () <UIAlertViewDelegate> {
    NSString *_newVersion, *_iTunesUrl;
}

@end

@implementation PSUpdateApp

CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(PSUpdateApp)

+ (id) startWithAppID:(NSString *)appId store:(NSString *)store
{
    return [[self alloc] initWithAppID:appId store:store];
}

+ (id) startWithAppID:(NSString *)appId
{
    return [[self alloc] initWithAppID:appId store:nil];
}

- (id) initWithAppID:(NSString *)appId store:(NSString *)store
{
    self = [super init];
    
    if ( self ) {
        [self setAppName:[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey]];
        [self setStrategy:DefaultStrategy];
        [self setAppID:appId];
        [self setAppStoreLocation: store ? store : [[NSLocale currentLocale] objectForKey: NSLocaleCountryCode]];
        [self setDaysUntilPrompt:2];
    }
    
    return self;
}

- (void) detectAppVersion:(PSUpdateAppCompletionBLock)completionBlock
{   
    if ( _strategy == RemindStrategy && [self remindDate] != nil && ![self checkConsecutiveDays] )
        return;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[self setAppleURL]]];
    [request setHTTPMethod:@"GET"];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request
                                                                                        success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                                                                                            if ( [self isNewVersion:JSON] ) {
                                                                                                if ( completionBlock && ![self isSkipVersion] ) {
                                                                                                    completionBlock(nil, YES);
                                                                                                } else if ( ![self isSkipVersion] ) {
                                                                                                    [self showAlert];
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                        failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                                                                                            if ( completionBlock && ![self isSkipVersion] )
                                                                                                completionBlock(error, NO);
                                                                                        }];
    [operation start];
}

- (NSString *) setAppleURL
{
    return [NSString stringWithFormat:@"%@id=%@&country=%@", APPLE_URL, _appID, _appStoreLocation];
}

#pragma mark - Check version

- (BOOL) isNewVersion:(NSDictionary *)dictionary
{
    if ( (int)[dictionary objectForKey:@"resultCount"] >= 1 ) {
        
        _newVersion = [[[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"version"];
        _iTunesUrl = [[[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"trackViewUrl"];
        
        NSLog(@"CURRENT %@ - NEW %@", kCurrentAppVersion, _newVersion);
        
        return [kCurrentAppVersion compare:_newVersion options:NSNumericSearch] == NSOrderedAscending;
    } else {
        return NO;
    }
}

- (BOOL) isSkipVersion
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"skipVersion"] isEqualToString:_newVersion];
}

#pragma mark - remindDate getter / setter

- (NSDate *) remindDate
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"remindDate"];
}

- (void) setRemindDate:(NSDate *)remindDate
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"remindDate"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Show alert

- (void) showAlert
{
    switch (self.strategy) {
        case DefaultStrategy:
        default:
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"alert.success.title", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"alert.success.default.text", nil), _appName, _newVersion]
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"alert.button.skip", nil)
                                                      otherButtonTitles:NSLocalizedString(@"alert.button.update", nil), nil];
            [alertView show];
        }
            break;
            
        case ForceStrategy:
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"alert.success.title", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"alert.success.force.text", nil), _appName, _newVersion]
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"alert.button.update", nil)
                                                      otherButtonTitles:nil, nil];
            [alertView show];
        }
            break;
            
        case RemindStrategy:
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"alert.success.title", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"alert.success.remindme.text", nil), _appName, _newVersion]
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"alert.button.skip", nil)
                                                      otherButtonTitles:NSLocalizedString(@"alert.button.update", nil), NSLocalizedString(@"alert.button.remindme", nil), nil];
            [alertView show];
        }
            break;
    }
}


#pragma mark - UIAlertViewDelegate Methods

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{   
    switch (self.strategy) {
        case DefaultStrategy:
        default:
        {
            if ( buttonIndex == 0) {
                [[NSUserDefaults standardUserDefaults] setObject:_newVersion forKey:@"skipVersion"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_iTunesUrl]];
            }
        }

            break;
            
        case ForceStrategy:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_iTunesUrl]];
            break;
            
        case RemindStrategy:
        {
            if ( buttonIndex == 0) {
                [[NSUserDefaults standardUserDefaults] setObject:_newVersion forKey:@"skipVersion"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else if ( buttonIndex == 1) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_iTunesUrl]];
            } else {
                [self setRemindDate:[NSDate date]];
            }
        }

            break;
    }
}

#pragma mark - Check if have passed

- (BOOL) checkConsecutiveDays
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSDate *dateA = [self remindDate];
    NSDate *dateB = [NSDate date];
    
    NSDate *dateToRound = [dateA earlierDate:dateB];
    int flags = ( NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit );
    NSDateComponents * dateComponents =
    [gregorian components:flags fromDate:dateToRound];
    
    NSDate *roundedDate = [gregorian dateFromComponents:dateComponents];
    NSDate *otherDate = (dateToRound == dateA) ? dateB : dateA ;
    NSInteger diff = abs([roundedDate timeIntervalSinceDate:otherDate]);
    NSInteger daysDifference = floor(diff/(24 * 60 * 60));
    
    NSLog(@"%@ - %@ - %i", dateA, dateB, daysDifference);
    
    return daysDifference >= _daysUntilPrompt;
}

@end