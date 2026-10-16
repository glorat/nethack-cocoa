#import "WindowTestCase.h"
#import "YesNoWindowController.h"
#import "YesNoInput.h"
#import "NhYnQuestion.h"
#import "StubEventQueue.h"

@interface YesNoWindowTests : WindowTestCase
@end

@implementation YesNoWindowTests

-(void)ask:(NhYnQuestion *)question steps:(NSArray<void (^)(void)> *)steps
{
	[self runModal:^{ [YesNoWindowController askQuestion:question]; } steps:steps];
}

-(void)testTypedLetterReachesTheGame
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Really attack?" choices:"yn" default:'n'];
	[self ask:q steps:@[ ^{ SendKey(@"y", 0, 0); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'y' ]);
}

-(void)testClickingYesAfterACountSendsTheCount
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Pick up 5 arrows?" choices:"yn#aq" default:'n'];
	[self ask:q steps:@[ ^{ SendKey(@"3", 0, 0); }, ^{ ClickButton(@"y   Yes"); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'#' ]);
	XCTAssertEqual(q.count, 3);
}

-(void)testControlCGivesTheDefaultEvenWithoutADefaultButton
{
	NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Which ring-finger?" choices:"rl" default:0];
	[self ask:q steps:@[ ^{ SendKey(@"\003", NSEventModifierFlagControl, 0); } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @0 ]);
}

-(void)testEveryButtonShowsItsKey
{
	for ( NSString * choices in @[ @"ynq", @"hsq", @"rl", @"yn#aq", @":oibrs nq or ?", @"cnoa q" ] ) {
		NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:"Well?" choices:choices.UTF8String default:'q'];
		__block NSArray * titles = nil;
		[self ask:q steps:@[ ^{
			titles = [DialogButtons() valueForKey:@"title"];
			[TestDialog() performClose:nil];
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
	[self ask:q steps:@[ ^{ [TestDialog() performClose:nil]; } ]];
	XCTAssertEqualObjects([StubEventQueue keys], @[ @'q' ]);
}

@end
