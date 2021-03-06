/*
 Copyright 2016 Urban Airship and Contributors
*/

#import "ComUrbanairshipModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "AirshipLib.h"

@interface ComUrbanairshipModule()
@property (nonatomic, copy) NSDictionary *launchPush;
@end

@implementation ComUrbanairshipModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID {
	return @"fbe797b5-475d-456a-bbb4-9bb9919fd63f";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId {
	return @"com.urbanairship";
}

#pragma mark UAPushNotificationDelegate

- (void)launchedFromNotification:(NSDictionary *)notification {
    UA_LDEBUG(@"The application was launched or resumed from a notification %@", notification);
    self.launchPush = notification;
}

- (void)receivedForegroundNotification:(NSDictionary *)notification {
    UA_LDEBUG(@"Received a notification while the app was already in the foreground %@", [notification description]);

    [[UAirship push] setBadgeNumber:0]; // zero badge after push received

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:[ComUrbanairshipModule alertForUserInfo:notification] forKey:@"message"];
    [data setValue:[ComUrbanairshipModule extrasForUserInfo:notification] forKey:@"extras"];

    [self fireEvent:self.EVENT_PUSH_RECEIVED withObject:data];
}

#pragma mark UARegistrationDelegate

- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken {
    UA_LINFO(@"Channel registration successful %@.", channelID);

    NSDictionary *data;
    if (deviceToken) {
        data = @{ @"channelId":channelID, @"deviceToken":deviceToken };
    } else {
        data = @{ @"channelId":channelID };
    }

    [self fireEvent:self.EVENT_CHANNEL_UPDATED withObject:data];
}


#pragma mark Lifecycle

-(void)startup {
    [super startup];

    dispatch_async(dispatch_get_main_queue(), ^{
        [UAirship push].pushNotificationDelegate = self;
        [UAirship push].registrationDelegate = self;
        self.launchPush = [UAirship push].launchNotification;
    });
}


#pragma Public APIs

-(NSString *)EVENT_PUSH_RECEIVED {
    return @"EVENT_PUSH_RECEIVED";
}

-(NSString *)EVENT_CHANNEL_UPDATED {
    return @"EVENT_CHANNEL_UPDATED";
}

- (void)displayMessageCenter:(id)args {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UAirship defaultMessageCenter] display];
    });
}

- (id)userNotificationsEnabled {
    return NUMBOOL([UAirship push].userPushNotificationsEnabled);
}

- (void)setUserNotificationsEnabled:(id)value {
    [UAirship push].userPushNotificationsEnabled = [TiUtils boolValue:value def:YES];
    [[UAirship push] updateRegistration];
}

- (NSArray *)tags {
    return [UAirship push].tags;
}

- (void)setTags:(id)args {
    ENSURE_ARRAY(args);

    [UAirship push].tags = args;
    [[UAirship push] updateRegistration];
}

-(NSString *)channelId {
    return [UAirship push].channelID;
}

- (NSString *)namedUser {
    return [UAirship push].namedUser.identifier;
}

- (void)setNamedUser:(id)value {
    ENSURE_STRING(value);
    [UAirship push].namedUser.identifier = [value length] ? value : nil;
}

- (NSDictionary *)getLaunchNotification:(id)args {
    NSString *incomingAlert = @"";
    NSMutableDictionary *incomingExtras = [NSMutableDictionary dictionary];

    if (self.launchPush) {
        incomingAlert = [ComUrbanairshipModule alertForUserInfo:self.launchPush];
        [incomingExtras setDictionary:[ComUrbanairshipModule extrasForUserInfo:self.launchPush]];
    }

    NSMutableDictionary *push = [NSMutableDictionary dictionary];

    [push setObject:incomingAlert forKey:@"message"];
    [push setObject:incomingExtras forKey:@"extras"];

    if ([TiUtils boolValue:[args firstObject] def:NO]) {
        self.launchPush = nil;
    }
    
    return push;
}

- (NSDictionary *)launchNotification {
    [self getLaunchNotification:@[NUMBOOL(NO)]];
}

#pragma mark Helpers

/**
 * Helper method to parse the alert from a notification.
 *
 * @param userInfo The notification.
 * @return The notification's alert.
 */
+ (NSString *)alertForUserInfo:(NSDictionary *)userInfo {
    NSString *alert = @"";

    if ([[userInfo allKeys] containsObject:@"aps"]) {
        NSDictionary *apsDict = [userInfo objectForKey:@"aps"];
        //TODO: what do we want to do in the case of a localized alert dictionary?
        if ([[apsDict valueForKey:@"alert"] isKindOfClass:[NSString class]]) {
            alert = [apsDict valueForKey:@"alert"];
        }
    }

    return alert;
}

/**
 * Helper method to parse the extras from a notification.
 *
 * @param userInfo The notification.
 * @return The notification's extras.
 */
+ (NSMutableDictionary *)extrasForUserInfo:(NSDictionary *)userInfo {

    // remove extraneous key/value pairs
    NSMutableDictionary *extras = [NSMutableDictionary dictionaryWithDictionary:userInfo];

    if([[extras allKeys] containsObject:@"aps"]) {
        [extras removeObjectForKey:@"aps"];
    }
    if([[extras allKeys] containsObject:@"_"]) {
        [extras removeObjectForKey:@"_"];
    }
    
    return extras;
}

@end