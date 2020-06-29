/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Handles UI interaction and retrieves window images.
 */

#import "Controller.h"

@interface WindowListApplierData : NSObject
{
}

@property (strong, nonatomic) NSMutableArray * outputArray;
@property int order;

@end

@implementation WindowListApplierData

-(instancetype)initWindowListData:(NSMutableArray *)array
{
    self = [super init];
    
    self.outputArray = array;
    self.order = 0;
    
    return self;
}

@end


@interface Controller ()
{
	IBOutlet NSImageView *outputView;
	IBOutlet NSArrayController *arrayController;
	
	CGWindowListOption listOptions;
	CGWindowListOption singleWindowListOptions;
	CGWindowImageOption imageOptions;
	CGRect imageBounds;
}

@property (strong) WindowListApplierData *windowListData;
@property (weak) IBOutlet NSButton * listOffscreenWindows;
@property (weak) IBOutlet NSButton * listDesktopWindows;
@property (weak) IBOutlet NSButton * imageFramingEffects;
@property (weak) IBOutlet NSButton * imageOpaqueImage;
@property (weak) IBOutlet NSButton * imageShadowsOnly;
@property (weak) IBOutlet NSButton * imageTightFit;
@property (weak) IBOutlet NSMatrix * singleWindow;

@end


@implementation Controller

#pragma mark Basic Profiling Tools
// Set to 1 to enable basic profiling. Profiling information is logged to console.
#ifndef PROFILE_WINDOW_GRAB
#define PROFILE_WINDOW_GRAB 0
#endif

#if PROFILE_WINDOW_GRAB
#define StopwatchStart() AbsoluteTime start = UpTime()
#define Profile(img) CFRelease(CGDataProviderCopyData(CGImageGetDataProvider(img)))
#define StopwatchEnd(caption) do { Duration time = AbsoluteDeltaToDuration(UpTime(), start); double timef = time < 0 ? time / -1000000.0 : time / 1000.0; NSLog(@"%s Time Taken: %f seconds", caption, timef); } while(0)
#else
#define StopwatchStart()
#define Profile(img)
#define StopwatchEnd(caption)
#endif

#pragma mark Utilities

// Simple helper to twiddle bits in a uint32_t. 
uint32_t ChangeBits(uint32_t currentBits, uint32_t flagsToChange, BOOL setFlags);
inline uint32_t ChangeBits(uint32_t currentBits, uint32_t flagsToChange, BOOL setFlags)
{
	if(setFlags)
	{	// Set Bits
		return currentBits | flagsToChange;
	}
	else
	{	// Clear Bits
		return currentBits & ~flagsToChange;
	}
}

-(void)setOutputImage:(CGImageRef)cgImage
{
	if(cgImage != NULL)
	{
		// Create a bitmap rep from the image...
		NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
		// Create an NSImage and add the bitmap rep to it...
		NSImage *image = [[NSImage alloc] init];
		[image addRepresentation:bitmapRep];
        
        //NSLog(@"image with = %d, image height = %d", image.size.width, image.size.height);
        
        
		// Set the output view to the new NSImage.
		[outputView setImage:image];
	}
	else
	{
		[outputView setImage:nil];
	}
}

#pragma mark Window List & Window Image Methods

NSString *kAppNameKey = @"applicationName";	// Application Name & PID
NSString *kWindowOriginKey = @"windowOrigin";	// Window Origin as a string
NSString *kWindowSizeKey = @"windowSize";		// Window Size as a string
NSString *kWindowIDKey = @"windowID";			// Window ID
NSString *kWindowLevelKey = @"windowLevel";	// Window Level
NSString *kWindowOrderKey = @"windowOrder";	// The overall front-to-back ordering of the windows as returned by the window server

