#import "KeyEvent.h"
#import <Carbon/Carbon.h>	// key codes

int NhKeyFromEvent(NSEvent * keyEvent, const char * directions)
{
	if ( [keyEvent type] != NSEventTypeKeyDown )
		return 0;
	if ( directions == NULL )
		directions = "hykulnjb><";
		
	int key = 0;
	switch ( [keyEvent keyCode] ) {
			// arrows
		case kVK_LeftArrow:				key = directions[0];	break;
		case kVK_RightArrow:			key	= directions[4];	break;
		case kVK_DownArrow:				key = directions[6];	break;
		case kVK_UpArrow:				key = directions[2];	break;
			// keypad
		case kVK_ANSI_Keypad1:			key = directions[7];	break;
		case kVK_ANSI_Keypad2:			key = directions[6];	break;
		case kVK_ANSI_Keypad3:			key = directions[5];	break;
		case kVK_ANSI_Keypad4:			key = directions[0];	break;
		case kVK_ANSI_Keypad5:			key = '.';				break;
		case kVK_ANSI_Keypad6:			key = directions[4];	break;
		case kVK_ANSI_Keypad7:			key = directions[1];	break;
		case kVK_ANSI_Keypad8:			key = directions[2];	break;
		case kVK_ANSI_Keypad9:			key = directions[3];	break;
		case kVK_ANSI_KeypadEnter:		key = '\r';			break;
			// escape
		case kVK_Escape:				key = '\033';			break;
	}
	if ( key ) {
		NSUInteger modifier = [keyEvent modifierFlags];
		if ( modifier & NSEventModifierFlagShift ) {
			key = toupper(key);
		}
	} else {
		// "real" keys
		NSString * chars = [keyEvent charactersIgnoringModifiers];
		NSUInteger modifier = [keyEvent modifierFlags];
		key = [chars characterAtIndex:0];
		
		switch (key) {
			case NSUpArrowFunctionKey:
			case NSDownArrowFunctionKey:
			case NSLeftArrowFunctionKey:
			case NSRightArrowFunctionKey:
				break;
			default:
				break;
		}
		
		
		if ( modifier & NSEventModifierFlagCommand ) {
			// map Cmd-x to Ctrl-x to match Qt port
			if ( strchr( "ad", key ) != NULL ) {
				modifier &= ~NSEventModifierFlagCommand;
				modifier |= NSEventModifierFlagControl;
			}
		}
		
		if ( modifier & NSEventModifierFlagShift  ) {
			// system already upcases for us
		}
		if ( modifier & NSEventModifierFlagControl ) {
			// convert to control key
			key = toupper(key) - 'A' + 1;
		}
		if ( modifier & NSEventModifierFlagOption ) {
			// convert to meta key
			key = 0x80 | key;
		}
	}
	return key;
}
