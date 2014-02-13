//
//  HighlightingTextView.m
//  SimpleSyntaxHighlightingTest
//
//  Created by Tobias Mende on 09.04.13.
//  Copyright (c) 2013 Tobias Mende. All rights reserved.
//

#import "HighlightingTextView.h"
#import "LatexSyntaxHighlighter.h"
#import "BracketHighlighter.h"
#import "CodeNavigationAssistant.h"
#import "NSString+LatexExtension.h"
#import "PlaceholderServices.h"
#import "EditorPlaceholder.h"
#import "Completion.h"
#import "EnvironmentCompletion.h"
#import "CompletionHandler.h"
#import "CodeExtensionEngine.h"
#import "UndoSupport.h"
#import "LineNumberView.h"
#import "GoToLineSheetController.h"
#import "AutoCompletionWindowController.h"
#import "MatrixViewController.h"
#import <TMTHelperCollection/TMTLog.h>
#import "TextViewLayoutManager.h"
#import "ApplicationController.h"
#import "TMTNotificationCenter.h"
#import "FirstResponderDelegate.h"
#import "CompletionProtocol.h"
#import "DBLPIntegrator.h"
#import "BibFile.h"
#import "QuickPreviewManager.h"
#import "CompletionManager.h"
#import "DocumentController.h"
#import "MainDocument.h"
#import "SimpleDocument.h"
#import "ProjectDocument.h"
#import "NSString+PathExtension.h"
#import "ProjectModel.h"
#import "NSString+TMTExtension.h"

static const double UPDATE_AFTER_SCROLL_DELAY = 1.0;
static const NSSet *DEFAULT_KEYS_TO_OBSERVE;
@interface HighlightingTextView()

/**
 Method for getting the new first range after swapping two ranges.
 
 @param first a random line range
 @param second another random line range
 
 @return the first range, if it was the first range before, the second otherwise.
 */
- (NSRange) firstRangeAfterSwapping:(NSRange)first and:(NSRange)second;

/** Method for swapping text in two ranges 
 
 @param first first range
 @param second second range
 
 */
- (void)swapTextIn:(NSRange)first and:(NSRange)second;

/** Method for setting up all user defaults observer */
- (void) registerUserDefaultsObserver;

/** Method for deleting all observations and bindings to the user defaults */
- (void) unregisterUserDefaultsObserver;

- (LineNumberView*) lineNumberView;

- (void) extendedComplete:(id)sender;

- (void) finalyUpdateTrackingAreas:(id)userInfo;

- (void) dismissCompletionWindow;

- (void) showDBLPSearchView;

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index additionalInformation:(NSDictionary **) info;
@end
@implementation HighlightingTextView

+ (void)initialize {
    if (self == [HighlightingTextView class]) {
        DEFAULT_KEYS_TO_OBSERVE = [NSSet setWithObjects:TMT_EDITOR_SELECTION_BACKGROUND_COLOR,TMT_EDITOR_SELECTION_FOREGROUND_COLOR,TMT_EDITOR_LINE_WRAP_MODE,TMT_EDITOR_HARD_WRAP_AFTER,TMT_REPLACE_INVISIBLE_SPACES, TMT_REPLACE_INVISIBLE_LINEBREAKS, TMTLineSpacing, nil];
    }
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    
    return self;
}

- (void)registerUserDefaultsObserver {
    for(NSString *key in DEFAULT_KEYS_TO_OBSERVE) {
         [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:[@"values." stringByAppendingString:key] options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:NULL];
    }
}

- (void)unregisterUserDefaultsObserver {
    for(NSString *key in DEFAULT_KEYS_TO_OBSERVE) {
        [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[@"values." stringByAppendingString:key]];
    }
}

- (void)awakeFromNib {
    
     NSDictionary *option = @{NSValueTransformerNameBindingOption: NSUnarchiveFromDataTransformerName};
    [self bind:@"textColor" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:TMT_EDITOR_FOREGROUND_COLOR] options:option];
    [self bind:@"backgroundColor" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:TMT_EDITOR_BACKGROUND_COLOR] options:option];
    
    
    _syntaxHighlighter = [[LatexSyntaxHighlighter alloc] initWithTextView:self];
    bracketHighlighter = [[BracketHighlighter alloc] initWithTextView:self];
    _codeNavigationAssistant = [[CodeNavigationAssistant alloc] initWithTextView:self];
    placeholderService = [[PlaceholderServices alloc] initWithTextView:self];
    completionHandler = [[CompletionHandler alloc] initWithTextView:self];
    _codeExtensionEngine = [[CodeExtensionEngine alloc] initWithTextView:self];
    _undoSupport = [[UndoSupport alloc] initWithTextView:self];
    if(self.string.length > 0) {
        [self.syntaxHighlighter highlightEntireDocument];
    }
    [self registerUserDefaultsObserver];
    [self setRichText:NO];
    [self setDisplaysLinkToolTips:YES];
    [self setHorizontallyResizable:YES];
    [self setVerticallyResizable:YES];
    [self setSmartInsertDeleteEnabled:NO];
    [self setAutomaticTextReplacementEnabled:NO];
    [self setAutomaticDashSubstitutionEnabled:NO];
    [self setAutomaticQuoteSubstitutionEnabled:NO];
    [self setUsesFontPanel:NO];
    self.servicesOn = YES;
    self.enableQuickPreviewAssistant = YES;
    
    
    [self.textContainer replaceLayoutManager:[TextViewLayoutManager new]];
    
}