void WindowListApplierFunction(const void *inputDictionary, void *context);
void WindowListApplierFunction(const void *inputDictionary, void *context)
{
	NSDictionary *entry = (__bridge NSDictionary*)inputDictionary;
	WindowListApplierData *data = (__bridge WindowListApplierData*)context;
	
	// The flags that we pass to CGWindowListCopyWindowInfo will automatically filter out most undesirable windows.
	// However, it is possible that we will get back a window that we cannot read from, so we'll filter those out manually.
	int sharingState = [entry[(id)kCGWindowSharingState] intValue];
	if(sharingState != kCGWindowSharingNone)
	{
		NSMutableDictionary *outputEntry = [NSMutableDictionary dictionary];
		
		// Grab the application name, but since it's optional we need to check before we can use it.
		NSString *applicationName = entry[(id)kCGWindowOwnerName];
		if(applicationName != NULL)
		{
			// PID is required so we assume it's present.
			NSString *nameAndPID = [NSString stringWithFormat:@"%@ (%@)", applicationName, entry[(id)kCGWindowOwnerPID]];
			outputEntry[kAppNameKey] = nameAndPID;
		}
		else
		{
			// The application name was not provided, so we use a fake application name to designate this.
			// PID is required so we assume it's present.
			NSString *nameAndPID = [NSString stringWithFormat:@"((unknown)) (%@)", entry[(id)kCGWindowOwnerPID]];
			outputEntry[kAppNameKey] = nameAndPID;
		}
		
		// Grab the Window Bounds, it's a dictionary in the array, but we want to display it as a string
		CGRect bounds;
		CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)entry[(id)kCGWindowBounds], &bounds);
		NSString *originString = [NSString stringWithFormat:@"%.0f/%.0f", bounds.origin.x, bounds.origin.y];
		outputEntry[kWindowOriginKey] = originString;
		NSString *sizeString = [NSString stringWithFormat:@"%.0f*%.0f", bounds.size.width, bounds.size.height];
		outputEntry[kWindowSizeKey] = sizeString;
		
		// Grab the Window ID & Window Level. Both are required, so just copy from one to the other
		outputEntry[kWindowIDKey] = entry[(id)kCGWindowNumber];
		outputEntry[kWindowLevelKey] = entry[(id)kCGWindowLayer];
		
		// Finally, we are passed the windows in order from front to back by the window server
		// Should the user sort the window list we want to retain that order so that screen shots
		// look correct no matter what selection they make, or what order the items are in. We do this
		// by maintaining a window order key that we'll apply later.
		outputEntry[kWindowOrderKey] = @(data.order);
		data.order++;
		
		[data.outputArray addObject:outputEntry];
	}
}

-(void)updateWindowList
{
	// Ask the window server for the list of windows.
	StopwatchStart();
	CFArrayRef windowList = CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID);
	StopwatchEnd("Create Window List");
	
	// Copy the returned list, further pruned, to another list. This also adds some bookkeeping
	// information to the list as well as 
	NSMutableArray * prunedWindowList = [NSMutableArray array];
    self.windowListData = [[WindowListApplierData alloc] initWindowListData:prunedWindowList];

    CFArrayApplyFunction(windowList, CFRangeMake(0, CFArrayGetCount(windowList)), &WindowListApplierFunction, (__bridge void *)(self.windowListData));
	CFRelease(windowList);
	
	// Set the new window list
	[arrayController setContent:prunedWindowList];
}

-(CFArrayRef)newWindowListFromSelection:(NSArray*)selection
{
	// Create a sort descriptor array. It consists of a single descriptor that sorts based on the kWindowOrderKey in ascending order
	NSArray * sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:kWindowOrderKey ascending:YES]];

	// Next sort the selection based on that sort descriptor array
	NSArray * sortedSelection = [selection sortedArrayUsingDescriptors:sortDescriptors];

	// Now we Collect the CGWindowIDs from the sorted selection
    int count = [sortedSelection count];
    const void *windowIDs[count];
    int i = 0;
	for(NSMutableDictionary *entry in sortedSelection)
	{
		windowIDs[i++] = [entry[kWindowIDKey] unsignedIntValue];
	}
	CFArrayRef windowIDsArray = CFArrayCreate(kCFAllocatorDefault, (const void**)windowIDs, [sortedSelection count], NULL);
	
	// And send our new array on it's merry way
	return windowIDsArray;
}

-(void)createSingleWindowShot:(CGWindowID)windowID
{
	// Create an image from the passed in windowID with the single window option selected by the user.
	StopwatchStart();
    
//    CGWindowLevel level =  CGWindowLevelForKey(kCGCursorWindowLevelKey);
    
    
    
    
	CGImageRef windowImage = CGWindowListCreateImage(imageBounds, singleWindowListOptions, windowID, imageOptions);
	Profile(windowImage);
	StopwatchEnd("Single Window");
    NSLog(@"singleImage = %@", windowImage);
	[self setOutputImage:windowImage];
	CGImageRelease(windowImage);
}

-(void)createMultiWindowShot:(NSArray*)selection
{
	// Get the correctly sorted list of window IDs. This is a CFArrayRef because we need to put integers in the array
	// instead of CFTypes or NSObjects.
	CFArrayRef windowIDs = [self newWindowListFromSelection:selection];
	
	// And finally create the window image and set it as our output image.
	StopwatchStart();
	CGImageRef windowImage = CGWindowListCreateImageFromArray(imageBounds, windowIDs, imageOptions);
	Profile(windowImage);
	StopwatchEnd("Multiple Window");
	CFRelease(windowIDs);
	[self setOutputImage:windowImage];
	CGImageRelease(windowImage);
}

