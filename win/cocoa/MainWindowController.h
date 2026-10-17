//
//  MainViewController.h
//  NetHack
//
//  Created by dirk on 2/1/10.
//  Copyright 2010 Dirk Zimmermann. All rights reserved.
//

/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation, version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import <AVFoundation/AVFoundation.h>

#import "ZDirection.h"
#import "Protocols.h"

@class NhYnQuestion;
@class MainView;
@class NhWindow;
@class NhMenuWindow;
@class MenuWindowController;
@class MessageWindowController;
@class PlayerSelectionWindowController;
@class NotesWindowController;
@class StatsView;
@class NhStatus;
@class EquipmentView;
@class InventoryView;
@class NetHackCocoaAppDelegate;

@interface MainWindowController : NSWindowController <NSWindowDelegate,NSMenuDelegate,NSTableViewDataSource,AVSpeechSynthesizerDelegate,NSFontChanging> {
	BOOL										isDirectionQuestion;
	BOOL										terminatedByUser;
	
	BOOL										useSpeech;
	
	AVSpeechSynthesizer						*	voice;
	NSMutableArray							*	voiceQueue;
	
	NSMutableArray							*	userTiles;
	NSString 								*	_tileSetName;

	IBOutlet MainView						*	mainView;
	IBOutlet NSTableView					*	messagesView;
	IBOutlet NSMenu							*	tileSetMenu;
	IBOutlet NSMenuItem						*	asciiModeMenuItem;
	IBOutlet StatsView						*	statsView;
	IBOutlet EquipmentView					*	equipmentView;
	InventoryView							*	inventoryView;
	NSArray<NSLayoutConstraint *>			*	inventoryShownConstraints;
	NSArray<NSLayoutConstraint *>			*	inventoryHiddenConstraints;
	
	IBOutlet PlayerSelectionWindowController*	showPlayerSelection;
	IBOutlet NotesWindowController			*	notesWindow;
}

@property (assign) 	BOOL useSpeech;
@property (strong)	NetHackCocoaAppDelegate * appDelegate;


+ (MainWindowController *) instance;


// menu
- (IBAction)performMenuAction:(id)sender;
- (IBAction)terminateApplication:(id)sender;
- (IBAction)enableAsciiMode:(id)sender;
- (IBAction)addTileSet:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)actualSize:(id)sender;

- (void)initWindows;
- (void)preferenceUpdate:(NSString *)pref;
- (void)setTerminatedByUser:(BOOL)byUser;
- (void)nethackExited;

// window API
- (void)showYnQuestion:(NhYnQuestion *)q;
- (void)updateWizardMenu;
- (void)refreshMessages;
- (void)updateStatus:(NhStatus *)status;
// gets called when core waits for input
- (void)refreshAllViews;
- (void)displayWindow:(NhWindow *)w;
- (void)showMenuWindow:(NhMenuWindow *)w;
- (void)clipAroundX:(int)x y:(int)y;
- (void)updateInventory;
- (void)setInventoryGroups:(NSArray *)groups;
- (void)chooseInventoryItem:(char)letter;
- (IBAction)toggleInventory:(id)sender;
- (void)getLineWithPrompt:(NSString *)prompt;
- (void)displayMessageWindow:(NSString *)text;
- (void)showExtendedCommands;
- (void)showPlayerSelection;
- (void)showDirectionWithPrompt:(NSString *)prompt;

// touch handling
- (void)handleMapTapTileX:(int)x y:(int)y forLocation:(CGPoint)p inView:(NSView *)view;

// speech
- (void)speakString:(NSString *)text;

@end
