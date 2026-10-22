//
//  TestDriver.m
//  NetHack UI tests
//
//  Linked only into NetHackUITest.app. Runs the script in NETHACK_TEST_SCRIPT
//  against the running app: it sends key and mouse events through AppKit the
//  way a player's would, waits until the game is waiting for input, and
//  checks what the windows show. Results are printed to stdout in TAP form.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <objc/message.h>

#import "MainWindowController.h"
#import "MainView.h"
#import "NhWindow.h"
#import "NhMapWindow.h"
#import "NhStatus.h"
#import "NhItem.h"
#import "NhTextStyle.h"
#import "NhEventQueue.h"
#import "NetHackCocoaAppDelegate.h"
#import "TileSet.h"

#include "hack.h"

static const NSTimeInterval kIdleTimeout = 20.0;
static const NSTimeInterval kExitTimeout = 20.0;

@interface TestDriver : NSObject
- (instancetype)initWithScript:(NSString *)script;
- (void)run;
@end

static id OnMain(id (^block)(void))
{
	if ( NSThread.isMainThread )
		return block();
	__block id result = nil;
	dispatch_sync(dispatch_get_main_queue(), ^{ result = block(); });
	return result;
}

static void PrepareGameDirectory(NSDictionary<NSString *, NSString *> * env)
{
	NSString * name = env[@"NETHACK_TEST_DIR"] ?: @"default";
	NSString * dir = [[NSHomeDirectory() stringByAppendingPathComponent:@"uitest"] stringByAppendingPathComponent:name];
	NSFileManager * files = NSFileManager.defaultManager;
	if ( [env[@"NETHACK_TEST_FRESH"] isEqualToString:@"1"] )
		[files removeItemAtPath:dir error:NULL];
	[files createDirectoryAtPath:[dir stringByAppendingPathComponent:@"save"] withIntermediateDirectories:YES attributes:nil error:NULL];
	for ( NSString * file in @[ @"perm", @"record", @"logfile", @"xlogfile", @"livelog" ] ) {
		NSString * path = [dir stringByAppendingPathComponent:file];
		if ( ![files fileExistsAtPath:path] )
			[files createFileAtPath:path contents:nil attributes:nil];
	}
	// the test app has its own container, so this is never a player's own file
	NSString * rc = [NSHomeDirectory() stringByAppendingPathComponent:@".nethackrc"];
	[files removeItemAtPath:rc error:NULL];
	if ( env[@"NETHACK_TEST_CONFIG"].length )
		[env[@"NETHACK_TEST_CONFIG"] writeToFile:rc atomically:NO encoding:NSUTF8StringEncoding error:NULL];
	setenv("NETHACKDIR", dir.fileSystemRepresentation, 1);
	setenv("HACKDIR", dir.fileSystemRepresentation, 1);
}

#pragma mark Reading the screen

static NSString * AttributedText(id s)
{
	return [s isKindOfClass:NSAttributedString.class] ? [s string] : [s description];
}

static NSString * GlyphName(int glyph)
{
	if ( glyph == kNoGlyph || glyph_is_unexplored(glyph) || glyph_is_nothing(glyph) )
		return @"";
	if ( glyph_is_invisible(glyph) )
		return @"remembered unseen creature";
	if ( glyph_is_monster(glyph) )
		return @(pmname(&mons[glyph_to_mon(glyph)], NEUTRAL));
	if ( glyph_is_object(glyph) )
		return @(OBJ_NAME(objects[glyph_to_obj(glyph)]));
	if ( glyph_is_cmap(glyph) )
		return @(defsyms[glyph_to_cmap(glyph)].explanation);
	if ( glyph_is_warning(glyph) )
		return @"warning";
	return @"other";
}

static NSString * MarksText(MapMarks marks)
{
	NSMutableArray * names = [NSMutableArray array];
	if ( marks & MapMarkPet ) [names addObject:@"pet"];
	if ( marks & MapMarkPile ) [names addObject:@"pile"];
	if ( marks & MapMarkPeaceful ) [names addObject:@"peaceful"];
	if ( marks & MapMarkRidden ) [names addObject:@"ridden"];
	if ( marks & MapMarkDetected ) [names addObject:@"detected"];
	return [names componentsJoinedByString:@" "];
}

