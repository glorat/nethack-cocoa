#import <Carbon/Carbon.h>
#import "WindowTestCase.h"
#import "InputWindowController.h"

@interface InputWindowTests : WindowTestCase
@end

@implementation InputWindowTests {
	NSString * answer;
	NSUInteger answers;
}

-(void)ask:(NSString *)prompt parent:(NSWindow *)parent steps:(NSArray<void (^)(void)> *)steps
{
	answer = nil;
	answers = 0;
	[self runModal:^{
		[InputWindowController askWithPrompt:prompt parent:parent answer:^(NSString * text) {
			self->answer = text;
			self->answers++;
		}];
	} steps:steps];
}

-(void)ask:(NSArray<void (^)(void)> *)steps
{
	[self ask:@"What do you want to name this scroll?" parent:nil steps:steps];
}

static void Type(NSString * text)
{
	for ( NSUInteger i = 0; i < text.length; ++i )
		SendKey([text substringWithRange:NSMakeRange(i, 1)], 0, 0);
}

static void Return(void) { SendKey(@"\r", 0, kVK_Return); }
static void Escape(void) { SendKey(@"\033", 0, kVK_Escape); }

static NSString * Typed(void)
{
	return [((NSText *)TestDialog().firstResponder).string copy];
}

-(void)assertAnswer:(NSString *)expected
{
	XCTAssertEqualObjects(answer, expected);
	XCTAssertEqual(answers, 1u);
}

-(void)testTypedTextAndReturnReachTheGame
{
	[self ask:@[ ^{ Type(@"fire"); }, ^{ Return(); } ]];
	[self assertAnswer:@"fire"];
}

-(void)testReturnWithNothingTypedGivesAnEmptyAnswer
{
	[self ask:@[ ^{ Return(); } ]];
	[self assertAnswer:@""];
}

-(void)testEscapeWithTextTypedClearsItFirst
{
	__block NSString * shown = nil;
	__block NSUInteger answersAfterFirstEscape = 99;
	[self ask:@[ ^{ Type(@"fire"); }, ^{ Escape(); }, ^{
		shown = Typed();
		answersAfterFirstEscape = self->answers;
	}, ^{ Escape(); } ]];
	XCTAssertEqualObjects(shown, @"");
	XCTAssertEqual(answersAfterFirstEscape, 0u);
	[self assertAnswer:@"\033"];
}

-(void)testEscapeWithNothingTypedCancels
{
	[self ask:@[ ^{ Escape(); } ]];
	[self assertAnswer:@"\033"];
}

-(void)testCloseButtonCancels
{
	[self ask:@[ ^{ [TestDialog() performClose:nil]; } ]];
	[self assertAnswer:@"\033"];
}

-(void)testCancelButtonCancelsEvenWithTextTyped
{
	[self ask:@[ ^{ Type(@"fire"); }, ^{ ClickButton(@"Cancel"); } ]];
	[self assertAnswer:@"\033"];
}

-(void)testALongPromptIsShownInFull
{
	NSString * prompt = @"What do you want to call this scroll labeled VERR YED HORRE, which you read while confused?";
	__block BOOL found = NO;
	__block NSSize needed = NSZeroSize, shown = NSZeroSize;
	[self ask:prompt parent:nil steps:@[ ^{
		NSMutableArray * views = [NSMutableArray arrayWithObject:TestDialog().contentView];
		while ( views.count ) {
			NSView * view = views.lastObject;
			[views removeLastObject];
			if ( [view isKindOfClass:[NSTextField class]] && [((NSTextField *)view).stringValue isEqualToString:prompt] ) {
				NSTextField * label = (NSTextField *)view;
				found = YES;
				shown = label.frame.size;
				needed = [prompt boundingRectWithSize:NSMakeSize(shown.width - 4, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin
										   attributes:@{ NSFontAttributeName : label.font }].size;
			}
			[views addObjectsFromArray:view.subviews];
		}
	}, ^{ Escape(); } ]];
	XCTAssertTrue(found, @"the prompt isn't shown");
	XCTAssertGreaterThanOrEqual(ceil(shown.height), ceil(needed.height), @"the prompt is cut off");
}

-(void)testItOpensAsASheetOnTheGameWindow
{
	NSWindow * parent = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 600, 400)
													styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	parent.releasedWhenClosed = NO;
	[parent orderFront:nil];
	__block BOOL sheet = NO;
	[self ask:@"For what do you wish?" parent:parent steps:@[ ^{
		sheet = parent.attachedSheet != nil && parent.attachedSheet == TestDialog();
	}, ^{ Type(@"wand"); }, ^{ Return(); } ]];
	XCTAssertTrue(sheet);
	XCTAssertNil(parent.attachedSheet, @"the sheet is still attached");
	[self assertAnswer:@"wand"];
	[parent close];
}

@end