- (NSRange) visibleRange
{
    NSRect visibleRect = [self visibleRect];
    NSLayoutManager *lm = [self layoutManager];
    NSTextContainer *tc = [self textContainer];
    
    NSRange glyphVisibleRange = [lm glyphRangeForBoundingRect:visibleRect inTextContainer:tc];;
    NSRange charVisibleRange = [lm characterRangeForGlyphRange:glyphVisibleRange  actualGlyphRange:nil];
    return charVisibleRange;
}


- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index additionalInformation:(NSDictionary **) info{
    if (!self.servicesOn) {
        return nil;
    }
    if ([completionHandler willHandleCompletionForPartialWordRange:charRange]) {
        [self.undoManager beginUndoGrouping];
        NSArray *completions =[completionHandler completionsForPartialWordRange:charRange indexOfSelectedItem:index additionalInformation:info];
        [self.undoManager endUndoGrouping];
        return completions;
    }
    return nil;
}

- (void)complete:(id)sender {
    [self extendedComplete:sender];
}

- (void)dismissCompletionWindow {
    [autoCompletionController.window orderOut:self];
    autoCompletionController = nil;
}


- (void)extendedComplete:(id)sender {
    if (!sender) {
        [self dismissCompletionWindow];
        if (self.selectedRange.length > 0) {
            [self deleteBackward:self];
        }
        return;
    }
    NSRange wordRange = [self rangeForUserCompletion];
    if (wordRange.location == NSNotFound) {
        return;
    }
    NSDictionary *additionalInformation;
    NSArray *completions = [self completionsForPartialWordRange:[self rangeForUserCompletion] indexOfSelectedItem:0 additionalInformation:&additionalInformation];
    if (completions.count > 0 || [additionalInformation[TMTShouldShowDBLPKey] boolValue]) {
        if (!autoCompletionController) {
            __unsafe_unretained id weakSelf = self;
            autoCompletionController = [[AutoCompletionWindowController alloc] initWithSelectionDidChangeCallback:^(id completion) {
                    [weakSelf insertCompletion:completion forPartialWordRange:[weakSelf rangeForUserCompletion] movement:NSOtherTextMovement isFinal:NO];
            }];
            autoCompletionController.parent = self;
        }
        [autoCompletionController positionWindowWithContent:completions andInformation:additionalInformation];
        if (completions.count > 0) {
            [self insertCompletion:completions[0] forPartialWordRange:wordRange movement:NSOtherTextMovement isFinal:NO];
        }
    } else {
        [self dismissCompletionWindow];
    }
}

- (NSRange)rangeForUserCompletion {
    __block NSRange range = NSMakeRange(NSNotFound, 0);
    NSRange lineRange = [self.string lineRangeForRange:self.selectedRange];
    if (NSMaxRange(lineRange) >= NSMaxRange(self.selectedRange) && lineRange.location <= self.selectedRange.location) {
        NSUInteger length = self.selectedRange.location - lineRange.location;
        NSRange searchRange = NSMakeRange(lineRange.location, length);
        [self.string enumerateSubstringsInRange:searchRange options:NSStringEnumerationByWords|NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            if (NSMaxRange(substringRange) == self.selectedRange.location) {
                range = substringRange;
            }
            *stop = YES;
        }];
    }
    return range;
}

- (LineNumberView *)lineNumberView {
    if ([self.enclosingScrollView.verticalRulerView isKindOfClass:[LineNumberView class]]) {
        return (LineNumberView *)self.enclosingScrollView.verticalRulerView;
    }
    return nil;
    
}

- (void)insertCompletion:(id<CompletionProtocol>)word forPartialWordRange:(NSRange)charRange movement:(NSInteger)movement isFinal:(BOOL)flag {
    if (!self.servicesOn) {
        return;
    }
    [completionHandler insertCompletion:word forPartialWordRange:charRange movement:movement isFinal:flag];
    if (flag || movement == NSCancelTextMovement || movement == NSLeftTextMovement) {
        [self dismissCompletionWindow];
    }
    
    
}