static BOOL SameColor(NSColor * a, NSColor * b)
{
	NSColor * ca = [a colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	NSColor * cb = [b colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	return ca && cb && fabs(ca.redComponent - cb.redComponent) < 0.01 && fabs(ca.greenComponent - cb.greenComponent) < 0.01
		&& fabs(ca.blueComponent - cb.blueComponent) < 0.01 && fabs(ca.alphaComponent - cb.alphaComponent) < 0.01;
}

static NSString * ColorName(NSColor * color, NSAppearance * appearance)
{
	static const struct { int clr; const char * name; } colors[] = {
		{ NO_COLOR, "default" }, { CLR_BLACK, "black" }, { CLR_RED, "red" }, { CLR_GREEN, "green" },
		{ CLR_BROWN, "brown" }, { CLR_BLUE, "blue" }, { CLR_MAGENTA, "magenta" }, { CLR_CYAN, "cyan" },
		{ CLR_ORANGE, "orange" }, { CLR_BRIGHT_GREEN, "bright-green" }, { CLR_YELLOW, "yellow" },
		{ CLR_BRIGHT_BLUE, "bright-blue" }, { CLR_BRIGHT_MAGENTA, "bright-magenta" }, { CLR_BRIGHT_CYAN, "bright-cyan" },
	};
	__block NSString * name = nil;
	[appearance performAsCurrentDrawingAppearance:^{
		for ( int i = 0; i < SIZE(colors) && !name; ++i ) {
			if ( SameColor(color, NhTextColor(colors[i].clr)) )
				name = @(colors[i].name);
		}
		if ( !name && SameColor(color, NSColor.secondaryLabelColor) )
			name = @"secondary";
	}];
	return name ?: @"other";
}

// the last character is in the item's text, after any picture and letter
static NSString * StyleText(NSAttributedString * s, NSAppearance * appearance)
{
	if ( s.length == 0 )
		return @"";
	NSDictionary * attributes = [s attributesAtIndex:s.length - 1 effectiveRange:NULL];
	NSMutableArray * style = [NSMutableArray array];
	NSColor * color = attributes[NSForegroundColorAttributeName] ?: NSColor.labelColor;
	[style addObject:ColorName(color, appearance)];
	NSFont * font = attributes[NSFontAttributeName];
	NSFontTraitMask traits = font ? [NSFontManager.sharedFontManager traitsOfFont:font] : 0;
	if ( traits & NSBoldFontMask ) [style addObject:@"bold"];
	if ( traits & NSItalicFontMask ) [style addObject:@"italic"];
	if ( [attributes[NSUnderlineStyleAttributeName] integerValue] ) [style addObject:@"underline"];
	if ( attributes[NSBackgroundColorAttributeName] ) [style addObject:@"background"];
	return [style componentsJoinedByString:@" "];
}

static void CollectText(NSView * view, NSMutableArray * out)
{
	if ( view.hidden )
		return;
	if ( [view isKindOfClass:NSTableView.class] ) {
		NSTableView * table = (NSTableView *) view;
		for ( NSInteger r = 0; r < table.numberOfRows; ++r ) {
			for ( NSInteger c = 0; c < table.numberOfColumns; ++c ) {
				NSView * cell = [table viewAtColumn:c row:r makeIfNecessary:YES];
				if ( cell ) {
					CollectText(cell, out);
				} else if ( [table.dataSource respondsToSelector:@selector(tableView:objectValueForTableColumn:row:)] ) {
					id value = [table.dataSource tableView:table objectValueForTableColumn:table.tableColumns[c] row:r];
					if ( value )
						[out addObject:AttributedText(value)];
				}
			}
		}
		return;
	}
	NSString * text = nil;
	if ( [view isKindOfClass:NSTextField.class] )
		text = ((NSTextField *) view).stringValue;
	else if ( [view isKindOfClass:NSButton.class] )
		text = ((NSButton *) view).attributedTitle.string;
	else if ( [view isKindOfClass:NSTextView.class] )
		text = ((NSTextView *) view).string;
	if ( text.length )
		[out addObject:text];
	for ( NSView * sub in view.subviews )
		CollectText(sub, out);
}

// where each tab-separated field of a menu row starts, in the table's coordinates
static NSArray<NSNumber *> * FieldStarts(NSTableView * table, NSInteger r)
{
	NSView * cell = [table viewAtColumn:0 row:r makeIfNecessary:YES];
	[cell layoutSubtreeIfNeeded];
	NSTextField * label = nil;
	for ( NSView * sub in cell.subviews ) {
		if ( [sub isKindOfClass:NSTextField.class] )
			label = (NSTextField *) sub;
	}
	if ( !label )
		return @[];
	NSTextStorage * storage = [[NSTextStorage alloc] initWithAttributedString:label.attributedStringValue];
	NSLayoutManager * layout = [[NSLayoutManager alloc] init];
	NSTextContainer * container = [[NSTextContainer alloc] initWithSize:NSMakeSize(1e6, 1e6)];
	[layout addTextContainer:container];
	[storage addLayoutManager:layout];
	CGFloat origin = [cell convertPoint:label.frame.origin toView:table].x;
	NSString * text = storage.string;
	NSMutableArray * starts = [NSMutableArray array];
	for ( NSUInteger i = 0; i < text.length; ++i ) {
		if ( [text characterAtIndex:i] == '\t' || (i > 0 && [text characterAtIndex:i-1] != '\t') )
			continue;
		NSUInteger glyph = [layout glyphIndexForCharacterAtIndex:i];
		NSRect box = [layout boundingRectForGlyphRange:NSMakeRange(glyph, 1) inTextContainer:container];
		[starts addObject:@(origin + box.origin.x)];
	}
	return starts;
}

static void SaveWindowImage(NSWindow * window, NSString * path);

#pragma mark Driver

@implementation TestDriver
{
	NSArray<NSString *> *	lines;
	NSUInteger				lineNumber;
	NSUInteger				testNumber;
	NSUInteger				failures;
	NSUInteger				messageMark;
	BOOL					sentinelSeen;
	id						sentinelMonitor;
	BOOL					timing;
	CFAbsoluteTime			sentinelTime, waitingTime, segmentStart;
	double					lineTimes[4], totals[5];	// delivery, game, screen, driver; checks
}

static CFAbsoluteTime s_loadTime, s_launchTime;

+ (void)load
{
	NSDictionary * env = NSProcessInfo.processInfo.environment;
	NSString * script = env[@"NETHACK_TEST_SCRIPT"];
	if ( !script )
		return;
	s_loadTime = CFAbsoluteTimeGetCurrent();
	PrepareGameDirectory(env);
	// a relaunch keeps the settings, as the app does from one launch to the next
	if ( [env[@"NETHACK_TEST_FRESH"] isEqualToString:@"1"] )
		[NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
	// no check looks at window animations, and they slow dialogs down (sheets still animate)
	[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"NSAutomaticWindowAnimationsEnabled"];
	__block id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification * note) {
		[NSNotificationCenter.defaultCenter removeObserver:observer];
		s_launchTime = CFAbsoluteTimeGetCurrent();
		TestDriver * driver = [[TestDriver alloc] initWithScript:script];
		[NSThread detachNewThreadSelector:@selector(run) toTarget:driver withObject:nil];
	}];
}

- (instancetype)initWithScript:(NSString *)script
{
	if ( self = [super init] ) {
		lines = [script componentsSeparatedByString:@"\n"];
		timing = getenv("UITEST_TIMING") != NULL;
		__weak TestDriver * weakSelf = self;
		sentinelMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskApplicationDefined handler:^NSEvent *(NSEvent * event) {
			if ( event.subtype == 0x4E48 ) {
				TestDriver * strongSelf = weakSelf;
				@synchronized ( strongSelf ) {
					strongSelf->sentinelSeen = YES;
					strongSelf->sentinelTime = CFAbsoluteTimeGetCurrent();
				}
				return nil;
			}
			return event;
		}];
	}
	return self;
}

- (void)say:(NSString *)text
{
	printf("%s\n", text.UTF8String);
	fflush(stdout);
}

- (void)result:(BOOL)ok description:(NSString *)description detail:(NSString *)detail
{
	++testNumber;
	if ( !ok )
		++failures;
	[self say:[NSString stringWithFormat:@"%@ %lu - line %lu: %@%@", ok ? @"ok" : @"not ok", (unsigned long)testNumber,
			   (unsigned long)lineNumber, description, detail.length ? [@" # " stringByAppendingString:detail] : @""]];
}

- (void)finish
{
	if ( timing )
		[self say:[NSString stringWithFormat:@"# timing steps: delivery %.3f, game %.3f, screen %.3f, driver %.3f; checks %.3f; total %.3f since launch",
				   totals[0], totals[1], totals[2], totals[3], totals[4], CFAbsoluteTimeGetCurrent() - s_loadTime]];
	[self say:[NSString stringWithFormat:@"1..%lu", (unsigned long)testNumber]];
	_exit(failures ? 1 : 0);
}

- (void)bailOut:(NSString *)reason
{
	[self result:NO description:reason detail:nil];
	[self recordFailure];
	[self say:[NSString stringWithFormat:@"Bail out! line %lu: %@", (unsigned long)lineNumber, reason]];
	[self finish];
}

- (void)recordFailure
{
	static BOOL recorded = NO;
	if ( recorded )
		return;
	recorded = YES;
	NSArray * messages = [[NhWindow messageWindow] messages];
	NSUInteger from = messages.count > 10 ? messages.count - 10 : 0;
	for ( NSUInteger i = from; i < messages.count; ++i )
		[self say:[@"# message: " stringByAppendingString:AttributedText(messages[i])]];
	// the main thread may be the thing that is stuck, so don't wait on it for long
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_main_queue(), ^{
		if ( self.controller.window ) {
			[self say:[NSString stringWithFormat:@"# dialog = %@", [[self mainStateFor:@"dialog"] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]]];
			NSString * dir = @(getenv("NETHACKDIR"));
			SaveWindowImage(self.controller.window, [dir stringByAppendingPathComponent:@"failure.png"]);
			NSWindow * dialog = [self dialogWindow];
			if ( dialog )
				SaveWindowImage(dialog, [dir stringByAppendingPathComponent:@"failure-dialog.png"]);
		}
		dispatch_semaphore_signal(done);
	});
	dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
}

