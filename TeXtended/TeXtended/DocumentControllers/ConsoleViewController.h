//
//  ConsoleViewController.h
//  TeXtended
//
//  Created by Tobias Mende on 05.06.13.
//  Copyright (c) 2013 Tobias Mende. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DocumentControllerProtocol.h"

@class DocumentModel;

/**
 Viewcontroller for handling interaction with a single console view
 
 **Author:** Tobias Mende
 
 */
@interface ConsoleViewController : NSViewController <DocumentControllerProtocol,NSTextFieldDelegate> {
    /** A file handle for reading the console output */
    NSFileHandle *readHandle;
}

/** The input view for sending messages to the compiler */
@property (weak) IBOutlet NSTextField *inputView;

/** The parent controller according to the DocumentControllerProtocol. */
@property (weak) id<DocumentControllerProtocol> parent;

/** The document model to deal with in this view */
@property (weak,nonatomic) DocumentModel *model;

/** The output view for showing the compilers output to the user */
@property (unsafe_unretained) IBOutlet NSTextView *outputView;

/** Flag for showing whether the console is active or not */
@property BOOL consoleActive;

/** Method for handling the compilers output when new data arrives on the models output pipe
 
 @param notification the notification which was send.
 */
- (void) handleOutput: (NSNotification*)notification;
@end
