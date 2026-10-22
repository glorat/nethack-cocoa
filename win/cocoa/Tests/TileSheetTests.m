#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "TileSheet.h"

@interface TileSheetTests : XCTestCase
@end

@implementation TileSheetTests
{
	NSString * folder;
}

-(void)setUp
{
	folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
}

-(void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
}

-(NSString *)writePNG:(NSString *)name width:(int)width height:(int)height
{
	NSBitmapImageRep * rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
		bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	NSString * path = [folder stringByAppendingPathComponent:name];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
	return path;
}

-(void)testPixelSizeIsReadFromTheFile
{
	NSString * path = [self writePNG:@"sheet.png" width:640 height:928];
	XCTAssertTrue(NSEqualSizes(NhPixelSizeOfImageFile(path), NSMakeSize(640, 928)));
}

-(void)testAFileThatIsntAnImageHasNoSize
{
	NSString * path = [folder stringByAppendingPathComponent:@"notes.png"];
	[@"not an image" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	XCTAssertTrue(NSEqualSizes(NhPixelSizeOfImageFile(path), NSZeroSize));
	XCTAssertNotNil(NhTileSheetProblem(NSZeroSize, NSZeroSize, 100));
}

-(void)testWithoutASizeInTheNameTilesAreFortyToARow
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"DawnHack.png", NSMakeSize(1280, 1856)), NSMakeSize(32, 32)));
}

-(void)testASizeInTheNameIsUsed
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"tiles24.png", NSMakeSize(960, 1392)), NSMakeSize(24, 24)));
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"Nethack Modern 24.bmp", NSMakeSize(960, 1392)), NSMakeSize(24, 24)));
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"/a/b/tiles10x20.bmp", NSMakeSize(400, 1160)), NSMakeSize(10, 20)));
}

-(void)testAVersionNumberInTheNameIsntASize
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"DawnHack 3.6.png", NSMakeSize(1280, 1856)), NSMakeSize(32, 32)));
}

-(void)testANumberInTheNameThatIsntFortyToARowIsIgnored
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"tiles64 copy 2.png", NSMakeSize(2560, 3712)), NSMakeSize(64, 64)));
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"DawnHack_v2.png", NSMakeSize(1280, 1856)), NSMakeSize(32, 32)));
}

-(void)testANameSizeIsUsedWhenTheSheetIsntFortyTilesWide
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"tiles32.png", NSMakeSize(1312, 1856)), NSMakeSize(32, 32)));
}

-(void)testANameSizeThatDoesntFitTheWidthIsIgnored
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"sheet7.png", NSMakeSize(1280, 1856)), NSMakeSize(32, 32)));
}

-(void)testNoSizeWhenNothingFits
{
	XCTAssertTrue(NSEqualSizes(NhTileSizeOfSheet(@"sheet.png", NSMakeSize(1010, 1000)), NSZeroSize));
	XCTAssertNotNil(NhTileSheetProblem(NSMakeSize(1010, 1000), NSZeroSize, 100));
}

-(void)testASheetWithEnoughTilesIsFine
{
	XCTAssertNil(NhTileSheetProblem(NSMakeSize(640, 937), NSMakeSize(16, 16), 2303));
}

-(void)testASheetWithTooFewTilesSaysHowMany
{
	NSString * problem = NhTileSheetProblem(NSMakeSize(1280, 960), NSMakeSize(32, 32), 2303);
	XCTAssertTrue([problem containsString:@"1200"], @"%@", problem);
	XCTAssertTrue([problem containsString:@"2303"], @"%@", problem);
}

-(void)testOnlyImageFilesDirectlyInTheFolderAreFound
{
	[self writePNG:@"b.png" width:40 height:40];
	[self writePNG:@"A.PNG" width:40 height:40];
	[self writePNG:@".hidden.png" width:40 height:40];
	[@"" writeToFile:[folder stringByAppendingPathComponent:@"tiles.bmp"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	[@"" writeToFile:[folder stringByAppendingPathComponent:@".nethackrc"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:[folder stringByAppendingPathComponent:@"Pictures.png"] withIntermediateDirectories:NO attributes:nil error:NULL];
	NSArray * expected = @[@"A.PNG", @"b.png", @"tiles.bmp"];
	XCTAssertEqualObjects(NhTileSheetsInFolder(folder), expected);
}

@end
