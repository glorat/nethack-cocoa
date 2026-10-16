#import <XCTest/XCTest.h>
#import "YesNoWindowController.h"
#import "YesNoInput.h"
#import "NhYnQuestion.h"
#import "StubEventQueue.h"

@interface YesNoWindowTests : XCTestCase
@end

@implementation YesNoWindowTests

-(void)setUp
{
	[NSApplication sharedApplication];
	[StubEventQueue reset];
}

static NSWindow * Dialog(void)
{
	for ( NSWindow * window in NSApp.windows ) {
		if ( window.isVisible && [window.windowController isKindOfClass:[YesNoWindowController class]] )
			return window;
	}
	return nil;
}

static void PostKey(NSString * chars, NSEventModifierFlags flags)
{
	NSEvent * event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags
									  timestamp:0 windowNumber:Dialog().windowNumber context:nil
									 characters:chars charactersIgnoringModifiers:chars isARepeat:NO keyCode:0];
	[NSApp sendEvent:event];
}

static NSArray<NSButton *> * Buttons(void)
{
	NSMutableArray * buttons = [NSMutableArray array];
	NSMutableArray * views = [NSMutableArray arrayWithObject:Dialog().contentView];
	while ( views.count ) {
		NSView * view = views.lastObject;
		[views removeLastObject];
		if ( [view isKindOfClass:[NSButton class]] )
			[buttons addObject:view];
		[views addObjectsFromArray:view.subviews];
	}
	return buttons;
}

static void Click(NSString * title)
{
	NSMutableArray * views = [NSMutableArray arrayWithObject:Dialog().contentView];
	while ( views.count ) {
		NSView * view = views.lastObject;
		[views removeLastObject];
		if ( [view isKindOfClass:[NSButton class]] && [((NSButton *)view).title isEqualToString:title] ) {
			[(NSButton *)view performClick:nil];
			return;
		}
		[views addObjectsFromArray:view.subviews];
	}
}

static void After(NSTimeInterval delay, void (^block)(void))
{
	NSTimer * timer = [NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer * _) { block(); }];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

// each step is scheduled only after the one before it has run, so a slow
// first window can't make two steps fire together
-(void)ask:(NhYnQuestion *)question steps:(NSArray<void (^)(void)> *)steps
{
	__block NSUInteger next = 0;
	__block void (^runNext)(void) = ^{
		if ( next < steps.count ) {
			steps[next++]();
			After(0.1, runNext);
		}
	};
	After(0.1, runNext);
	__block BOOL timedOut = NO;
	NSTimer * timeout = [NSTimer timerWithTimeInterval:10 repeats:NO block:^(NSTimer * _) {
		timedOut = YES;
		[Dialog() close];
	}];
	[[NSRunLoop mainRunLoop] addTimer:timeout forMode:NSRunLoopCommonModes];
	[YesNoWindowController askQuestion:question];
	[timeout invalidate];
	runNext = nil;
	XCTAssertFalse(timedOut, @"the dialog was not answered");
}

-(void)testTypedLetterReachesTheGame
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Really attack?" choices:"yn" default:'n'];
	[self ask:q steps:@[ ^{ PostKey(@"y", 0); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'y' ]);
}

-(void)testClickingYesAfterACountSendsTheCount
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Pick up 5 arrows?" choices:"yn#aq" default:'n'];
	[self ask:q steps:@[ ^{ PostKey(@"3", 0); }, ^{ Click(@"y   Yes"); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'#' ]);
	XCTAssertEqual(q.count, 3);
}

-(void)testControlCGivesTheDefaultEvenWithoutADefaultButton
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Which ring-finger?" choices:"rl" default:0];
	[self ask:q steps:@[ ^{ PostKey(@"\003", NSEventModifierFlagControl); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @0 ]);
}

-(void)testEveryButtonShowsItsKey
{
	for ( NSString * choices in @[ @"ynq", @"hsq", @"rl", @"yn#aq", @":oibrs nq or ?", @"cnoa q" ] ) {
		NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Well?" choices:choices.UTF8String default:'q'];
		__block NSArray * titles = nil;
		[self ask:q steps:@[ ^{
			titles = [Buttons() valueForKey:@"title"];
			[Dialog() performClose:nil];
		} ]];
		NSString * answers = [YesNoInput visibleAnswersForChoices:choices];
		XCTAssertEqual(titles.count, answers.length, @"%@: one button per answer", choices);
		for ( NSString * title in titles ) {
			NSString * key = [title substringToIndex:1];
			XCTAssertTrue([answers containsString:key], @"%@: button \"%@\" doesn't start with its key", choices, title);
			XCTAssertTrue(title.length == 1 || [title characterAtIndex:1] == ' ', @"%@: button \"%@\" doesn't start with its key", choices, title);
		}
	}
}

-(void)testCloseButtonCancels
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Eat it?" choices:"ynq" default:'q'];
	[self ask:q steps:@[ ^{ [Dialog() performClose:nil]; } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'q' ]);
}

@end