#pragma mark Waiting

- (void)mainThreadNoop
{
}

// waiting on the player, with everything it asked the main thread to show already shown
- (BOOL)waitForIdle
{
	NSDate * deadline = [NSDate dateWithTimeIntervalSinceNow:kIdleTimeout];
	for (;;) {
		if ( ![(NetHackCocoaAppDelegate *)NSApp.delegate netHackThreadRunning] )
			return YES;
		if ( [[NhEventQueue instance] gameIsWaiting] ) {
			waitingTime = CFAbsoluteTimeGetCurrent();
			// the game sends screen updates this way, so this runs after the ones it sent before waiting
			[self performSelectorOnMainThread:@selector(mainThreadNoop) withObject:nil waitUntilDone:YES];
			if ( [[NhEventQueue instance] gameIsWaiting] )
				return YES;
		}
		if ( [deadline timeIntervalSinceNow] < 0 )
			return NO;
		usleep(1000);
	}
}

- (void)waitForGameStart
{
	NSDate * deadline = [NSDate dateWithTimeIntervalSinceNow:60];
	CFAbsoluteTime started = 0;
	while ( !program_state.in_moveloop || ![self waitForIdle] ) {
		if ( !started && program_state.in_moveloop )
			started = CFAbsoluteTimeGetCurrent();
		if ( [deadline timeIntervalSinceNow] < 0 )
			[self bailOut:@"the game did not start"];
		usleep(1000);
	}
	CFAbsoluteTime ready = CFAbsoluteTimeGetCurrent();
	if ( !started )
		started = ready;
	// clicks on an inactive window only activate it, and a locked screen can't be activated
	NSDate * focusDeadline = [NSDate dateWithTimeIntervalSinceNow:10];
	while ( ![OnMain(^id{
		[NSApp activateIgnoringOtherApps:YES];
		[[MainWindowController instance].window makeKeyAndOrderFront:nil];
		return @(NSApp.active);
	}) boolValue] ) {
		if ( [focusDeadline timeIntervalSinceNow] < 0 )
			[self bailOut:@"the app could not take the focus (is the screen locked?)"];
		usleep(200000);
	}
	[self waitForIdle];
	if ( timing )
		[self say:[NSString stringWithFormat:@"# timing start: app launch %.3f, game until play %.3f, first input %.3f, focus %.3f",
				   s_launchTime - s_loadTime, started - s_launchTime, ready - started, CFAbsoluteTimeGetCurrent() - ready]];
	segmentStart = CFAbsoluteTimeGetCurrent();
}

// some questions come before play starts, e.g. what to do with the game a crash left behind
- (void)answerBeforeStart:(NSString *)keys
{
	NSDate * deadline = [NSDate dateWithTimeIntervalSinceNow:60];
	while ( ![self waitForIdle] || !OnMain(^id{ return [self dialogWindow]; }) ) {
		if ( [deadline timeIntervalSinceNow] < 0 )
			[self bailOut:@"the game asked nothing before it started"];
		usleep(1000);
	}
	OnMain(^id{
		[NSApp activateIgnoringOtherApps:YES];
		return nil;
	});
	[self typeText:keys];
}

// events reach the app in order, so once this one arrives the earlier ones have
- (void)waitForPostedEvents
{
	@synchronized ( self ) {
		sentinelSeen = NO;
	}
	OnMain(^id{
		NSEvent * sentinel = [NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0
											   timestamp:0 windowNumber:0 context:nil subtype:0x4E48 data1:0 data2:0];
		[NSApp postEvent:sentinel atStart:NO];
		return nil;
	});
	NSDate * deadline = [NSDate dateWithTimeIntervalSinceNow:kIdleTimeout];
	for (;;) {
		@synchronized ( self ) {
			if ( sentinelSeen )
				return;
		}
		if ( [deadline timeIntervalSinceNow] < 0 )
			[self bailOut:@"the app stopped taking events"];
		usleep(1000);
	}
}

- (void)afterAction
{
	[self waitForPostedEvents];
	CFAbsoluteTime delivered;
	@synchronized ( self ) {
		delivered = sentinelTime;
	}
	waitingTime = 0;
	if ( ![self waitForIdle] )
		[self bailOut:@"the game did not come back for input"];
	CFAbsoluteTime done = CFAbsoluteTimeGetCurrent();
	if ( !waitingTime )
		waitingTime = done;
	// game: until it waits again, or until it was seen waiting if it never stopped
	double parts[3] = { delivered - segmentStart, MAX(0, waitingTime - delivered), done - MAX(waitingTime, delivered) };
	for ( int i = 0; i < 3; ++i ) {
		lineTimes[i] += parts[i];
		totals[i] += parts[i];
	}
	segmentStart = done;
}

#pragma mark Sending events

- (NSWindow *)eventWindow
{
	NSWindow * main = [MainWindowController instance].window;
	return NSApp.modalWindow ?: main.attachedSheet ?: NSApp.keyWindow ?: main;
}

- (void)pressKey:(NSString *)characters ignoring:(NSString *)ignoring modifiers:(NSEventModifierFlags)modifiers code:(unsigned short)code
{
	OnMain(^id{
		if ( !NSApp.active )
			[NSApp activateIgnoringOtherApps:YES];
		NSInteger window = [self eventWindow].windowNumber;
		for ( NSNumber * type in @[ @(NSEventTypeKeyDown), @(NSEventTypeKeyUp) ] ) {
			NSEvent * e = [NSEvent keyEventWithType:type.unsignedIntegerValue location:NSZeroPoint modifierFlags:modifiers
										  timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window context:nil
										 characters:characters charactersIgnoringModifiers:ignoring isARepeat:NO keyCode:code];
			[NSApp postEvent:e atStart:NO];
		}
		return nil;
	});
}

static unsigned short KeyCodeFor(unichar c)
{
	static const char * keys = "asdfhgzxcv?bqweryt123465=97-80]ou[ip?lj'k;\\,/nm.";
	unichar lower = c < 128 ? tolower(c) : c;
	const char * at = lower < 128 ? strchr(keys, lower) : NULL;
	if ( at && *at != '?' )
		return (unsigned short)(at - keys);
	return c == ' ' ? kVK_Space : 0xFF;
}

// one key at a time, letting the app catch up as a person typing would
- (void)typeText:(NSString *)text
{
	for ( NSUInteger i = 0; i < text.length; ++i ) {
		if ( i > 0 )
			[self afterAction];
		NSString * c = [text substringWithRange:NSMakeRange(i, 1)];
		unichar ch = [c characterAtIndex:0];
		NSEventModifierFlags mods = ch < 128 && (isupper(ch) || strchr("~!@#$%^&*()_+{}|:\"<>?", ch)) ? NSEventModifierFlagShift : 0;
		[self pressKey:c ignoring:c modifiers:mods code:KeyCodeFor(ch)];
	}
}

