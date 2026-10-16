#import <Cocoa/Cocoa.h>

// directions: the core's gc.Cmd.dirchars (W NW N NE E SE S SW down up), or NULL for vi-keys
int NhKeyFromEvent(NSEvent * keyEvent, const char * directions);