-(void)createScreenShot
{
	// This just invokes the API as you would if you wanted to grab a screen shot. The equivalent using the UI would be to
	// enable all windows, turn off "Fit Image Tightly", and then select all windows in the list.
	StopwatchStart();
	CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault);
    
    size_t width = CGImageGetWidth(screenShot);
    size_t height = CGImageGetHeight(screenShot);
    
    CGDataProviderRef provider = CGImageGetDataProvider(screenShot);
    CFDataRef data = CGDataProviderCopyData(provider);
//    const UInt8 *ptr = CFDataGetBytePtr(data);
    CFIndex length = CFDataGetLength(data);
    CFRelease(data);
    
    //NSLog(@"width = %zu, height = %zu, length = %ld", width, height, (long)length);
    
    
	Profile(screenShot);
	StopwatchEnd("Screenshot");
	[self setOutputImage:screenShot];
	CGImageRelease(screenShot);
}

#pragma mark GUI Support

-(void)updateImageWithSelection
{
	// Depending on how much is selected either clear the output image
	// set the image based on a single selected window or
	// set the image based on multiple selected windows.
	NSArray *selection = [arrayController selectedObjects];
	if([selection count] == 0)
	{
		[self setOutputImage:NULL];
	}
	else if([selection count] == 1)
	{
		// Single window selected, so use the single window options.
		// Need to grab the CGWindowID to pass to the method.
		CGWindowID windowID = [selection[0][kWindowIDKey] unsignedIntValue];
		[self createSingleWindowShot:windowID];
	}
	else
	{
		// Multiple windows selected, so composite just those windows
		[self createMultiWindowShot:selection];
	}
}

enum
{
	// Constants that correspond to the rows in the
	// Single Window Option matrix.
	kSingleWindowAboveOnly = 0,
	kSingleWindowAboveIncluded = 1,
	kSingleWindowOnly = 2,
	kSingleWindowBelowIncluded = 3,
	kSingleWindowBelowOnly = 4,
};

// Simple helper that converts the selected row number of the singleWindow NSMatrix 
// to the appropriate CGWindowListOption.
-(CGWindowListOption)singleWindowOption
{
	CGWindowListOption option = 0;
	switch([_singleWindow selectedRow])
	{
		case kSingleWindowAboveOnly:
			option = kCGWindowListOptionOnScreenAboveWindow;
			break;
			
		case kSingleWindowAboveIncluded:
			option = kCGWindowListOptionOnScreenAboveWindow | kCGWindowListOptionIncludingWindow;
			break;
			
		case kSingleWindowOnly:
			option = kCGWindowListOptionIncludingWindow;
			break;
			
		case kSingleWindowBelowIncluded:
			option = kCGWindowListOptionOnScreenBelowWindow | kCGWindowListOptionIncludingWindow;
			break;

		case kSingleWindowBelowOnly:
			option = kCGWindowListOptionOnScreenBelowWindow;
			break;
			
		default:
			break;
	}
	return option;
}

NSString *kvoContext = @"SonOfGrabContext";
-(void)awakeFromNib
{
	// Set the initial list options to match the UI.
	listOptions = kCGWindowListOptionAll;
	listOptions = ChangeBits(listOptions, kCGWindowListOptionOnScreenOnly, [_listOffscreenWindows intValue] == NSOffState);
	listOptions = ChangeBits(listOptions, kCGWindowListExcludeDesktopElements, [_listDesktopWindows intValue] == NSOffState);

	// Set the initial image options to match the UI.
	imageOptions = kCGWindowImageDefault;
	imageOptions = ChangeBits(imageOptions, kCGWindowImageBoundsIgnoreFraming, [_imageFramingEffects intValue] == NSOnState);
	imageOptions = ChangeBits(imageOptions, kCGWindowImageShouldBeOpaque, [_imageOpaqueImage intValue] == NSOnState);
	imageOptions = ChangeBits(imageOptions, kCGWindowImageOnlyShadows, [_imageShadowsOnly intValue] == NSOnState);
	
	// Set initial single window options to match the UI.
	singleWindowListOptions = [self singleWindowOption];
	
	// CGWindowListCreateImage & CGWindowListCreateImageFromArray will determine their image size dependent on the passed in bounds.
	// This sample only demonstrates passing either CGRectInfinite to get an image the size of the desktop
	// or passing CGRectNull to get an image that tightly fits the windows specified, but you can pass any rect you like.
	imageBounds = ([_imageTightFit intValue] == NSOnState) ? CGRectNull : CGRectInfinite;
	
	// Register for updates to the selection
	[arrayController addObserver:self forKeyPath:@"selectionIndexes" options:0 context:&kvoContext];
	
	// Make sure the source list window is in front
	[[outputView window] makeKeyAndOrderFront:self];
	[[self window] makeKeyAndOrderFront:self];

	// Get the initial window list, and set the initial image, but wait for us to return to the
	// event loop so that the sample's windows will be included in the list as well.
	[self performSelectorOnMainThread:@selector(refreshWindowList:) withObject:self waitUntilDone:NO];
	
	// Default to creating a screen shot. Do this after our return since the previous request
	// to refresh the window list will set it to nothing due to the interactions with KVO.
	[self performSelectorOnMainThread:@selector(createScreenShot) withObject:self waitUntilDone:NO];
}