// a whole line into the text box that has the focus, then Return: the game only sees the line
- (void)enterText:(NSString *)text
{
	BOOL typing = [OnMain(^id{
		return @([[self eventWindow].firstResponder isKindOfClass:NSText.class]);
	}) boolValue];
	if ( !typing )
		[self bailOut:@"no text box has the focus"];
	for ( NSUInteger i = 0; i < text.length; ++i ) {
		NSString * c = [text substringWithRange:NSMakeRange(i, 1)];
		unichar ch = [c characterAtIndex:0];
		[self pressKey:c ignoring:c modifiers:ch < 128 && isupper(ch) ? NSEventModifierFlagShift : 0 code:KeyCodeFor(ch)];
	}
	[self pressNamedKey:@"return"];
}

- (BOOL)pressNamedKey:(NSString *)name
{
	if ( [name isEqualToString:@"return"] )
		[self pressKey:@"\r" ignoring:@"\r" modifiers:0 code:kVK_Return];
	else if ( [name isEqualToString:@"escape"] )
		[self pressKey:@"\033" ignoring:@"\033" modifiers:0 code:kVK_Escape];
	else if ( [name isEqualToString:@"space"] )
		[self pressKey:@" " ignoring:@" " modifiers:0 code:kVK_Space];
	else if ( [name hasPrefix:@"ctrl-"] && name.length == 6 ) {
		unichar c = [name characterAtIndex:5];
		[self pressKey:[NSString stringWithFormat:@"%C", (unichar)(toupper(c) - 'A' + 1)] ignoring:[name substringFromIndex:5]
			 modifiers:NSEventModifierFlagControl code:KeyCodeFor(c)];
	} else
		return NO;
	return YES;
}

- (void)clickInView:(NSView *)view at:(NSPoint)point
{
	NSWindow * window = view.window;
	NSPoint inWindow = [view convertPoint:point toView:nil];
	for ( NSNumber * type in @[ @(NSEventTypeLeftMouseDown), @(NSEventTypeLeftMouseUp) ] ) {
		NSEvent * e = [NSEvent mouseEventWithType:type.unsignedIntegerValue location:inWindow modifierFlags:0
										timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber
										  context:nil eventNumber:0 clickCount:1 pressure:type.unsignedIntegerValue == NSEventTypeLeftMouseDown];
		[NSApp postEvent:e atStart:NO];
	}
}

// as narrow as the window can be, so a test of widening it doesn't depend on the screen's size
- (void)narrowWindow
{
	OnMain(^id{
		NSWindow * window = self.controller.window;
		NSRect frame = window.frame;
		frame.size.width = [window frameRectForContentRect:NSMakeRect(0, 0, window.contentMinSize.width, 1)].size.width;
		[window setFrame:frame display:YES];
		[window layoutIfNeeded];
		return nil;
	});
}

// drags the sidebar's left edge dx points to the right, a few steps at a time as a hand would
- (void)dragSidebarEdge:(CGFloat)dx
{
	OnMain(^id{
		NSView * inventory = [self ivar:@"inventoryView" of:self.controller];
		NSWindow * window = inventory.window;
		[window layoutIfNeeded];
		NSPoint start = [inventory convertPoint:NSMakePoint(2, NSMidY(inventory.bounds)) toView:nil];
		NSMutableArray * events = [NSMutableArray array];
		[events addObject:@[ @(NSEventTypeLeftMouseDown), @0 ]];
		for ( int i = 1; i <= 4; ++i )
			[events addObject:@[ @(NSEventTypeLeftMouseDragged), @(dx * i / 4) ]];
		[events addObject:@[ @(NSEventTypeLeftMouseUp), @(dx) ]];
		for ( NSArray * step in events ) {
			NSEventType type = [step[0] unsignedIntegerValue];
			NSEvent * e = [NSEvent mouseEventWithType:type location:NSMakePoint(start.x + [step[1] doubleValue], start.y) modifierFlags:0
											timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber
											  context:nil eventNumber:0 clickCount:1 pressure:type == NSEventTypeLeftMouseUp ? 0 : 1];
			[NSApp postEvent:e atStart:NO];
		}
		return nil;
	});
}

#pragma mark Game state

- (NSPoint)hero
{
	return NSMakePoint(u.ux, u.uy);
}

- (MainWindowController *)controller
{
	return [MainWindowController instance];
}

- (id)ivar:(NSString *)name of:(id)object
{
	return [object valueForKey:name];
}

- (NSWindow *)dialogWindow
{
	NSWindow * main = self.controller.window;
	NSWindow * w = NSApp.modalWindow ?: main.attachedSheet;
	if ( w )
		return w;
	for ( NSWindow * other in NSApp.orderedWindows ) {
		if ( other != main && other.visible && other.windowController )
			return other;
	}
	return nil;
}

- (id)openMenuController
{
	id controller = [self dialogWindow].windowController;
	return [controller isKindOfClass:NSClassFromString(@"MenuWindowController")] ? controller : nil;
}

static int DirectionIndex(int dx, int dy)
{
	for ( int i = 0; i < N_DIRS; ++i ) {
		if ( xdir[i] == dx && ydir[i] == dy )
			return i;
	}
	return -1;
}

