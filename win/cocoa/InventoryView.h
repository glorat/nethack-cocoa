//
//  InventoryView.h
//  NetHack
//

#import <Cocoa/Cocoa.h>

@class NhItemGroup;

@interface InventoryView : NSView <NSTableViewDataSource, NSTableViewDelegate>

// called with the inventory letter of a clicked item
@property (nonatomic, copy) void (^chooseItem)(char letter);

- (void)setItemGroups:(NSArray<NhItemGroup *> *)groups;

@end
