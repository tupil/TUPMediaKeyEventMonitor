/*
 * Author: Eelco Lempsink <eml@tupil.com>
 *
 * Inspired by SPMediaKeyTap https://github.com/nevyn/SPMediaKeyTap
 *
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

// TODO: Cocoapod
// TODO: Drop-in replacement code?

@import Cocoa;
@import IOKit.hidsystem;

/*! The media key codes.  Not all keys are available on all keyboards. */
typedef NS_ENUM(NSInteger, TUPMediaKeyCode)
{
    /// Play key
    TUPMediaKeyPlay     = NX_KEYTYPE_PLAY,
    /// Next key
    TUPMediaKeyNext     = NX_KEYTYPE_NEXT,
    /// Previous key
    TUPMediaKeyPrevious = NX_KEYTYPE_PREVIOUS,
    /// Fast-forward key
    TUPMediaKeyFast     = NX_KEYTYPE_FAST,
    /// Rewind key
    TUPMediaKeyRewind   = NX_KEYTYPE_REWIND
};

@protocol TUPMediaKeyEventMonitorDelegate;

/*! @class TUPMediaKeyEventMonitor
 
    @discussion The \c TUPMediaKeyEventMonitor can monitor keypresses to the media keys even if the
    application is not frontmost.  It will prevent conflicts with other applications
    implementing media key monitoring by only calling the \c TUPMediaKeyEventMonitorDelegate
    if this application was the most recent media key receiving application.
 */
@interface TUPMediaKeyEventMonitor : NSObject

@property (weak) id<TUPMediaKeyEventMonitorDelegate> delegate;

/*! Start monitoring all system events for media key presses.
 
    If a media key is pressed and this application was the last active application known to 
    handle media key presses, a call to \f mediaKeyEventMonitor:keyPressWithCode:repeat: 
    delegate method will be made.
 */
- (void)startMonitoring;

/*! Stop monitoring all system events for media key presses. */
- (void)stopMonitoring;

/*! Handle media keys directly from local events.
 
    If the monitor is active, calls to this method will be ignored.
 
    If the event does not contain a media key press it will do nothing.
 
    @param event The event might contain a media key press.
 */
- (void)handleLocalMediaKeyEvent:(NSEvent*)event;
@end

/*! @protocol TUPMediaKeyEventMonitorDelegate
    
    Implement the \c TUPMediaKeyEventMonitorDelegate protocol to receive media key presses.
 */
@protocol TUPMediaKeyEventMonitorDelegate <NSObject>

/*! Called when a media key is pressed and the application should handle it
  
    @param monitor The \c TUPMediaKeyEventMonitor that monitored the key event.
    @param code    The key code of the pressed key.
    @param repeat  YES if the key is held down and repeats.
 */
- (void)mediaKeyEventMonitor:(TUPMediaKeyEventMonitor*)monitor keyPressWithCode:(TUPMediaKeyCode)code repeat:(BOOL)repeat;

@end
