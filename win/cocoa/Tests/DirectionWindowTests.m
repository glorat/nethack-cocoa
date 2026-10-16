#import <Carbon/Carbon.h>
#import "WindowTestCase.h"
#import "DirectionWindowController.h"
#import "StubEventQueue.h"

@interface DirectionWindowTests : WindowTestCase
@end

@implementation DirectionWindowTests

-(void)ask:(NSArray<void (^)(void)> *)steps
{
	[self ask:steps directions:@"hykulnjb><"];
}

-(void)ask:(NSArray<void (^)(void)> *)steps directions:(NSString *)directions
{
	[self runModal:^{ [DirectionWindowController askWithPrompt:@"In what direction?" directions:directions near:NSZeroRect]; } steps:steps];
}

-(void)assertKey:(NSString *)chars sends:(int)key
{
	[StubEventQueue reset];
	[self ask:@[ ^{ SendKey(chars, 0, 0); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @(key) ], @"typing \"%@\"", chars);
}

-(void)testDirectionKeysAnswer
{
	for ( NSString * key in @[ @"h", @"j", @"k", @"l", @"y", @"u", @"b", @"n", @"<", @">", @"." ] )
		[self assertKey:key sends:[key characterAtIndex:0]];
}

-(void)testSAlsoMeansSelf
{
	[self assertKey:@"s" sends:'s'];
}

-(void)testQuestionMarkAsksTheGameForHelp
{
	[self assertKey:@"?" sends:'?'];
}

-(void)testUnderscorePicksAPlaceOnTheMap
{
	[self assertKey:@"_" sends:'_'];
}

-(void)testEscapeCancels
{
	[self ask:@[ ^{ SendKey(@"\033", 0, kVK_Escape); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @27 ]);
}

-(void)testOtherKeysGoToTheGameToReject
{
	[self assertKey:@"x" sends:'x'];
}

-(void)testArrowKeysAreDirections
{
	[self ask:@[ ^{ SendKey([NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey], NSEventModifierFlagFunction, kVK_LeftArrow); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'h' ]);
}

-(void)testNumberPadButtonsShowAndSendDigits
{
	__block NSArray * titles = nil;
	[self ask:@[ ^{ titles = [DialogButtons() valueForKey:@"title"]; }, ^{ ClickButton(@"7"); } ] directions:@"47896321><"];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'7' ]);
	NSSet * expected = [NSSet setWithArray:@[ @"7", @"8", @"9", @"4", @".  Self", @"6", @"1", @"2", @"3", @"<  Up", @">  Down" ]];
	XCTAssertEqualObjects([NSSet setWithArray:titles], expected);
}

-(void)testNumberPadArrowKeysSendDigits
{
	[self ask:@[ ^{ SendKey([NSString stringWithFormat:@"%C", (unichar)NSUpArrowFunctionKey], NSEventModifierFlagFunction, kVK_UpArrow); } ] directions:@"47896321><"];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'8' ]);
}

-(void)testKeypadEnterCancelsLikeReturn
{
	[self ask:@[ ^{ SendKey(@"\003", 0, kVK_ANSI_KeypadEnter); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'\r' ]);
}

-(void)testCommandKeysAreLeftToTheMenus
{
	[self ask:@[ ^{ SendKey(@"x", NSEventModifierFlagCommand, 0); }, ^{ SendKey(@"j", 0, 0); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'j' ]);
}

-(void)testClickingAButtonSendsItsKey
{
	[self ask:@[ ^{ ClickButton(@"y"); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'y' ]);
	[StubEventQueue reset];
	[self ask:@[ ^{ ClickButton(@">  Down"); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'>' ]);
}

-(void)testCloseButtonCancels
{
	[self ask:@[ ^{ [TestDialog() performClose:nil]; } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @27 ]);
}

-(void)testPromptIsInTheWindowAndEveryButtonShowsItsKey
{
	__block NSArray * titles = nil;
	__block NSString * windowTitle = nil;
	__block BOOL promptShown = NO;
	[self ask:@[ ^{
		titles = [DialogButtons() valueForKey:@"title"];
		windowTitle = TestDialog().title;
		NSMutableArray * views = [NSMutableArray arrayWithObject:TestDialog().contentView];
		while ( views.count ) {
			NSView * view = views.lastObject;
			[views removeLastObject];
			if ( [view isKindOfClass:[NSTextField class]] && [((NSTextField *)view).stringValue isEqualToString:@"In what direction?"] )
				promptShown = YES;
			[views addObjectsFromArray:view.subviews];
		}
		[TestDialog() performClose:nil];
	} ]];
	XCTAssertTrue(promptShown);
	XCTAssertEqualObjects(windowTitle, @"");
	NSSet * expected = [NSSet setWithArray:@[ @"y", @"k", @"u", @"h", @".  Self", @"l", @"b", @"j", @"n", @"<  Up", @">  Down" ]];
	XCTAssertEqualObjects([NSSet setWithArray:titles], expected);
}

#pragma mark Placement

static const NSRect kScreen = { { 0, 0 }, { 1440, 900 } };
static const NSSize kSize = { 240, 300 };

-(void)testOpensBesideTheHero
{
	NSRect hero = NSMakeRect(400, 400, 32, 32);
	NSRect frame = [DirectionWindowController frameForSize:kSize near:hero within:kScreen];
	XCTAssertFalse(NSIntersectsRect(frame, hero));
	XCTAssertEqual(NSMinX(frame), NSMaxX(hero) + 24);
	XCTAssertEqual(NSMidY(frame), NSMidY(hero));
}

-(void)testOpensLeftOfAHeroNearTheRightEdge
{
	NSRect hero = NSMakeRect(1300, 400, 32, 32);
	NSRect frame = [DirectionWindowController frameForSize:kSize near:hero within:kScreen];
	XCTAssertFalse(NSIntersectsRect(frame, hero));
	XCTAssertEqual(NSMaxX(frame), NSMinX(hero) - 24);
}

-(void)testStaysOnScreen
{
	NSRect hero = NSMakeRect(400, 10, 32, 32);
	NSRect frame = [DirectionWindowController frameForSize:kSize near:hero within:kScreen];
	XCTAssertTrue(NSContainsRect(kScreen, frame));
}

-(void)testWithoutAHeroOpensTopCentre
{
	NSRect frame = [DirectionWindowController frameForSize:kSize near:NSZeroRect within:kScreen];
	XCTAssertEqual(NSMidX(frame), NSMidX(kScreen));
	XCTAssertTrue(NSContainsRect(kScreen, frame));
}

@end
