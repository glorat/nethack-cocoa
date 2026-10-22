#import <XCTest/XCTest.h>
#import "TextSize.h"

@interface TextSizeTests : XCTestCase
@end

@implementation TextSizeTests

-(void)tearDown
{
	NhSetTextSize(NhDefaultTextSize);
}

-(void)testBiggerAndSmallerStepFromTheDefault
{
	XCTAssertEqual(NhBiggerTextSize(NhDefaultTextSize), 14);
	XCTAssertEqual(NhSmallerTextSize(NhDefaultTextSize), 12);
}

-(void)testStepsStopAtTheEnds
{
	XCTAssertEqual(NhBiggerTextSize(28), 28);
	XCTAssertEqual(NhSmallerTextSize(10), 10);
}

-(void)testASizeBetweenStepsMovesToTheNextOne
{
	XCTAssertEqual(NhBiggerTextSize(15), 16);
	XCTAssertEqual(NhSmallerTextSize(15), 14);
}

-(void)testAnOptionsFileSizeSnapsToAStep
{
	NhSetTextSize(17);
	XCTAssertEqual(NhTextSize(), 16);
	NhSetTextSize(100);
	XCTAssertEqual(NhTextSize(), 28);
	NhSetTextSize(1);
	XCTAssertEqual(NhTextSize(), 10);
}

-(void)testOtherTextScalesWithTheMessageText
{
	XCTAssertEqual(NhScaledFontSize(11), 11);
	NhSetTextSize(20);
	XCTAssertEqual(NhScaledFontSize(11), 17);
	XCTAssertEqual(NhScaledFont([NSFont boldSystemFontOfSize:13]).pointSize, 20);
}

-(void)testChangingTheSizeTellsTheViews
{
	[self expectationForNotification:NhTextSizeDidChangeNotification object:nil handler:nil];
	NhSetTextSize(18);
	[self waitForExpectationsWithTimeout:0 handler:nil];
}

@end