-(void)insertDropCompletionForModel:(DocumentModel*)model {
    NSString *base = model.texPath ? [model.texPath stringByDeletingLastPathComponent] : nil;
    for (NSUInteger i = 0; i < [droppedFileNames count]; i++) {
        
        NSString *filename = [droppedFileNames objectAtIndex:i];
        NSString *path = base ? [filename relativePathWithBase:base] : filename;
        NSAttributedString *insertion = [[CompletionManager sharedInstance] getDropCompletionForPath:path];
        
        [self insertText:[completionHandler expandWhiteSpacesInAttrString:insertion]];
        
        if ([droppedFileNames count] > i+1) {
            [self insertNewline:self];
        }
    }
    
    [self jumpToNextPlaceholder];
    
    // After drop operation the first responder remains the drag source
    [[self window]makeFirstResponder:self];
}

-(void)insertDropCompletionForPath:(NSString*)path {
    for (NSUInteger i = 0; i < [droppedFileNames count]; i++) {
        
        NSString *filename = [droppedFileNames objectAtIndex:i];
        
        NSAttributedString *insertion = [[CompletionManager sharedInstance] getDropCompletionForPath:[filename relativePathWithBase:[path stringByDeletingLastPathComponent]]];
        
        [self insertText:[completionHandler expandWhiteSpacesInAttrString:insertion]];
        
        if ([droppedFileNames count] > i+1) {
            [self insertNewline:self];
        }
    }
    
    [self jumpToNextPlaceholder];
    
    // After drop operation the first responder remains the drag source
    [[self window]makeFirstResponder:self];
}

- (void)flagsChanged:(NSEvent *)theEvent {
    [super flagsChanged:theEvent];
    self.currentModifierFlags = theEvent.modifierFlags;
}

- (void)insertFinalCompletion:(id<CompletionProtocol>)word forPartialWordRange:(NSRange)charRange movement:(NSInteger)movement isFinal:(BOOL)flag {
    if (movement == NSCancelTextMovement || movement == NSLeftTextMovement) {
        [self delete:nil];
        [self dismissCompletionWindow];
        return;
    }
    [super insertCompletion:word.autoCompletionWord forPartialWordRange:charRange movement:movement isFinal:flag];
}

- (void)jumpToNextPlaceholder {
    if (!self.servicesOn) {
        return;
    }
    [placeholderService handleInsertTab];
}

- (void)jumpToPreviousPlaceholder {
    if (!self.servicesOn) {
        return;
    }
    [placeholderService handleInsertBacktab];
}

- (void)updateTrackingAreas {
    if (scrollTimer) {
        [scrollTimer invalidate];
    }
    scrollTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_AFTER_SCROLL_DELAY target:self selector:@selector(finalyUpdateTrackingAreas:) userInfo:nil repeats:NO];
    
}

- (void)finalyUpdateTrackingAreas:(id)userInfo {
    [super updateTrackingAreas];

}


- (void)updateSyntaxHighlighting {
    if (!self.servicesOn) {
        return;
    }
    [self.syntaxHighlighter highlightRange:[self extendedVisibleRange]];
}



- (NSRange) extendRange:(NSRange)range byLines:(NSUInteger)numLines {
    for (NSUInteger iteration = 0; iteration < numLines; iteration++) {
        BOOL update = NO;
        if (range.location >0) {
            range.location -= 1;
            range.length +=1;
            update = YES;
        }
        if (NSMaxRange(range) < self.string.length-1 && NSMaxRange(range) >0) {
            range.length += 1;
            update = YES;
        }
        if (update) {
            range = [self.codeNavigationAssistant lineTextRangeWithRange:range withLineTerminator:YES];
        } else {
            break;
        }
    }
    return range;
}

- (NSRange) extendedVisibleRange {
    NSRange range = [self.codeNavigationAssistant lineTextRangeWithRange:self.visibleRange withLineTerminator:YES];
    
    return [self extendRange:range byLines:5];
    
}

- (void)insertText:(id)str {
    if (!self.servicesOn) {
        [super insertText:str];
        return;
    }
    if (![completionHandler shouldCompleteForInsertion:str]) {
        [self dismissCompletionWindow];
    }
    if (![bracketHighlighter shouldInsert:str]) {
        return;
    }
    [super insertText:str];
    if ([str isKindOfClass:[NSAttributedString class]]) {
        return;
    }
    NSUInteger position = [self selectedRange].location;
    // Some services should not run if a latex linebreak occures befor the current position
    if (![self.string latexLineBreakPreceedingPosition:position]) {
        if ([completionHandler shouldCompleteForInsertion:str]) {
            [self complete:self];
        }
    } else {
        DDLogInfo(@"Latex LineBreak");
    }
    [bracketHighlighter handleBracketsOnInsertWithInsertion:str];
    NSRange lineRange = [self.string lineRangeForRange:self.selectedRange];
    [self.codeNavigationAssistant lineTextRangeWithRange:self.selectedRange];
    if([self.codeNavigationAssistant handleWrappingInLine:lineRange]) {
        [self scrollRangeToVisible:self.selectedRange];
    }

}

