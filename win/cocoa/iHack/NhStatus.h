//
//  NhStatus.h
//  NetHack
//

#import <Foundation/Foundation.h>

// the status fields the core last reported, keyed by its field numbers (BL_*);
// filled in on the game thread and handed to the status view as a copy
@interface NhStatus : NSObject <NSCopying>

- (void)setValue:(NSString *)value forField:(int)field;
// nil for a field the core has disabled
- (NSString *)valueForField:(int)field;
- (void)setEnabled:(BOOL)enabled forField:(int)field;

@property (nonatomic, copy) NSString * levelText;
@property (nonatomic, copy) NSString * roleText;
@property (nonatomic, copy) NSString * stateText;

@end
