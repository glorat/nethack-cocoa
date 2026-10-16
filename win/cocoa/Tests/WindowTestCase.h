#import <XCTest/XCTest.h>

@interface WindowTestCase : XCTestCase

-(void)runModal:(void (^)(void))show steps:(NSArray<void (^)(void)> *)steps;

@end

NSWindow * TestDialog(void);
NSArray<NSButton *> * DialogButtons(void);
void ClickButton(NSString * title);
void SendKey(NSString * chars, NSEventModifierFlags flags, unsigned short keyCode);