- (void)goToLine:(id)sender {
    if (!goToLineSheet) {
        goToLineSheet = [[GoToLineSheetController alloc] init];
    }
    goToLineSheet.line = [NSNumber numberWithInteger:self.currentRow];
    goToLineSheet.max = [NSNumber numberWithInteger:self.string.numberOfLines];
    [NSApp beginSheet:[goToLineSheet window]
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
    [NSApp runModalForWindow:[self window]];
}

- (IBAction)matrixView:(id)sender {
    if (!matrixView) {
        matrixView = [[MatrixViewController alloc] init];
    }
    [NSApp beginSheet:[matrixView window]
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(matrixSheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
    [NSApp runModalForWindow:[self window]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)context {
    if (returnCode == NSRunStoppedResponse) {
        [self showLine:[goToLineSheet.line integerValue]];
    }
}

- (void)matrixSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)context {
    if (returnCode == NSRunStoppedResponse) {
        [self.undoManager beginUndoGrouping];
        EnvironmentCompletion *completion = [matrixView matrixCompletion];
        [completionHandler insertEnvironmentCompletion:completion forPartialWordRange:self.selectedRange movement:NSReturnTextMovement isFinal:YES];
        [self.undoManager endUndoGrouping];
    }
}

- (void)showLine:(NSUInteger)line {
    [self.window makeKeyAndOrderFront:self];
    if (line <= self.string.numberOfLines && line > 0) {
    NSRange lineRange = [self.string rangeForLine:line-1];
        [self scrollRangeToVisible:lineRange];
        [self setSelectedRange:lineRange];
    } else {
        NSBeep();
    }
    
}

- (NSRange)rangeForLine:(NSUInteger)index {
    return [self.string rangeForLine:index-1];
}


- (void)insertTab:(id)sender {
    if (!self.servicesOn) {
        [super insertTab:sender];
        return;
    }
    if (autoCompletionController) {
        NSInteger index = (autoCompletionController.tableView.selectedRow >= 0 ? autoCompletionController.tableView.selectedRow : 0);
        [self insertCompletion:(autoCompletionController.content)[index] forPartialWordRange:[self rangeForUserCompletion] movement:NSTabTextMovement isFinal:YES];
    }else if ( ![placeholderService handleInsertTab] && ![self.codeNavigationAssistant handleTabInsertion]) {
        [super insertTab:sender];
    } 
    
}


- (void)insertBacktab:(id)sender {
    if (!self.servicesOn) {
         [super insertBacktab:sender];
        return;
    }
    if (![placeholderService handleInsertBacktab] && ![self.codeNavigationAssistant handleBacktabInsertion]) {
        [super insertBacktab:sender];
    }
}

- (void)insertNewline:(id)sender {
    if (!self.servicesOn) {
        [super insertNewline:sender];
        return;
    }
    [self.codeNavigationAssistant handleNewLineInsertion];
}

- (void)paste:(id)sender {
    [super paste:sender];
    if (!self.servicesOn) {
        return;
    }
    [self.syntaxHighlighter highlightEntireDocument];
    [self.codeExtensionEngine addLinksForRange:NSMakeRange(0, self.string.length)];
}

-(void)setString:(NSString *)string {
    [super setString:string];
    if (!self.servicesOn) {
        return;
    }
    [self.syntaxHighlighter highlightEntireDocument];
}

-(void)showMainDocumentsWindow:(NSArray*)mainDocuments {
    if (!autoCompletionController) {
        autoCompletionController = [[AutoCompletionWindowController alloc] initWithSelectionDidChangeCallback:nil];
        autoCompletionController.parent = self;
    }
    
    NSMutableArray *dictionaryArray = [NSMutableArray new];
    
    for (NSString* path in mainDocuments) {
        [dictionaryArray addObject:@{@"key":path}];
    }
    
    [[self window] makeFirstResponder:self];
    [autoCompletionController positionWindowWithContent:dictionaryArray andInformation:@{TMTDropCompletionKey: @YES}];
}


#pragma mark -
#pragma mark Setter & Getter

- (void)setLineWrapMode:(TMTLineWrappingMode)lineWrapMode {
    _lineWrapMode = lineWrapMode;
    
        if (lineWrapMode == SoftWrap) {
            [[self textContainer] setWidthTracksTextView:YES];
            [self setMaxSize:NSMakeSize(self.superview.visibleRect.size.width, FLT_MAX)];
            [self.textContainer setContainerSize:NSMakeSize(self.superview.visibleRect.size.width, FLT_MAX)];
        } else {
            [[self textContainer]
             setContainerSize:NSMakeSize(FLT_MAX   , FLT_MAX)];
            [[self textContainer] setWidthTracksTextView:NO];
            [self setAutoresizingMask:NSViewNotSizable];
            [self setMaxSize:NSMakeSize(FLT_MAX,
                                        FLT_MAX)];
            
        }
}


- (NSUInteger)currentCol {
    return [self colForRange:self.selectedRange];
}

- (NSUInteger)colForRange:(NSRange)range {
    NSUInteger location = 0;
    
    NSRange window = NSMakeRange(range.location, 1);
    while (window.location > 0 && NSMaxRange(window) < self.string.length) {
        if ([[self.string substringWithRange:window] isEqualToString:@"\n"]) {
            return location;
        } else {
            location ++;
            window.location --;
        }
    }
    return location;
}


#pragma mark -
#pragma mark Input Actions

- (void)selectCurrentBlock:(id)sender {
    NSRange blockRange = [self.string blockRangeForPosition:self.selectedRange.location];
    if (blockRange.location != NSNotFound) {
        self.selectedRange = blockRange;
    } else {
        NSBeep();
    }
}

- (void)gotoBlockBegin:(id)sender {
    NSRange beginRange = [self.string beginRangeForPosition:self.selectedRange.location];
    if (beginRange.location != NSNotFound) {
        self.selectedRange = NSMakeRange(NSMaxRange(beginRange), 0);
    } else {
        NSBeep();
    }
}

- (void)gotoBlockEnd:(id)sender {
    NSRange endRange = [self.string endRangeForPosition:self.selectedRange.location];
    if (endRange.location != NSNotFound) {
        self.selectedRange = NSMakeRange(endRange.location, 0);
    } else {
        NSBeep();
    }
}

- (void)moveLeft:(id)sender {
    [super moveLeft:sender];
    [self dismissCompletionWindow];
    if (!self.servicesOn) {
        return;
    }
    [bracketHighlighter highlightOnMoveLeft];
    
    
}

- (void)moveRight:(id)sender {
    [super moveRight:sender];
    [self dismissCompletionWindow];
    if (!self.servicesOn) {
        return;
    }
    [bracketHighlighter highlightOnMoveRight];
}


- (void)keyDown:(NSEvent *)theEvent {
    if (autoCompletionController) {
        switch (theEvent.keyCode) {
            case TMTArrowDownKeyCode:
                [autoCompletionController arrowDown];
                return;
            case TMTArrowUpKeyCode:
                [autoCompletionController arrowUp];
                return;
            case TMTBackKeyCode:
                [self dismissCompletionWindow];
                break;
            case TMTReturnKeyCode: { // Brackets are needed here due to compiler issues
                if (autoCompletionController.tableView.selectedRow >= autoCompletionController.content.count) {
                    if ([(autoCompletionController.additionalInformation)[TMTShouldShowDBLPKey] boolValue]) {
                        [self showDBLPSearchView];
                    }
                } else {
                    NSUInteger index = (autoCompletionController.tableView.selectedRow >= 0 ? autoCompletionController.tableView.selectedRow : 0);
                    
                    if ([(autoCompletionController.additionalInformation)[TMTDropCompletionKey] boolValue]) {
                        NSDictionary* pathDioctionary = (autoCompletionController.content)[index];
                        NSString* path = [[self.firstResponderDelegate.model.project.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[pathDioctionary objectForKey:@"key"]];
                        [self insertDropCompletionForPath:path];
                        [self dismissCompletionWindow];
                    }
                    else {
                        [self insertCompletion:(autoCompletionController.content)[index] forPartialWordRange:[self rangeForUserCompletion] movement:NSReturnTextMovement isFinal:YES];
                    }
                }
                return;
            }
            default:
                break;
        }
        
    }
    
    if (theEvent.keyCode == TMTTabKeyCode && theEvent.modifierFlags&NSAlternateKeyMask) {
        if (theEvent.modifierFlags & NSShiftKeyMask) {
            [self.codeNavigationAssistant handleBacktabInsertion];
        } else {
            [self.codeNavigationAssistant handleTabInsertion];
        }
    } else {
        [super keyDown:theEvent];
    }
    
    if (!self.servicesOn) {
        return;
    }
    [self.codeNavigationAssistant highlightCarret];
}


- (void)showDBLPSearchView {
    [self dismissCompletionWindow];
    if (!dblpIntegrator) {
        dblpIntegrator = [[DBLPIntegrator alloc] initWithTextView:self];
    }
    [dblpIntegrator initializeDBLPView];
}

- (void)showQuickPreviewAssistant:(id)sender {
    if (!quickPreview) {
        quickPreview = [[QuickPreviewManager alloc] initWithParentView:self];
    }
    [quickPreview showWindow:self];
}


- (void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    if (!self.servicesOn) {
        return;
    }
    if (autoCompletionController) {
        [autoCompletionController close];
        autoCompletionController = nil;
    }
    [self.codeNavigationAssistant highlightCarret];
    if (self.selectedRanges.count== 1 || self.selectedRange.length==0) {
        NSUInteger position = self.selectedRange.location;
        [self.codeExtensionEngine handleLinkAt:position];
    }
    
}

- (void)hardWrapText:(id)sender {
    
    TMTLineWrappingMode current = self.lineWrapMode;
    self.lineWrapMode = HardWrap;
    [self.codeNavigationAssistant handleWrappingInRange:NSMakeRange(0, self.string.length)];
    self.lineWrapMode = current;
    
}

- (IBAction)deleteLines:(id)sender {
    if (self.selectedRanges.count != 1) {
        return;
    }
    NSRange totalRange = [self.codeNavigationAssistant lineTextRangeWithRange:self.selectedRange withLineTerminator:YES];

    [self.undoSupport deleteTextInRange:[NSValue valueWithRange:totalRange] withActionName:NSLocalizedString(@"Delete Lines", @"line deletion")];


}

- (IBAction)moveLinesDown:(id)sender {
    if (self.selectedRanges.count != 1) {
        return;
    }
    NSRange totalRange = [self.codeNavigationAssistant lineTextRangeWithRange:self.selectedRange];
    if(NSMaxRange(totalRange) < self.string.length) {
        NSString *actionName = NSLocalizedString(@"Move Lines", @"moving lines");
        NSRange nextLine = [self.codeNavigationAssistant lineTextRangeWithRange:NSMakeRange(NSMaxRange(totalRange)+1, 0)];
        [self.undoManager beginUndoGrouping];
        [self swapTextIn:totalRange and:nextLine];
        [self setSelectedRange:[self firstRangeAfterSwapping:totalRange and:nextLine]];
        [self.undoManager setActionName:actionName];
        [self.undoManager endUndoGrouping];
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(moveLinesUp:)) {
        NSRange totalRange = [self.codeNavigationAssistant lineTextRangeWithRange:self.selectedRange];
        if (totalRange.location == 0) {
            return NO;
        } else {
            return YES;
        }
    } else if(aSelector == @selector(moveLinesDown:)) {
        NSRange totalRange = [self.codeNavigationAssistant lineTextRangeWithRange:self.selectedRange];
        if(NSMaxRange(totalRange) < self.string.length) {
            return YES;
        } else {
            return NO;
        }
    } else if (aSelector == @selector(commentSelection:) || aSelector == @selector(uncommentSelection:) || aSelector == @selector(toggleComment:)) {
        return self.selectedRanges.count == 1;
    } else if (aSelector == @selector(jumpNextAnchor:) || aSelector == @selector(jumpPreviousAnchor:)) {
        if (self.lineNumberView && self.lineNumberView.anchoredLines.count > 0) {
            return YES;
        } else {
            return NO;
        }
    }else if(aSelector == @selector(showQuickPreviewAssistant:)) {
        return  self.enableQuickPreviewAssistant && self.firstResponderDelegate.model.texPath && self.firstResponderDelegate.model.texPath.length > 0;
    } else {
        return [super respondsToSelector:aSelector] || (self.firstResponderDelegate && [self.firstResponderDelegate respondsToSelector:aSelector]);
    }
}


- (IBAction)moveLinesUp:(id)sender {
    if (self.selectedRanges.count != 1) {
        return;
    }
    NSRange totalRange = [self.codeNavigationAssistant lineTextRangeWithRange:self.selectedRange];
    if(totalRange.location > 0) {
        NSString *actionName = NSLocalizedString(@"Move Lines", @"moving lines");
        NSRange lineBefore = [self.codeNavigationAssistant lineTextRangeWithRange:NSMakeRange(totalRange.location-1, 0)];
        [self.undoManager beginUndoGrouping];
        [self swapTextIn:lineBefore and:totalRange];
        [self setSelectedRange:NSMakeRange(lineBefore.location, totalRange.length)];
        [self.undoManager setActionName:actionName];
        [self.undoManager endUndoGrouping];
    }
}
- (NSRange) firstRangeAfterSwapping:(NSRange)first and:(NSRange)second {
    if (second.length > first.length) {
        NSUInteger lengthDif = second.length - first.length;
        first.location = second.location + lengthDif;
        return first;
    } else if (first.length > second.length) {
        NSUInteger lengthDif = first.length-second.length;
        first.location = second.location -lengthDif;
        return first;
    }
    return second;
}

- (void)swapTextIn:(NSRange)first and:(NSRange)second {
    if (first.location > second.location) {
        // Ensure that first range ist before second range
        NSRange tmp = first;
        first = second;
        second = tmp;
    }

    NSAttributedString *secondStr;
    if (second.length == 0) {
        NSUInteger pos = second.location > 0 ? second.location -1 : 0;
        NSDictionary *attr = [self.textStorage attributesAtIndex:pos effectiveRange:NULL];
        secondStr = [[NSAttributedString alloc] initWithString:@"" attributes:attr];
    } else {
        
        secondStr = [self.textStorage attributedSubstringFromRange:second];
    }
    NSAttributedString *firstStr;
    if (first.length == 0) {
        NSUInteger pos = first.location > 0 ? first.location -1 : 0;
        NSDictionary *attr = [self.textStorage attributesAtIndex:pos effectiveRange:NULL];
        firstStr = [[NSAttributedString alloc] initWithString:@"" attributes:attr];
    } else {
        
        firstStr = [self.textStorage attributedSubstringFromRange:first];
    }
    if (first.length == 0) {
        [self.undoSupport deleteTextInRange:[NSValue valueWithRange:second] withActionName:@""];
    } else {
        [self insertText:firstStr replacementRange:second];
    }
    if (second.length == 0) {
        [self.undoSupport deleteTextInRange:[NSValue valueWithRange:first] withActionName:@""];
    } else {
        [self insertText:secondStr replacementRange:first];
    }

}



- (void)commentSelection:(id)sender {
    [self.codeNavigationAssistant commentSelectionInRange:self.selectedRange];
}

- (void)uncommentSelection:(id)sender {
    [self.codeNavigationAssistant uncommentSelectionInRange:self.selectedRange];
}

- (void)toggleComment:(id)sender {
    [self.codeNavigationAssistant toggleCommentInRange:self.selectedRange];
}

- (void)jumpNextAnchor:(id)sender {
    NSUInteger current = [self currentRow];
    NSArray *anchors = self.lineNumberView.anchoredLines;
    anchors = [anchors sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger nextLine = NSNotFound;
    for (NSNumber *line in anchors) {
        if (nextLine == NSNotFound) {
            nextLine = line.integerValue;
        }
        if (line.integerValue > current) {
            nextLine = line.integerValue;
            break;
        }
    }
    [self showLine:nextLine];
}

- (void)jumpPreviousAnchor:(id)sender {
    NSUInteger current = [self currentRow];
    NSArray *anchors = self.lineNumberView.anchoredLines;
    anchors = [anchors sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger nextLine = NSNotFound;
    for (NSNumber *line in [anchors reverseObjectEnumerator]) {
        if (nextLine == NSNotFound) {
            nextLine = line.integerValue;
        }
        if (line.integerValue < current) {
            nextLine = line.integerValue;
            break;
        }
    }
    [self showLine:nextLine];
}

#pragma mark -
#pragma mark Drag & Drop

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    
    NSPasteboard *pb = [sender draggingPasteboard];
    NSDragOperation dragOperation = [sender draggingSourceOperationMask];
    
    if ([[pb types] containsObject:NSFilenamesPboardType]) {
        if (dragOperation & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    if ([[pb types] containsObject:NSPasteboardTypeString]) {
        if (dragOperation & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
    
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    
    NSPasteboard *pb = [sender draggingPasteboard];

    if ( [[pb types] containsObject:NSFilenamesPboardType] ) {
        
        NSPoint draggingLocation = [sender draggingLocation];
        draggingLocation = [self convertPoint:draggingLocation fromView:nil];
        NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
        [self setSelectedRange:NSMakeRange(characterIndex, 0)];
        
        droppedFileNames = [pb propertyListForType:NSFilenamesPboardType];
        
        DocumentModel *model = self.firstResponderDelegate.model;

        if (model.mainDocuments.count > 1) {
            NSMutableArray* mainDocumentNames = [[NSMutableArray alloc] init];
            NSMutableSet* dirs = [[NSMutableSet alloc] init];
            for (DocumentModel *temp in model.mainDocuments) {
                [dirs addObject:[[temp.path stringByDeletingLastPathComponent] relativePathWithBase:[temp.project.path stringByDeletingLastPathComponent]]];
                NSString *str = [NSString stringWithFormat:NSLocalizedString(@"Relative path to %@", @"Relativ to prefix"), [temp.path relativePathWithBase:[temp.project.path stringByDeletingLastPathComponent]]];
                [mainDocumentNames addObject:str];
            }
            if ([dirs count] > 1) {
                [self showMainDocumentsWindow:mainDocumentNames];
            }
            else {
                [self insertDropCompletionForModel:[model.mainDocuments firstObject]];
            }
        } else if (model.mainDocuments.count == 1) {
            [self insertDropCompletionForModel:[model.mainDocuments firstObject]];
        }
        
    }
    
    else {
        return [super performDragOperation:sender];
    }
    
    return YES;
    
}

- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
    NSUInteger glyphIndex;
    NSLayoutManager *layoutManager = [self layoutManager];
    CGFloat fraction;
    NSRange range;
    
    range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
    aPoint.x -= [self textContainerOrigin].x;
    aPoint.y -= [self textContainerOrigin].y;
    glyphIndex = [layoutManager glyphIndexForPoint:aPoint
                                   inTextContainer:[self textContainer]
                    fractionOfDistanceThroughGlyph:&fraction];
    
    if( glyphIndex == NSMaxRange(range)-1 ) return  [[self textStorage]
                                                   length];
    else return [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    
}

#pragma mark -
#pragma mark Drawing Actions

- (void) drawViewBackgroundInRect:(NSRect)rect
{
    [super drawViewBackgroundInRect:rect];
    if (self.servicesOn) {
        [self.codeNavigationAssistant highlightCurrentLine];
    }

}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:[@"values." stringByAppendingString:TMT_EDITOR_SELECTION_FOREGROUND_COLOR]] || [keyPath isEqualToString:[@"values." stringByAppendingString:TMT_EDITOR_SELECTION_BACKGROUND_COLOR]]) {
        NSColor *textColor = [NSUnarchiver unarchiveObjectWithData:[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKeyPath:TMT_EDITOR_SELECTION_FOREGROUND_COLOR]];
        NSColor *backgroundColor = [NSUnarchiver unarchiveObjectWithData:[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKeyPath:TMT_EDITOR_SELECTION_BACKGROUND_COLOR]];
        NSDictionary *selectionAttributes = @{NSForegroundColorAttributeName: textColor,NSBackgroundColorAttributeName: backgroundColor};
        [self setSelectedTextAttributes:selectionAttributes];
    } else if([keyPath isEqualToString:[@"values." stringByAppendingString:TMT_EDITOR_LINE_WRAP_MODE]]) {
        self.lineWrapMode = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKeyPath:TMT_EDITOR_LINE_WRAP_MODE] intValue];
    } else if ([keyPath isEqualToString:[@"values." stringByAppendingString:TMT_EDITOR_HARD_WRAP_AFTER]]) {
        self.hardWrapAfter = [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKeyPath:TMT_EDITOR_HARD_WRAP_AFTER];
    } else if ([keyPath isEqualToString:[@"values." stringByAppendingString:TMT_REPLACE_INVISIBLE_SPACES]]) {
        [self setNeedsDisplay:YES];
    } else if ([keyPath isEqualToString:[@"values." stringByAppendingString:TMT_REPLACE_INVISIBLE_LINEBREAKS]]) {
        [self setNeedsDisplay:YES];
    } else if ([keyPath isEqualToString:[@"values." stringByAppendingString:TMTLineSpacing]]) {
        NSMutableParagraphStyle *ps = self.typingAttributes[NSParagraphStyleAttributeName];
        if (!ps) {
            ps = [NSMutableParagraphStyle new];
        }
        CGFloat spacing = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKeyPath:TMTLineSpacing] floatValue];
         ps.paragraphSpacing = spacing;
        [self.textStorage addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, self.string.length)];
        NSMutableDictionary *typingAttributes = [self.typingAttributes mutableCopy];
        typingAttributes[NSParagraphStyleAttributeName] = ps;
        self.typingAttributes = typingAttributes;
    }
}

- (BOOL)resignFirstResponder {
    BOOL result = [super resignFirstResponder];
    if (result && autoCompletionController) {
        if (self.selectedRange.length>0) {
            [self delete:self];
        }
        [self dismissCompletionWindow];
    }
    return result;
}


-(void)dealloc {
    DDLogVerbose(@"dealloc");
    [self unregisterUserDefaultsObserver];
  
}

# pragma mark - First Responder Chain

- (id)performSelector:(SEL)aSelector withObject:(id)object {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([super respondsToSelector:aSelector]) {
        [super performSelector:aSelector withObject:object];
    } else if(self.firstResponderDelegate && [self.firstResponderDelegate respondsToSelector:aSelector]) {
        [self.firstResponderDelegate performSelector:aSelector withObject:object];
    }
#pragma clang diagnostic pop
    return nil;
}


- (BOOL)canBecomeKeyView {
    DDLogInfo(@"Become KeyView: %@", self.firstResponderDelegate);
    return [super canBecomeKeyView];
}

- (BOOL)becomeFirstResponder {
    [self makeKeyView];
    return [super becomeFirstResponder];
}

- (void)makeKeyView {
    if (self.firstResponderDelegate) {
        [[TMTNotificationCenter centerForCompilable:self.firstResponderDelegate.model] postNotificationName:TMTFirstResponderDelegateChangeNotification object:nil userInfo:@{TMTFirstResponderKey: self.firstResponderDelegate}];
        [[NSNotificationCenter defaultCenter] postNotificationName:TMTFirstResponderDelegateChangeNotification object:nil userInfo:@{TMTFirstResponderKey: self.firstResponderDelegate}];
    }
}


@end
