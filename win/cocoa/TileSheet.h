#import <Foundation/Foundation.h>

// The size of a sheet's image file in pixels, read from its header; zero if it isn't an image
NSSize NhPixelSizeOfImageFile(NSString * path);

// tile2bmp's 40 tiles per row, with the height from the file name if it gives one (tiles10x20.bmp);
// a sheet that isn't 40 tiles wide needs its size in the name (tiles32.png). Zero if neither fits
NSSize NhTileSizeOfSheet(NSString * fileName, NSSize pixels);

// Why a sheet can't be used, or nil if it can
NSString * NhTileSheetProblem(NSSize pixels, NSSize tileSize, int tilesNeeded);

// The .png and .bmp files directly inside a folder, sorted by name
NSArray<NSString *> * NhTileSheetsInFolder(NSString * folder);
