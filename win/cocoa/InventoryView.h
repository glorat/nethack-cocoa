//
//  InventoryView.h
//  NetHack
//

#import <Cocoa/Cocoa.h>

@class NhItemGroup;

@interface InventoryView : NSView <NSTableViewDataSource, NSTableViewDelegate>

// called with the inventory letter of a clicked item
@property (nonatomic, copy) void (^chooseItem)(char letter);

// called with the width the left edge has been dragged to, and done once the button is up
@property (nonatomic, copy) void (^resize)(CGFloat width, BOOL done);

- (void)setItemGroups:(NSArray<NhItemGroup *> *)groups;

@end
