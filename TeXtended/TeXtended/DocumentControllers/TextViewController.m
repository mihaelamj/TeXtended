//
//  TextViewController.m
//  TeXtended
//
//  Created by Tobias Mende on 26.05.13.
//  Copyright (c) 2013 Tobias Mende. All rights reserved.
//

#import "TextViewController.h"
#import "LineNumberView.h"
#import "HighlightingTextView.h"
#import "CodeNavigationAssistant.h"
#import "DocumentController.h"
#import "Constants.h"
#import "DocumentModel.h"
#import "ForwardSynctex.h"
@interface TextViewController ()
/** Method for handling the initial setup of this object */
- (void) initialize;

/** Method for handling the and of a compiler task
 
 @param note the TMTCompilerDidEndCompiling notification
*/
- (void) handleCompilerEnd:(NSNotification *)note;

/** Method for setting up the model observations */
- (void) registerModelObserver;

/** Method for unregistering this object as model observer */
- (void) unregisterModelObserver;

/** Method for syncing the pdf output with the HighlightingTextView
 
 @param model the model to sync for
 */
- (void) syncPDF:(DocumentModel *)model;
@end

@implementation TextViewController


- (id)initWithParent:(id<DocumentControllerProtocol>)parent {
    self = [super initWithNibName:@"TextView" bundle:nil];
    if (self) {
        self.parent = parent;
        observers = [NSMutableSet new];
        self.model = [[self.parent documentController] model];
        [self bind:@"liveScrolling" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:TMTDocumentEnableLiveScrolling] options:NULL];
        [self registerModelObserver];
    }
    return self;
}

- (void)registerModelObserver {
    [self.model addObserver:self forKeyPath:@"mainDocuments" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
    for (DocumentModel *m in self.model.mainDocuments) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCompilerEnd:) name:TMTCompilerDidEndCompiling object:m];
    }
}

- (void)unregisterModelObserver {
    [self.model removeObserver:self forKeyPath:@"mainDocuments"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TMTCompilerDidEndCompiling object:nil];
}

- (void)handleCompilerEnd:(NSNotification *)note {
    DocumentModel *m = [note object];
    if (![self.model.mainDocuments containsObject:m]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:TMTCompilerDidEndCompiling object:m];
        return;
    }
ForwardSynctex *synctex = [[ForwardSynctex alloc] initWithInputPath:self.model.texPath outputPath:m.pdfPath row:self.textView.currentRow andColumn:self.textView.currentCol];
NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:synctex,TMTForwardSynctexKey, nil];
[[NSNotificationCenter defaultCenter] postNotificationName:TMTCompilerSynctexChanged object:m userInfo:info];
}

- (void)loadView {
    [super loadView];
    [self initialize];
    [self.textView addObserver:self forKeyPath:@"currentRow" options:NSKeyValueObservingOptionNew context:NULL];
    
}

- (void)initialize {
    lineNumberView = [[LineNumberView alloc] initWithScrollView:[self scrollView]];
    [self.scrollView setVerticalRulerView:lineNumberView];
    [self.scrollView setHasHorizontalRuler:NO];
    [self.scrollView setHasVerticalRuler:YES];
    [self.scrollView setRulersVisible:YES];
}


- (NSString *)content {
    return [self.textView string];
}

- (void)setContent:(NSString *)content {
    [self.textView setString:content];
}

- (NSSet *)children {
    return [NSSet setWithObject:nil];
}

- (void) documentModelHasChangedAction : (DocumentController*) controller {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TMTCompilerDidEndCompiling object:nil];
    for (DocumentModel *m in self.model.mainDocuments) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCompilerEnd:) name:TMTCompilerDidEndCompiling object:m];
    }
    //TODO: reload file path?
}


- (void)syncPDF:(DocumentModel *)model {
    if (model) {
        ForwardSynctex *synctex = [[ForwardSynctex alloc] initWithInputPath:self.model.texPath outputPath:model.pdfPath row:self.textView.currentRow andColumn:self.textView.currentCol];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:synctex,TMTForwardSynctexKey, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:TMTCompilerSynctexChanged object:model userInfo:info];
    } else {
        for (DocumentModel *m in self.model.mainDocuments) {
            ForwardSynctex *synctex = [[ForwardSynctex alloc] initWithInputPath:self.model.texPath outputPath:m.pdfPath row:self.textView.currentRow andColumn:self.textView.currentCol];
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:synctex,TMTForwardSynctexKey, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:TMTCompilerSynctexChanged object:m userInfo:info];
        }
    }
}

- (void)goToLine:(id)sender {
    NSLog(@"Go to line");
}

- (void) documentHasChangedAction {
}

- (void)breakUndoCoalescing {
    [self.textView breakUndoCoalescing];
}

- (DocumentController *)documentController {
    return [self.parent documentController];
}


#pragma mark -
#pragma mark Observers

- (void)addObserver:(id<TextViewObserver>)observer {
    [observers addObject:observer];
}

- (void)removeDelegateObserver:(id<TextViewObserver>)observer {
    [observers removeObject:observer];
}

#pragma mark -
#pragma mark Delegate Methods


- (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange{
    if (self.textView.servicesOn) {
        [self.textView.codeNavigationAssistant highlightCurrentLineForegroundWithRange:newSelectedCharRange];
        
    }
    return newSelectedCharRange;
}


- (void)textViewDidChangeSelection:(NSNotification *)notification {
    [self.scrollView.verticalRulerView setNeedsDisplay:YES];
    
}

- (void)textDidChange:(NSNotification *)notification {
    [observers makeObjectsPerformSelector:@selector(textDidChange:) withObject:notification];
}




- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqualTo:self.model] && self.model.faultingState >0) {
        [self unregisterModelObserver];
        if ([keyPath isEqualToString:@"mainDocuments"]) {
            [self registerModelObserver];
        }
    } else if([keyPath isEqualToString:@"currentRow"] && [object isEqualTo:self.textView]) {
        if (self.liveScrolling) {
            [self performSelectorInBackground:@selector(syncPDF:) withObject:nil];
        }
    }
}


#pragma mark -
#pragma mark Dealloc

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"TextViewController dealloc");
#endif
    [self unbind:@"liveScrolling"];
    [self.textView removeObserver:self forKeyPath:@"currentRow"];
    [self unregisterModelObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
