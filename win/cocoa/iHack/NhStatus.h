//
//  NhStatus.h
//  NetHack
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, NhSeverity) {
	NhSeverityInfo,
	NhSeverityCaution,
	NhSeverityWarning,
	NhSeverityDanger,
};

// hunger, encumbrance or a status condition
@interface NhStatusBadge : NSObject
@property (nonatomic, readonly) NSString * text;
@property (nonatomic, readonly) NhSeverity severity;
+ (instancetype)badgeWithText:(NSString *)text severity:(NhSeverity)severity;
@end

// the status fields the core last reported, keyed by its field numbers (BL_*);
// filled in on the game thread and handed to the status view as a copy
@interface NhStatus : NSObject <NSCopying>

- (void)setValue:(NSString *)value forField:(int)field;
// nil for a field the core has disabled
- (NSString *)valueForField:(int)field;
- (void)setEnabled:(BOOL)enabled forField:(int)field;

@property (nonatomic, copy) NSString * levelText;
@property (nonatomic, copy) NSString * roleText;
@property (nonatomic, copy) NSArray<NhStatusBadge *> * badges;

// the turn the status describes; a change is shown for a few turns after it
@property (nonatomic, assign) long turn;
// change is the core's direction: 1 for up, -1 for down
- (void)noteChange:(int)change improved:(BOOL)improved forField:(int)field;
// 0 once the change has been shown long enough
- (int)changeForField:(int)field improved:(BOOL *)improved;

@end
