#import "WindowTestCase.h"
#import "StubEventQueue.h"

NSWindow * TestDialog(void)
{
	for ( NSWindow * window in NSApp.windows ) {
		if ( window.isVisible )
			return window;
	}
	return nil;
}

NSArray<NSButton *> * DialogButtons(void)
{
	NSMutableArray * buttons = [NSMutableArray array];
	NSMutableArray * views = [NSMutableArray arrayWithObject:TestDialog().contentView];
	while ( views.count ) {
		NSView * view = views.lastObject;
		[views removeLastObject];
		if ( [view isKindOfClass:[NSButton class]] )
			[buttons addObject:view];
		[views addObjectsFromArray:view.subviews];
	}
	return buttons;
}

void ClickButton(NSString * title)
{
	for ( NSButton * button in DialogButtons() ) {
		if ( [button.title isEqualToString:title] ) {
			[button performClick:nil];
			return;
		}
	}
}

void SendKey(NSString * chars, NSEventModifierFlags flags, unsigned short keyCode)
{
	NSEvent * event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags
									  timestamp:0 windowNumber:TestDialog().windowNumber context:nil
									 characters:chars charactersIgnoringModifiers:chars isARepeat:NO keyCode:keyCode];
	[NSApp sendEvent:event];
}

static void After(NSTimeInterval delay, void (^block)(void))
{
	NSTimer * timer = [NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer * _) { block(); }];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

@implementation WindowTestCase

-(void)setUp
{
	[NSApplication sharedApplication];
	[StubEventQueue reset];
}

// each step is scheduled only after the one before it has run, so a slow
// first window can't make two steps fire together
-(void)runModal:(void (^)(void))show steps:(NSArray<void (^)(void)> *)steps
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
	NSTimer * timeout = [NSTimer timerWithTimeInterval:5 repeats:NO block:^(NSTimer * _) {
		timedOut = YES;
		[TestDialog() close];
		[NSApp stopModal];
	}];
	[[NSRunLoop mainRunLoop] addTimer:timeout forMode:NSRunLoopCommonModes];
	show();
	[timeout invalidate];
	runNext = nil;
	XCTAssertFalse(timedOut, @"the dialog was not answered");
}

@end