- (NSArray<NSValue *> *)cellsNamed:(NSString *)name
{
	NhMapWindow * map = (NhMapWindow *) [NhWindow mapWindow];
	NSMutableArray * cells = [NSMutableArray array];
	for ( int y = 0; y < ROWNO; ++y ) {
		for ( int x = 1; x < COLNO; ++x ) {
			if ( [GlyphName([map glyphAtX:x y:y]) isEqualToString:name] )
				[cells addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
		}
	}
	return cells;
}

static NSDictionary<NSString *, NSString *> * StatusFieldIvars(void)
{
	return @{ @"name" : @"name", @"role" : @"role", @"dlvl" : @"dlvl", @"hp" : @"hp", @"pw" : @"pw",
			  @"level" : @"level", @"xplabel" : @"xpLabel", @"xp" : @"xp", @"ac" : @"ac", @"gold" : @"gold",
			  @"str" : @"str", @"dex" : @"dex", @"con" : @"con", @"int" : @"iq", @"wis" : @"wis", @"cha" : @"cha",
			  @"turn" : @"turn" };
}

static NSDictionary<NSString *, NSNumber *> * StatusMarkFields(void)
{
	return @{ @"str" : @(BL_STR), @"dex" : @(BL_DX), @"con" : @(BL_CO), @"int" : @(BL_IN), @"wis" : @(BL_WI),
			  @"cha" : @(BL_CH), @"ac" : @(BL_AC), @"level" : @(BL_XP), @"hd" : @(BL_HD) };
}

static NSArray<NSString *> * WearingSlots(void)
{
	return @[ @"amulet", @"helmet", @"blindfold", @"weapon", @"armor", @"shield",
			  @"gloves", @"shirt", @"cloak", @"left-ring", @"boots", @"right-ring" ];
}

- (NSString *)stateFor:(NSString *)key
{
	if ( [key hasPrefix:@"map."] )
		return [self mapStateFor:[key substringFromIndex:4]];
	if ( [key isEqualToString:@"game.input"] ) {
		switch ( program_state.input_state ) {
			case commandInp:	return @"command";
			case getposInp:		return @"position";
			default:			return @"other";
		}
	}
	if ( [key isEqualToString:@"messages"] || [key isEqualToString:@"messages.new"] ) {
		NSArray * messages = [[NhWindow messageWindow] messages] ?: @[];
		NSUInteger from = [key isEqualToString:@"messages"] ? 0 : MIN(messageMark, messages.count);
		NSMutableArray * texts = [NSMutableArray array];
		for ( NSUInteger i = from; i < messages.count; ++i )
			[texts addObject:AttributedText(messages[i])];
		return [texts componentsJoinedByString:@"\n"];
	}
	return OnMain(^id{ return [self mainStateFor:key]; });
}

- (NSString *)mapStateFor:(NSString *)key
{
	NhMapWindow * map = (NhMapWindow *) [NhWindow mapWindow];
	MainView * mainView = [self ivar:@"mainView" of:self.controller];
	NSPoint hero = self.hero;
	if ( [key isEqualToString:@"cursor"] ) {
		int x, y;
		[map cursX:&x y:&y];
		return [NSString stringWithFormat:@"%d,%d", x - (int)hero.x, y - (int)hero.y];
	}
	if ( [key hasPrefix:@"with."] ) {
		NSString * wanted = [key substringFromIndex:5];
		return OnMain(^id{
			NSMutableArray * names = [NSMutableArray array];
			for ( int y = 0; y < ROWNO; ++y ) {
				for ( int x = 1; x < COLNO; ++x ) {
					if ( [[MarksText([mainView marksAtX:x y:y]) componentsSeparatedByString:@" "] containsObject:wanted] )
						[names addObject:GlyphName([map glyphAtX:x y:y])];
				}
			}
			return [names componentsJoinedByString:@"|"];
		});
	}
	if ( [key hasPrefix:@"count."] )
		return [NSString stringWithFormat:@"%lu", (unsigned long)[self cellsNamed:[key substringFromIndex:6]].count];
	if ( [key hasPrefix:@"find."] ) {
		NSArray * cells = [self cellsNamed:[key substringFromIndex:5]];
		return OnMain(^id{
			NSMutableArray * marks = [NSMutableArray array];
			for ( NSValue * cell in cells )
				[marks addObject:MarksText([mainView marksAtX:cell.pointValue.x y:cell.pointValue.y])];
			return [marks componentsJoinedByString:@"|"];
		});
	}
	NSArray * parts = [key componentsSeparatedByString:@"."];
	NSArray * offset = [parts[0] componentsSeparatedByString:@","];
	if ( offset.count != 2 )
		return nil;
	int x = (int)hero.x + [offset[0] intValue], y = (int)hero.y + [offset[1] intValue];
	if ( x < 1 || x >= COLNO || y < 0 || y >= ROWNO )
		return @"";
	if ( parts.count == 1 )
		return GlyphName([map glyphAtX:x y:y]);
	if ( [parts[1] isEqualToString:@"marks"] )
		return MarksText([OnMain(^id{ return @([mainView marksAtX:x y:y]); }) unsignedIntegerValue]);
	if ( [parts[1] isEqualToString:@"bg"] )
		return GlyphName([map backgroundGlyphAtX:x y:y]);
	return nil;
}

- (NSString *)mainStateFor:(NSString *)key
{
	MainWindowController * controller = self.controller;
	NSAppearance * appearance = controller.window.effectiveAppearance;
	id statsView = [self ivar:@"statsView" of:controller];

	if ( [key hasPrefix:@"status."] ) {
		NSString * field = [key substringFromIndex:7];
		if ( [field isEqualToString:@"badges"] ) {
			NSStackView * badges = [self ivar:@"badges" of:statsView];
			NSMutableArray * texts = [NSMutableArray array];
			NSArray * severities = @[ @"info", @"caution", @"warning", @"danger" ];
			for ( NSView * view in badges.arrangedSubviews ) {
				NhStatusBadge * badge = [self ivar:@"badge" of:view];
				[texts addObject:[NSString stringWithFormat:@"%@:%@", badge.text, severities[badge.severity]]];
			}
			return [texts componentsJoinedByString:@" "];
		}
		if ( [field isEqualToString:@"marks"] ) {
			NSMutableArray * marks = [NSMutableArray array];
			for ( NSString * name in [StatusMarkFields().allKeys sortedArrayUsingSelector:@selector(compare:)] ) {
				NSString * mark = [self mainStateFor:[@"status.mark." stringByAppendingString:name]];
				if ( mark.length )
					[marks addObject:[NSString stringWithFormat:@"%@:%@", name, mark]];
			}
			return [marks componentsJoinedByString:@" "];
		}
		if ( [field hasPrefix:@"mark."] ) {
			NSNumber * bl = StatusMarkFields()[[field substringFromIndex:5]];
			if ( !bl )
				return nil;
			NSTextField * mark = [[self ivar:@"changeMarks" of:statsView] objectForKey:bl];
			if ( !mark || mark.hidden )
				return @"";
			BOOL better = [mark.textColor isEqual:NSColor.systemGreenColor];
			return [NSString stringWithFormat:@"%@ %@", [mark.stringValue isEqualToString:@"↑"] ? @"up" : @"down", better ? @"better" : @"worse"];
		}
		NSString * ivar = StatusFieldIvars()[field];
		return ivar ? [[self ivar:ivar of:statsView] stringValue] : nil;
	}

	if ( [key isEqualToString:@"dialog"] || [key isEqualToString:@"dialog.kind"] ) {
		NSWindow * w = [self dialogWindow];
		if ( !w )
			return @"none";
		if ( [key isEqualToString:@"dialog.kind"] ) {
			if ( !w.windowController )
				return @"Alert";
			return [NSStringFromClass([w.windowController class]) stringByReplacingOccurrencesOfString:@"WindowController" withString:@""];
		}
		NSMutableArray * texts = [NSMutableArray array];
		if ( w.title.length )
			[texts addObject:w.title];
		CollectText(w.contentView, texts);
		return [texts componentsJoinedByString:@" | "];
	}

	if ( [key hasPrefix:@"menu."] ) {
		id menu = [self openMenuController];
		if ( !menu )
			return @"(no menu)";
		NSArray * rows = [self ivar:@"rows" of:menu];
		NSString * field = [key substringFromIndex:5];
		if ( [field isEqualToString:@"question"] )
			return ((BOOL (*)(id, SEL))objc_msgSend)(menu, NSSelectorFromString(@"isQuestion")) ? @"yes" : @"no";
		if ( [field isEqualToString:@"misaligned"] ) {
			NSTableView * table = [self ivar:@"tableView" of:menu];
			NSMutableArray * itemStarts = [NSMutableArray array];
			for ( NSUInteger r = 0; r < rows.count; ++r ) {
				if ( [rows[r] valueForKey:@"item"] )
					[itemStarts addObjectsFromArray:FieldStarts(table, r)];
			}
			NSMutableArray * misaligned = [NSMutableArray array];
			for ( NSUInteger r = 0; r < rows.count; ++r ) {
				NSArray * fields = [rows[r] valueForKey:@"fields"];
				if ( [rows[r] valueForKey:@"item"] || fields.count < 2 )
					continue;
				NSArray<NSNumber *> * starts = FieldStarts(table, r);
				for ( NSUInteger f = 0; f < starts.count && f < fields.count; ++f ) {
					BOOL matched = NO;
					for ( NSNumber * x in itemStarts )
						matched |= fabs(x.doubleValue - starts[f].doubleValue) < 1;
					if ( !matched )
						[misaligned addObject:fields[f]];
				}
			}
			return [misaligned componentsJoinedByString:@" "];
		}
		if ( [field hasPrefix:@"@"] ) {
			BOOL style = [field hasSuffix:@".style"];
			NSString * wanted = [field substringWithRange:NSMakeRange(1, field.length - 1 - (style ? 6 : 0))];
			for ( id row in rows ) {
				NSString * text = [[row valueForKey:@"fields"] componentsJoinedByString:@" "];
				if ( [row valueForKey:@"item"] && [text containsString:wanted] ) {
					NSAttributedString * shown = ((id (*)(id, SEL, id))objc_msgSend)(menu, NSSelectorFromString(@"stringForRow:"), row);
					return style ? StyleText(shown, appearance) : text;
				}
			}
			return @"(no such row)";
		}
		NSMutableArray * letters = [NSMutableArray array], * headings = [NSMutableArray array], * headingStyles = [NSMutableArray array];
		for ( id row in rows ) {
			NhItem * item = [row valueForKey:@"item"];
			NSString * text = [[row valueForKey:@"fields"] componentsJoinedByString:@" "];
			NSAttributedString * shown = ((id (*)(id, SEL, id))objc_msgSend)(menu, NSSelectorFromString(@"stringForRow:"), row);
			if ( item.inventoryLetter ) {
				NSString * letter = [NSString stringWithFormat:@"%c", item.inventoryLetter];
				[letters addObject:letter];
				if ( [field isEqualToString:letter] )
					return text;
				if ( [field isEqualToString:[letter stringByAppendingString:@".style"]] )
					return StyleText(shown, appearance);
			} else if ( [[row valueForKey:@"heading"] boolValue] ) {
				[headings addObject:text];
				[headingStyles addObject:StyleText(shown, appearance)];
			}
		}
		if ( [field isEqualToString:@"letters"] )
			return [letters componentsJoinedByString:@""];
		if ( [field isEqualToString:@"headings"] )
			return [headings componentsJoinedByString:@"|"];
		if ( [field isEqualToString:@"headings.style"] )
			return [headingStyles componentsJoinedByString:@"|"];
		return @"(no such row)";
	}

	if ( [key isEqualToString:@"window.squeezed"] ) {
		// shrinks the window to its minimum and sees whether the layout still fits, then puts it back
		NSWindow * window = controller.window;
		NSRect frame = window.frame;
		[window setContentSize:window.contentMinSize];
		[window.contentView layoutSubtreeIfNeeded];
		NSView * content = window.contentView;
		CGFloat right = 0;
		for ( NSView * view in content.subviews )
			if ( !view.hidden )
				right = MAX(right, NSMaxX(view.frame));
		BOOL squeezed = right > NSWidth(content.bounds) + 0.5 || NSWidth(content.bounds) > window.contentMinSize.width + 0.5;
		[window setFrame:frame display:YES];
		return squeezed ? @"yes" : @"no";
	}
	if ( [key isEqualToString:@"sidebar.width"] ) {
		[controller.window layoutIfNeeded];
		return [NSString stringWithFormat:@"%g", [[self ivar:@"inventoryView" of:controller] frame].size.width];
	}
	if ( [key hasPrefix:@"sidebar."] ) {
		id inventory = [self ivar:@"inventoryView" of:controller];
		NSTableView * table = [self ivar:@"tableView" of:inventory];
		NSArray * rows = [self ivar:@"rows" of:inventory];
		NSString * field = [key substringFromIndex:8];
		BOOL byText = [field hasPrefix:@"@"], style = [field hasSuffix:@".style"];
		NSString * wanted = byText ? [field substringWithRange:NSMakeRange(1, field.length - 1 - (style ? 6 : 0))] : nil;
		NSMutableArray * letters = [NSMutableArray array], * headings = [NSMutableArray array], * headingStyles = [NSMutableArray array];
		for ( NSUInteger r = 0; r < rows.count; ++r ) {
			if ( [rows[r] isKindOfClass:NhItem.class] ) {
				NhItem * item = rows[r];
				NSString * letter = [NSString stringWithFormat:@"%c", item.inventoryLetter];
				[letters addObject:letter];
				if ( byText ? [item.title containsString:wanted]
					 : ([field isEqualToString:letter] || [field isEqualToString:[letter stringByAppendingString:@".style"]]) ) {
					NSTableCellView * cell = (NSTableCellView *) [(id<NSTableViewDelegate>)inventory tableView:table viewForTableColumn:table.tableColumns[0] row:r];
					NSAttributedString * shown = cell.textField.attributedStringValue;
					return style ? StyleText(shown, appearance) : shown.string;
				}
			} else {
				[headings addObject:AttributedText(rows[r])];
				[headingStyles addObject:StyleText(rows[r], appearance)];
			}
		}
		if ( [field isEqualToString:@"letters"] )
			return [letters componentsJoinedByString:@""];
		if ( [field isEqualToString:@"headings"] )
			return [headings componentsJoinedByString:@"|"];
		if ( [field isEqualToString:@"headings.style"] )
			return [headingStyles componentsJoinedByString:@"|"];
		return @"(no such row)";
	}

	if ( [key hasPrefix:@"wearing."] ) {
		NSUInteger slot = [WearingSlots() indexOfObject:[key substringFromIndex:8]];
		if ( slot == NSNotFound )
			return nil;
		NSArray * tips = [self ivar:@"tips" of:[self ivar:@"equipmentView" of:controller]];
		return slot < tips.count ? tips[slot] : @"";
	}

	if ( [key hasPrefix:@"menubar."] ) {
		NSArray * path = [[key substringFromIndex:8] componentsSeparatedByString:@"/"];
		NSMenu * menu = [NSApp.mainMenu itemWithTitle:path.firstObject].submenu;
		[menu update];
		NSMenuItem * item = [menu itemWithTitle:path.lastObject];
		return item ? (item.enabled ? @"enabled" : @"disabled") : nil;
	}

	if ( [key isEqualToString:@"tileset.size"] ) {
		NSSize size = [TileSet instance].tileSize;
		return [NSString stringWithFormat:@"%gx%g", size.width, size.height];
	}
	if ( [key isEqualToString:@"text.size"] ) {
		NSTableView * log = [self.controller valueForKey:@"messagesView"];
		if ( log.numberOfRows == 0 )
			return @"";
		NSAttributedString * row = [log.dataSource tableView:log objectValueForTableColumn:log.tableColumns[0] row:0];
		NSFont * font = [row attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
		return [NSString stringWithFormat:@"%g", font.pointSize];
	}
	return nil;
}

#pragma mark Commands

- (void)check:(NSString *)rest
{
	static NSArray * ops;
	if ( !ops )
		ops = @[ @"==", @"!=", @"!contains", @"contains", @"matches", @">=", @"<=" ];
	NSArray * words = [rest componentsSeparatedByString:@" "];
	NSUInteger opIndex = NSNotFound;
	for ( NSUInteger i = 1; i < words.count && opIndex == NSNotFound; ++i ) {
		if ( [ops containsObject:words[i]] )
			opIndex = i;
	}
	if ( opIndex == NSNotFound ) {
		[self bailOut:[@"no operator in check: " stringByAppendingString:rest]];
		return;
	}
	NSString * key = [[words subarrayWithRange:NSMakeRange(0, opIndex)] componentsJoinedByString:@" "];
	NSString * op = words[opIndex];
	NSString * expected = [[words subarrayWithRange:NSMakeRange(opIndex + 1, words.count - opIndex - 1)] componentsJoinedByString:@" "];
	if ( [expected isEqualToString:@"\"\""] )
		expected = @"";
	NSString * actual = [self stateFor:key];
	if ( !actual ) {
		[self bailOut:[@"unknown check key " stringByAppendingString:key]];
		return;
	}
	BOOL ok;
	if ( [op isEqualToString:@"=="] )
		ok = [actual isEqualToString:expected];
	else if ( [op isEqualToString:@"!="] )
		ok = ![actual isEqualToString:expected];
	else if ( [op isEqualToString:@"contains"] )
		ok = [actual containsString:expected];
	else if ( [op isEqualToString:@"!contains"] )
		ok = ![actual containsString:expected];
	else if ( [op isEqualToString:@"matches"] )
		ok = [actual rangeOfString:expected options:NSRegularExpressionSearch].location != NSNotFound;
	else if ( [op isEqualToString:@">="] )
		ok = actual.doubleValue >= expected.doubleValue;
	else
		ok = actual.doubleValue <= expected.doubleValue;
	[self result:ok description:[@"check " stringByAppendingString:rest]
		  detail:ok ? nil : [NSString stringWithFormat:@"got '%@'", [actual stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]]];
	if ( !ok )
		[self recordFailure];
}

// a hidden monster or trap on a square that looks empty would stop or divert the hero
static BOOL HidesSomething(NSPoint cell)
{
	int x = cell.x, y = cell.y;
	return !glyph_is_monster(glyph_at(x, y)) && (m_at(x, y) || t_at(x, y));
}

- (void)toward:(NSString *)name
{
	NSPoint hero = self.hero;
	for ( NSValue * cell in [self cellsNamed:name] ) {
		if ( HidesSomething(cell.pointValue) )
			continue;
		int dx = cell.pointValue.x - hero.x, dy = cell.pointValue.y - hero.y;
		int dir = DirectionIndex(dx, dy);
		if ( dir >= 0 && (dx || dy) ) {
			[self typeText:[NSString stringWithFormat:@"%c", gc.Cmd.dirchars[dir]]];
			return;
		}
	}
	[self bailOut:[NSString stringWithFormat:@"no %@ next to the hero", name]];
}

- (void)pick:(NSString *)text
{
	NSString * letter = OnMain(^id{
		id menu = [self openMenuController];
		for ( id row in [self ivar:@"rows" of:menu] ) {
			NhItem * item = [row valueForKey:@"item"];
			if ( item.inventoryLetter && [[[row valueForKey:@"fields"] componentsJoinedByString:@" "] containsString:text] )
				return [NSString stringWithFormat:@"%c", item.inventoryLetter];
		}
		return nil;
	});
	if ( !letter )
		[self bailOut:[NSString stringWithFormat:@"no menu row with '%@'", text]];
	[self typeText:letter];
}

- (void)click:(NSString *)rest
{
	NSArray * words = [rest componentsSeparatedByString:@" "];
	NSString * target = words.firstObject;
	NSPoint hero = self.hero;
	NSPoint cell = NSMakePoint(-1, -1);
	if ( [target isEqualToString:@"map-near"] ) {
		NSString * name = [rest substringFromIndex:target.length + 1];
		for ( NSValue * v in [self cellsNamed:name] ) {
			if ( fabs(v.pointValue.x - hero.x) <= 1 && fabs(v.pointValue.y - hero.y) <= 1 && !HidesSomething(v.pointValue) ) {
				cell = v.pointValue;
				break;
			}
		}
	} else if ( [target isEqualToString:@"map-unexplored"] ) {
		NhMapWindow * map = (NhMapWindow *) [NhWindow mapWindow];
		for ( int d = 4; d < COLNO && cell.x < 0; ++d ) {
			for ( int dx = -d; dx <= d && cell.x < 0; dx += 2 * d ) {
				int x = hero.x + dx, y = hero.y;
				if ( x >= 1 && x < COLNO && GlyphName([map glyphAtX:x y:y]).length == 0 )
					cell = NSMakePoint(x, y);
			}
		}
	}
	if ( [target hasPrefix:@"map-"] ) {
		if ( cell.x < 0 )
			[self bailOut:[@"no map square for " stringByAppendingString:rest]];
		words = @[ @"map", [NSString stringWithFormat:@"%d", (int)(cell.x - hero.x)], [NSString stringWithFormat:@"%d", (int)(cell.y - hero.y)] ];
		target = @"map";
	}
	NSString * error = OnMain(^id{
		MainWindowController * controller = self.controller;
		if ( [target isEqualToString:@"sidebar"] && words.count == 2 ) {
			id inventory = [self ivar:@"inventoryView" of:controller];
			NSTableView * table = [self ivar:@"tableView" of:inventory];
			NSArray * rows = [self ivar:@"rows" of:inventory];
			for ( NSUInteger r = 0; r < rows.count; ++r ) {
				if ( [rows[r] isKindOfClass:NhItem.class] && ((NhItem *)rows[r]).inventoryLetter == [words[1] characterAtIndex:0] ) {
					[table scrollRowToVisible:r];
					NSRect rect = [table rectOfRow:r];
					[self clickInView:table at:NSMakePoint(NSMidX(rect), NSMidY(rect))];
					return nil;
				}
			}
			return @"no such sidebar item";
		}
		if ( [target isEqualToString:@"wearing"] && words.count == 2 ) {
			NSUInteger slot = [WearingSlots() indexOfObject:words[1]];
			if ( slot == NSNotFound )
				return @"no such wearing slot";
			NSView * equipment = [self ivar:@"equipmentView" of:controller];
			NSRect rect = ((NSRect (*)(id, SEL, int))objc_msgSend)(equipment, NSSelectorFromString(@"rectForSlot:"), (int)slot);
			[self clickInView:equipment at:NSMakePoint(NSMidX(rect), NSMidY(rect))];
			return nil;
		}
		if ( [target isEqualToString:@"map"] && words.count == 3 ) {
			MainView * mainView = [self ivar:@"mainView" of:controller];
			NSSize tile = [[self ivar:@"tileSize" of:mainView] sizeValue];
			NSRect rect = NSMakeRect((hero.x + [words[1] intValue]) * tile.width, (hero.y + [words[2] intValue]) * tile.height, tile.width, tile.height);
			[mainView scrollRectToVisible:rect];
			[self clickInView:mainView at:NSMakePoint(NSMidX(rect), NSMidY(rect))];
			return nil;
		}
		return @"unknown click target";
	});
	if ( error )
		[self bailOut:error];
}

- (void)chooseMenuItem:(NSString *)path
{
	NSString * error = OnMain(^id{
		NSArray * parts = [path componentsSeparatedByString:@"/"];
		NSMenu * menu = NSApp.mainMenu;
		NSMenuItem * item = nil;
		for ( NSString * title in parts ) {
			if ( item ) {
				menu = item.submenu;
				// as when it opens, so menus built on demand (Tile Set) are filled in
				if ( [menu.delegate respondsToSelector:@selector(menuWillOpen:)] )
					[menu.delegate menuWillOpen:menu];
				[menu update];
			}
			item = [menu itemWithTitle:title];
			if ( !item )
				return @"no such menu item";
		}
		if ( !item.enabled )
			return @"menu item is disabled";
		[menu performActionForItemAtIndex:[menu indexOfItem:item]];
		return nil;
	});
	if ( error )
		[self bailOut:[NSString stringWithFormat:@"%@: %@", path, error]];
}

static void SaveWindowImage(NSWindow * window, NSString * path)
{
	NSView * view = window.contentView;
	NSBitmapImageRep * rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
	NSData * png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	NSError * error = nil;
	if ( ![png writeToFile:path options:0 error:&error] )
		NSLog(@"snapshot %@: %lu bytes, %@", path, (unsigned long)png.length, error);
}

- (void)snapshot:(NSString *)name
{
	NSString * dir = @(getenv("NETHACKDIR"));
	OnMain(^id{
		SaveWindowImage(self.controller.window, [dir stringByAppendingFormat:@"/%@.png", name]);
		NSWindow * dialog = [self dialogWindow];
		if ( dialog )
			SaveWindowImage(dialog, [dir stringByAppendingFormat:@"/%@-dialog.png", name]);
		return nil;
	});
	[self say:[NSString stringWithFormat:@"# snapshot %@/%@.png", dir, name]];
}

// the message window throws while it holds its lock, as it did for messages ending in "you"
- (void)throwOnMessage:(NSString *)text
{
	SEL sel = NSSelectorFromString(@"stringReferencesHero:");
	Method m = class_getInstanceMethod(NhWindow.class, sel);
	BOOL (*original)(id, SEL, NSString *) = (BOOL (*)(id, SEL, NSString *))method_getImplementation(m);
	method_setImplementation(m, imp_implementationWithBlock(^BOOL(id window, NSString * s) {
		if ( [s containsString:text] )
			[NSException raise:NSRangeException format:@"thrown by the test on \"%@\"", text];
		return original(window, sel, s);
	}));
}

- (void)expectExit
{
	[self waitForPostedEvents];
	NSDate * deadline = [NSDate dateWithTimeIntervalSinceNow:kExitTimeout];
	while ( [deadline timeIntervalSinceNow] > 0 )
		usleep(100000);
	[self bailOut:@"the app did not quit"];
}

- (void)run
{
	@autoreleasepool {
		BOOL started = NO;
		for ( NSString * raw in lines ) {
			++lineNumber;
			NSString * line = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
			if ( line.length == 0 || [line hasPrefix:@"#"] || [line hasPrefix:@"@"] )
				continue;
			NSRange space = [line rangeOfString:@" "];
			NSString * command = space.location == NSNotFound ? line : [line substringToIndex:space.location];
			NSString * rest = space.location == NSNotFound ? @"" : [line substringFromIndex:space.location + 1];

			if ( [command isEqualToString:@"answer"] && !started ) {
				[self answerBeforeStart:rest];
				continue;
			}
			if ( !started ) {
				[self waitForGameStart];
				started = YES;
			}
			if ( [command isEqualToString:@"check"] ) {
				CFAbsoluteTime before = CFAbsoluteTimeGetCurrent();
				[self check:rest];
				totals[4] += CFAbsoluteTimeGetCurrent() - before;
				segmentStart = CFAbsoluteTimeGetCurrent();
				continue;
			}
			if ( [command isEqualToString:@"print"] ) {
				NSString * value = [self stateFor:rest];
				if ( !value )
					[self bailOut:[@"unknown key " stringByAppendingString:rest]];
				[self say:[NSString stringWithFormat:@"# %@ = %@", rest, [value stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]]];
				continue;
			}
			if ( [command isEqualToString:@"snapshot"] ) {
				[self snapshot:rest];
				continue;
			}
			if ( [command isEqualToString:@"pause"] ) {
				usleep((useconds_t)(rest.doubleValue * 1e6));
				continue;
			}
			if ( [command isEqualToString:@"throw-on-message"] ) {
				[self throwOnMessage:rest];
				continue;
			}
			if ( [command isEqualToString:@"die"] ) {
				// as a crash would: no save, and the game's files are left behind
				fflush(stdout);
				_exit(0);
			}
			if ( [command isEqualToString:@"expect-exit"] ) {
				[self expectExit];
				return;
			}

			messageMark = [[NhWindow messageWindow] messageCount];
			CFAbsoluteTime lineStart = CFAbsoluteTimeGetCurrent();
			segmentStart = lineStart;
			memset(lineTimes, 0, sizeof lineTimes);
			if ( [command isEqualToString:@"type"] )
				[self typeText:rest];
			else if ( [command isEqualToString:@"key"] ) {
				for ( NSString * name in [rest componentsSeparatedByString:@" "] ) {
					if ( ![self pressNamedKey:name] )
						[self bailOut:[@"unknown key " stringByAppendingString:name]];
				}
			} else if ( [command isEqualToString:@"enter"] )
				[self enterText:rest];
			else if ( [command isEqualToString:@"pass"] ) {
				// a forced search always takes a turn, even beside a hidden monster
				for ( int i = 0; i < rest.intValue; ++i ) {
					if ( i > 0 )
						[self afterAction];
					[self typeText:@"ms"];
				}
			} else if ( [command isEqualToString:@"pick"] )
				[self pick:rest];
			else if ( [command isEqualToString:@"toward"] )
				[self toward:rest];
			else if ( [command isEqualToString:@"step"] ) {
				// a move that silently fails would otherwise only show up in a later check
				NSPoint from = self.hero;
				[self toward:rest];
				[self afterAction];
				if ( NSEqualPoints(from, self.hero) )
					[self bailOut:[@"the hero did not move toward " stringByAppendingString:rest]];
				continue;
			}
			else if ( [command isEqualToString:@"click"] )
				[self click:rest];
			else if ( [command isEqualToString:@"choose"] )
				[self chooseMenuItem:rest];
			else if ( [command isEqualToString:@"narrow-window"] )
				[self narrowWindow];
			else if ( [command isEqualToString:@"drag"] && [rest hasPrefix:@"sidebar-edge "] )
				[self dragSidebarEdge:[[rest substringFromIndex:13] doubleValue]];
			else
				[self bailOut:[@"unknown command " stringByAppendingString:command]];
			[self afterAction];
			double total = CFAbsoluteTimeGetCurrent() - lineStart;
			double driver = total - lineTimes[0] - lineTimes[1] - lineTimes[2];
			totals[3] += driver;
			if ( timing )
				[self say:[NSString stringWithFormat:@"# timing line %lu %.3f (delivery %.3f, game %.3f, screen %.3f, driver %.3f): %@",
						   (unsigned long)lineNumber, total, lineTimes[0], lineTimes[1], lineTimes[2], driver, line]];
		}
		if ( !started )
			[self waitForGameStart];
		[self finish];
	}
}

@end
