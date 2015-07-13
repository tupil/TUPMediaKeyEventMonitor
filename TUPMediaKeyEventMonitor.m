/*
 * Author: Eelco Lempsink <eml@tupil.com>
 *
 * Inspired by SPMediaKeyTap https://github.com/nevyn/SPMediaKeyTap
 *
 * Copyright (c) 2011, Joachim Bengtsson
 * Copyright (c) 2015-2015 Tupil B.V.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "TUPMediaKeyEventMonitor.h"

const static NSString* TUPMediaKeyEventMonitorEnabledKey = @"TUPMediaKeyEventMonitorEnabled";

@interface TUPMediaKeyEventMonitorThread : NSThread
- (instancetype)initWithMediaKeyEventHandler:(BOOL (^)(NSEvent*))handler;
@end

#pragma mark - TUPMediaKeyEventMonitor

@implementation TUPMediaKeyEventMonitor {
    NSThread* keyEventTapThread;
    NSMutableArray* runningMediaKeyAppsSortedByLastActive;
}

#pragma mark - Setup

- (instancetype)init
{
    self = [super init];
    if (self) {
        runningMediaKeyAppsSortedByLastActive = [NSMutableArray new];
        [self startMonitoringAppSwitching];
    }
    return self;
}

-(void)dealloc
{
	[self stopMonitoring];
	[self stopMonitoringAppSwitching];
}

#pragma mark - Public methods

-(void)startMonitoring
{
    // Every app using this framework needs to have this in the bundle, so other apps can check if
    // they should let key events through (if they are not frontmost)
    NSAssert([[[NSBundle mainBundle] infoDictionary][TUPMediaKeyEventMonitorEnabledKey] boolValue], @"Enable TUPMediaKeyEventMonitor adding the key ‘TUPMediaKeyEventMonitorEnabled’ in the Info.plist with the boolean value YES.");

    if (keyEventTapThread == nil) {
        [self setKeyTapEnabled:YES];
    }
}

-(void)stopMonitoring
{
    if (keyEventTapThread != nil) {
        [self setKeyTapEnabled:NO];
    }
}

- (void)handleLocalMediaKeyEvent:(NSEvent*)event {
    // If a tap thread is active, ignore this event
    if (keyEventTapThread == nil) {
        [self handleMediaKeyEvent:event];
    }
}

#pragma mark - Private methods

- (void)startMonitoringAppSwitching
{
    [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:@"frontmostApplication" options:NSKeyValueObservingOptionInitial context:NULL];
    [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:@"runningApplications" options:0 context:NULL];
}

- (void)stopMonitoringAppSwitching
{
    [[NSWorkspace sharedWorkspace] removeObserver:self forKeyPath:@"frontmostApplication"];
    [[NSWorkspace sharedWorkspace] removeObserver:self forKeyPath:@"runningApplications"];
}

- (void)setKeyTapEnabled:(BOOL)enabled
{
    if (enabled && keyEventTapThread == nil) {
        keyEventTapThread = [[TUPMediaKeyEventMonitorThread alloc] initWithMediaKeyEventHandler:^BOOL(NSEvent *event) {
            return [self handleMediaKeyEvent:event];
        }];
        [keyEventTapThread start];
    }

    if (enabled == NO && keyEventTapThread != nil) {
        [keyEventTapThread cancel];
        keyEventTapThread = nil;
    }
}

- (BOOL)handleMediaKeyEvent:(NSEvent*)event
{
    if ([event type] != NX_SYSDEFINED || [event subtype] != NX_SUBTYPE_AUX_CONTROL_BUTTONS) {
        return NO;
    } // else

    int keyCode = (([event data1] & 0xFFFF0000) >> 16);
    if (keyCode != NX_KEYTYPE_PLAY &&
        keyCode != NX_KEYTYPE_FAST &&
        keyCode != NX_KEYTYPE_REWIND &&
        keyCode != NX_KEYTYPE_PREVIOUS &&
        keyCode != NX_KEYTYPE_NEXT)
    {
        return NO;
    } // else

    int keyFlags = ([event data1] & 0x0000FFFF);
    BOOL keyIsRepeat = (keyFlags & 0x1) == 0x1;
    BOOL keyIsPressed = (((keyFlags & 0xFF00) >> 8)) == 0xA;

    if (keyIsPressed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate mediaKeyEventMonitor:self keyPressWithCode:keyCode repeat:keyIsRepeat];
        });
    }

    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [NSWorkspace sharedWorkspace]) {

        if ([keyPath isEqualToString:@"frontmostApplication"]) {
            NSRunningApplication* frontmost = [[NSWorkspace sharedWorkspace] frontmostApplication];
            NSURL* frontmostBundleURL = [frontmost bundleURL];

            if (frontmostBundleURL != nil) {
                NSBundle* frontmostBundle = [NSBundle bundleWithURL:frontmostBundleURL];
                NSArray *whitelistIdentifiers = [[self class] knownMediaKeyMonitoringAppsBundleIdentifiers];

                BOOL hasMediaKeyEventMonitorEnabled = [[frontmostBundle infoDictionary][TUPMediaKeyEventMonitorEnabledKey] boolValue];
                BOOL isWhitelisted = [whitelistIdentifiers containsObject:frontmost.bundleIdentifier];

                if (isWhitelisted || hasMediaKeyEventMonitorEnabled) {
                    @synchronized(runningMediaKeyAppsSortedByLastActive) {
                        [runningMediaKeyAppsSortedByLastActive removeObject:frontmost];
                        [runningMediaKeyAppsSortedByLastActive insertObject:frontmost atIndex:0];

                        [self setKeyTapEnabled:[frontmost isEqual:[NSRunningApplication currentApplication]]];
                    }
                }
            }
        }

        if ([keyPath isEqualToString:@"runningApplications"]) {
            @synchronized(runningMediaKeyAppsSortedByLastActive) {
                [runningMediaKeyAppsSortedByLastActive filterUsingPredicate:[NSPredicate predicateWithFormat:@"self IN %@", [[NSWorkspace sharedWorkspace] runningApplications]]];

                [self setKeyTapEnabled:[[runningMediaKeyAppsSortedByLastActive firstObject] isEqual:[NSRunningApplication currentApplication]]];
            }
        }
    }
}

+ (NSArray*)knownMediaKeyMonitoringAppsBundleIdentifiers
{
    static NSArray* knownMediaKeyMonitoringAppsBundleIdentifiers = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownMediaKeyMonitoringAppsBundleIdentifiers =
        [NSArray arrayWithObjects:
         [[NSBundle mainBundle] bundleIdentifier], // your app
         @"com.spotify.client",
         @"com.apple.iTunes",
         @"com.apple.QuickTimePlayerX",
         @"com.apple.quicktimeplayer",
         @"com.apple.iWork.Keynote",
         @"com.apple.iPhoto",
         @"org.videolan.vlc",
         @"com.apple.Aperture",
         @"com.plexsquared.Plex",
         @"com.soundcloud.desktop",
         @"org.niltsh.MPlayerX",
         @"com.ilabs.PandorasHelper",
         @"com.mahasoftware.pandabar",
         @"com.bitcartel.pandorajam",
         @"org.clementine-player.clementine",
         @"fm.last.Last.fm",
         @"fm.last.Scrobbler",
         @"com.beatport.BeatportPro",
         @"com.Timenut.SongKey",
         @"com.macromedia.fireworks", // the tap messes up their mouse input
         @"at.justp.Theremin",
         @"ru.ya.themblsha.YandexMusic",
         @"com.jriver.MediaCenter18",
         @"com.jriver.MediaCenter19",
         @"com.jriver.MediaCenter20",
         @"co.rackit.mate",
         @"com.ttitt.b-music",
         @"com.beardedspice.BeardedSpice",
         @"com.plug.Plug",
         @"com.netease.163music",
         @"net.sai9.MediaKeys", // https://github.com/jesboat/TUPMediaKeyEventMonitor/commit/662cb3a0637f3ac6f9f46430bcb40673a0fcb5bd
         @"com.alexcrichton.Hermes", // https://github.com/winny-/TUPMediaKeyEventMonitor/commit/3b9f97c15b5d5a2fa3a32c70091acc3bb2838087
         @"com.rdio.desktop", // https://github.com/msfeldstein/TUPMediaKeyEventMonitor/commit/cb6d858d521a11383561e97e06f4d0f69c3536e6
         nil
         ];
    });

	return knownMediaKeyMonitoringAppsBundleIdentifiers;
}

@end

#pragma mark - TUPMediaKeyEventMonitorThread

@implementation TUPMediaKeyEventMonitorThread {
    CFMachPortRef eventPort;

    BOOL (^mediaKeyHandler)(NSEvent*);
}

- (instancetype)initWithMediaKeyEventHandler:(BOOL (^)(NSEvent *))handler
{
    self = [super init];
    if (self) {
        mediaKeyHandler = [handler copy];
    }
    return self;
}

- (void)main {
    // Add an event tap to intercept the system defined media key events
	eventPort = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 CGEventMaskBit(NX_SYSDEFINED),
                                 tapEventCallback,
                                 (__bridge void *)self);
	NSAssert(eventPort != NULL, @"Creating an event port should succeed.");

    CFRunLoopSourceRef eventPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, eventPort, 0);
	NSAssert(eventPortSource != NULL, @"Creating an event port source should succeed.");

    CFRunLoopRef tapThreadRunLoop = CFRunLoopGetCurrent();
	CFRunLoopAddSource(tapThreadRunLoop, eventPortSource, kCFRunLoopCommonModes);

    while (![self isCancelled]) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, true);
    }

    CFRelease(eventPortSource);

    CFMachPortInvalidate(eventPort);
    CFRelease(eventPort);
}

static CGEventRef tapEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo)
{
    @autoreleasepool {
        TUPMediaKeyEventMonitorThread *self = (__bridge id)(userInfo);

        if ([self isCancelled]) {
            return event;
        } // else

        if (type == kCGEventTapDisabledByTimeout) {
#ifdef DEBUG
            NSLog(@"Event tap was disabled by timeout");
#endif
            CGEventTapEnable(self->eventPort, TRUE);
            return event;
        } // else

        NSEvent* nsEvent = nil;
        @try {
            nsEvent = [NSEvent eventWithCGEvent:event];
        }
        @catch (NSException *exception) {
#ifdef DEBUG
            NSLog(@"Unexpected CGEventType: %d: %@", type, exception);
            assert(0);
#endif
            return event;
        }

        return self->mediaKeyHandler(nsEvent) ? NULL : event;
    }
}

@end
