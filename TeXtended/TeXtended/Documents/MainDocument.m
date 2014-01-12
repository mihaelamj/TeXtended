//
//  MainDocument.m
//  TeXtended
//
//  Created by Tobias Mende on 02.11.13.
//  Copyright (c) 2013 Tobias Mende. All rights reserved.
//

#import "MainDocument.h"
#import "Compilable.h"
#import "DocumentModel.h"
#import "DocumentController.h"
#import "MainWindowController.h"
#import "ExportCompileWindowController.h"
#import <TMTHelperCollection/TMTLog.h>
#import "TMTTabManager.h"
#import "ApplicationController.h"
#import "PrintDialogController.h"
#import "HighlightingTextView.h"

@implementation MainDocument

- (id)init
{
    self = [super init];
    if (self) {
            // Add your subclass-specific initialization here.
    }
    return self;
}


- (void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    if (!self.documentControllers || self.documentControllers.count == 0) {
        [self initializeDocumentControllers];
    }
    if ([windowController isKindOfClass:[MainWindowController class]]) {
        for(DocumentController *dc in self.documentControllers) {
            [self.mainWindowController showDocument:dc];
        }
    }
    
}

- (void)firstResponderDidChangeNotification:(NSNotification *)note {
    self.mainWindowController.myCurrentFirstResponderDelegate = (note.userInfo)[TMTFirstResponderKey];
}


- (void)saveEntireDocumentWithDelegate:(id)delegate andSelector:(SEL)action {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (Compilable *)model {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (BOOL)autosavesInPlace
{
    return YES;
    
}


- (void)initializeDocumentControllers {
    DDLogVerbose(@"initializeDocumentControllers (Count: %li)", self.model.mainDocuments.count);
    self.documentControllers = [NSMutableSet new];
    for (DocumentModel *m in self.model.mainDocuments) {
        [self.documentControllers addObject:[[DocumentController alloc] initWithDocument:m andMainDocument:self]];
    }
}

- (void)removeDocumentController:(DocumentController *)dc {
    self.mainWindowController.myCurrentFirstResponderDelegate = nil;
    [ApplicationController sharedApplicationController].currentFirstResponderDelegate = nil;
    [self.documentControllers removeObject:dc];
    if (self.documentControllers.count == 0) {
        [self close];
    }
}


- (void)makeWindowControllers {
    DDLogVerbose(@"makeWindowControllers");
    MainWindowController *mc = [[MainWindowController alloc] initForDocument:self];
    self.mainWindowController = mc;
    [self addWindowController:mc];
}

- (void)finalCompileForDocumentController:(DocumentController *)dc {
    if (!exportWindowController) {
        exportWindowController = [[ExportCompileWindowController alloc] initWithMainDocument:self];
    }
    exportWindowController.documentController = dc;
    [exportWindowController showWindow:nil];
}

- (void)printDocument:(id)sender
{
    [self showPrintDialog];
}

- (void)showPrintDialog
{
    if (!printDialogController) {
        printDialogController = [PrintDialogController new];
    }
    
    NSMutableArray *documentNames = [[NSMutableArray alloc] init];
    NSMutableArray *documentIdentifier = [[NSMutableArray alloc] init];
    for (DocumentController* dc in self.documentControllers) {
        if (dc.model.pdfName) {
            [documentNames addObject:dc.model.pdfName];
            [documentIdentifier addObject:dc.model.pdfIdentifier];
        }
        if (dc.model.texName) {
            [documentNames addObject:dc.model.texName];
            [documentIdentifier addObject:dc.model.texIdentifier];
        }
    }
    printDialogController.popUpElements = [NSArray arrayWithArray:documentNames];
    printDialogController.popUpIdentifier = [NSArray arrayWithArray:documentIdentifier];
    
    [NSApp beginSheet:[printDialogController window]
       modalForWindow: [self.mainWindowController window]
        modalDelegate: self
       didEndSelector: @selector(printDialogDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
    [NSApp runModalForWindow:[self.mainWindowController window]];
}

- (void)printDialogDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)context
{
    if (returnCode != NSRunAbortedResponse) {
        NSString* identifier = [printDialogController.popUpIdentifier objectAtIndex:printDialogController.documentName.indexOfSelectedItem];
        BOOL isPDF = [[identifier substringFromIndex:identifier.length-4] isEqualToString:@"-pdf"];
        
        if (isPDF) {
            NSTabViewItem *item = [[TMTTabManager sharedTabManager] tabViewItemForIdentifier:identifier];
            [item.tabView selectTabViewItem:item];
            [[item view] printDocument:nil];
        }
        else {
            for (DocumentController* dc in self.documentControllers) {
                if (dc.model.texIdentifier == identifier) {
                    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 468, 648)];
                    
                    
                    NSString *text = [NSString stringWithContentsOfFile:dc.model.texPath encoding:[dc.model.encoding unsignedLongValue] error:nil];
                    
                    [textView setEditable:true];
                    [textView insertText:text];

                    NSPrintOperation *printOperation;
                    
                    printOperation = [NSPrintOperation printOperationWithView:textView];
                    
                    [printOperation runOperation];
                    
                }
            }
        }
    }
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo
{
    // Nothing to do here...
}

- (IBAction)exportSingleDocument:(id)sender
{
    [NSException raise:@"exportSingleDocument not implemented." format:@"Yout have to implement exportSingleDocument in subclasses of MainDocument."];
}

- (void)openNewTabForCompilable:(DocumentModel*)model {
    for (DocumentController *dc in self.documentControllers) {
        if (dc.model == model) {
            NSTabViewItem *item = [[TMTTabManager sharedTabManager] tabViewItemForIdentifier:model.texIdentifier];
            if (item) {
                [item.tabView.window makeKeyAndOrderFront:self];
                [item.tabView selectTabViewItem:item];
            }
            [dc showPDFViews];
            [self.mainWindowController showDocument:dc];
            return;
        }
    }
    
    DocumentController *dc = [[DocumentController alloc] initWithDocument:model andMainDocument:self];
    [self.documentControllers addObject:dc];
    [self.mainWindowController showDocument:dc];
}

- (void)dealloc {
    for (DocumentController *dc in self.documentControllers) {
        dc.mainDocument = nil;
    }
}

@end