-(void)dealloc
{
	// Remove our KVO notification
	[arrayController removeObserver:self forKeyPath:@"selectionIndexes"];
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context == &kvoContext)
	{
	// Find the "Single Window" options control and dynamically enable it based on how many items are selected.
	[_singleWindow setEnabled:[[arrayController selectedObjects] count] <= 1];
	
	// Selection has changed, so update the image
	[self updateImageWithSelection];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}

}

#pragma mark Control Actions

-(IBAction)toggleOffscreenWindows:(id)sender
{
	listOptions = ChangeBits(listOptions, kCGWindowListOptionOnScreenOnly, [sender intValue] == NSOffState);
	[self updateWindowList];
	[self updateImageWithSelection];
}

-(IBAction)toggleDesktopWindows:(id)sender
{
	listOptions = ChangeBits(listOptions, kCGWindowListExcludeDesktopElements, [sender intValue] == NSOffState);
	[self updateWindowList];
	[self updateImageWithSelection];
}

-(IBAction)toggleFramingEffects:(id)sender
{
	imageOptions = ChangeBits(imageOptions, kCGWindowImageBoundsIgnoreFraming, [sender intValue] == NSOnState);
	[self updateImageWithSelection];
}

-(IBAction)toggleOpaqueImage:(id)sender
{
	imageOptions = ChangeBits(imageOptions, kCGWindowImageShouldBeOpaque, [sender intValue] == NSOnState);
	[self updateImageWithSelection];
}

-(IBAction)toggleShadowsOnly:(id)sender
{
	imageOptions = ChangeBits(imageOptions, kCGWindowImageOnlyShadows, [sender intValue] == NSOnState);
	[self updateImageWithSelection];
}

-(IBAction)toggleTightFit:(id)sender
{
	imageBounds = ([sender intValue] == NSOnState) ? CGRectNull : CGRectInfinite;
	[self updateImageWithSelection];
}

-(IBAction)updateSingleWindowOption:(id)sender
{
	#pragma unused(sender)
	singleWindowListOptions = [self singleWindowOption];
	[self updateImageWithSelection];
}

-(IBAction)grabScreenShot:(id)sender
{
	#pragma unused(sender)
	[self createScreenShot];
}

-(IBAction)refreshWindowList:(id)sender
{
	#pragma unused(sender)
	// Refreshing the window list combines updating the window list and updating the window image.
	[self updateWindowList];
	[self updateImageWithSelection];
}


- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    CVPixelBufferRef pxbuffer = NULL;
    NSCParameterAssert(NULL != image);
    size_t originalWidth = CGImageGetWidth(image);
    size_t originalHeight = CGImageGetHeight(image);
    
    NSMutableData *imageData = [NSMutableData dataWithLength:originalWidth*originalHeight*4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate([imageData mutableBytes], originalWidth, originalHeight, 8, 4*originalWidth, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(cgContext, CGRectMake(0, 0, originalWidth, originalHeight), image);
    CGContextRelease(cgContext);
    CGImageRelease(image);
    unsigned char *pImageData = (unsigned char *)[imageData bytes];
    
    
    CFDictionaryRef empty;
    empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL,
                               0,
                               &kCFTypeDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks);
    
    CFMutableDictionaryRef m_pPixelBufferAttribs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                      3,
                                                      &kCFTypeDictionaryKeyCallBacks,
                                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(m_pPixelBufferAttribs, kCVPixelBufferIOSurfacePropertiesKey, empty);
    CFDictionarySetValue(m_pPixelBufferAttribs, kCVPixelBufferOpenGLCompatibilityKey, empty);
    CFDictionarySetValue(m_pPixelBufferAttribs, kCVPixelBufferCGBitmapContextCompatibilityKey, empty);
    
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, originalWidth, originalHeight, kCVPixelFormatType_32BGRA, pImageData, originalWidth * 4, NULL, NULL, m_pPixelBufferAttribs, &pxbuffer);
    CFRelease(empty);
    CFRelease(m_pPixelBufferAttribs);
    
    
    return pxbuffer;
}





@end
