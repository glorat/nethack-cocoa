#import <XCTest/XCTest.h>
#import <Carbon/Carbon.h>
#import "KeyEvent.h"

@interface KeyEventTests : XCTestCase
@end

@implementation KeyEventTests

static int KeyWith(const char * directions, NSString * chars, NSEventModifierFlags flags, unsigned short keyCode)
{
	NSEvent * event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags
									  timestamp:0 windowNumber:0 context:nil
									 characters:chars charactersIgnoringModifiers:chars isARepeat:NO keyCode:keyCode];
	return NhKeyFromEvent(event, directions);
}

static int Key(NSString * chars, NSEventModifierFlags flags, unsigned short keyCode)
{
	return KeyWith("hykulnjb><", chars, flags, keyCode);
}

-(void)testArrowsAndKeypadAreDirections
{
	XCTAssertEqual(Key(@"", 0, kVK_LeftArrow), 'h');
	XCTAssertEqual(Key(@"", 0, kVK_UpArrow), 'k');
	XCTAssertEqual(Key(@"", 0, kVK_ANSI_Keypad7), 'y');
	XCTAssertEqual(Key(@"", 0, kVK_ANSI_Keypad5), '.');
	XCTAssertEqual(Key(@"", NSEventModifierFlagShift, kVK_RightArrow), 'L');
}

-(void)testArrowsAndKeypadFollowNumberPad
{
	const char * numberPad = "47896321><";
	XCTAssertEqual(KeyWith(numberPad, @"", 0, kVK_LeftArrow), '4');
	XCTAssertEqual(KeyWith(numberPad, @"", 0, kVK_UpArrow), '8');
	XCTAssertEqual(KeyWith(numberPad, @"", 0, kVK_ANSI_Keypad7), '7');
	XCTAssertEqual(KeyWith(numberPad, @"", 0, kVK_ANSI_Keypad3), '3');
}

-(void)testKeypadFollowsSwappedYAndZ
{
	XCTAssertEqual(KeyWith("hzkulnjb><", @"", 0, kVK_ANSI_Keypad7), 'z');
}

-(void)testWithoutDirectionsArrowsAreViKeys
{
	XCTAssertEqual(KeyWith(NULL, @"", 0, kVK_DownArrow), 'j');
}

-(void)testKeypadEnterIsReturn
{
	XCTAssertEqual(Key(@"\003", 0, kVK_ANSI_KeypadEnter), '\r');
}

-(void)testEscapeAndControlKeys
{
	XCTAssertEqual(Key(@"\033", 0, kVK_Escape), 27);
	XCTAssertEqual(Key(@"r", NSEventModifierFlagControl, kVK_ANSI_R), 'R' - 'A' + 1);
}

-(void)testOrdinaryCharactersPassThrough
{
	XCTAssertEqual(Key(@"s", 0, kVK_ANSI_S), 's');
	XCTAssertEqual(Key(@"?", NSEventModifierFlagShift, kVK_ANSI_Slash), '?');
}

@end
