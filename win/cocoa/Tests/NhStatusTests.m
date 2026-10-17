#import <XCTest/XCTest.h>
#import "NhStatus.h"

@interface NhStatusTests : XCTestCase
@end

@implementation NhStatusTests
{
	NhStatus * status;
}

static const int kField = 3;

-(void)setUp
{
	status = [[NhStatus alloc] init];
	[status setEnabled:YES forField:kField];
	status.turn = 100;
}

-(void)testADisabledFieldHasNoValue
{
	[status setValue:@"18" forField:kField];
	XCTAssertEqualObjects([status valueForField:kField], @"18");
	[status setEnabled:NO forField:kField];
	XCTAssertNil([status valueForField:kField]);
}

-(void)testAChangeIsShownWithItsDirection
{
	BOOL improved = NO;
	[status noteChange:-1 improved:YES forField:kField];
	XCTAssertEqual([status changeForField:kField improved:&improved], -1);
	XCTAssertTrue(improved);
}

-(void)testAChangeLastsThreeTurns
{
	[status noteChange:1 improved:YES forField:kField];
	status.turn = 102;
	XCTAssertEqual([status changeForField:kField improved:NULL], 1);
	status.turn = 103;
	XCTAssertEqual([status changeForField:kField improved:NULL], 0);
}

-(void)testALaterChangeReplacesTheEarlierOne
{
	BOOL improved = YES;
	[status noteChange:1 improved:YES forField:kField];
	status.turn = 102;
	[status noteChange:-1 improved:NO forField:kField];
	status.turn = 104;
	XCTAssertEqual([status changeForField:kField improved:&improved], -1);
	XCTAssertFalse(improved);
}

-(void)testACopyKeepsChangesButIsIndependent
{
	[status noteChange:1 improved:YES forField:kField];
	NhStatus * copy = [status copy];
	status.turn = 200;
	XCTAssertEqual([copy changeForField:kField improved:NULL], 1);
	XCTAssertEqual([status changeForField:kField improved:NULL], 0);
}

-(void)testADisabledFieldShowsNoChange
{
	[status noteChange:1 improved:YES forField:kField];
	[status setEnabled:NO forField:kField];
	XCTAssertEqual([status changeForField:kField improved:NULL], 0);
}

@end
