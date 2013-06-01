//
//  PDFViewController.h
//  TeXtended
//
//  Created by Max Bannach on 01.06.13.
//  Copyright (c) 2013 Tobias Mende. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DocumentControllerProtocol.h"
#import "ExtendedPdf.h"

@interface ExtendedPDFViewController : NSViewController<DocumentControllerProtocol>

@property (assign) NSString * pdfPath;
@property (strong) id<DocumentControllerProtocol> parent;
@property (strong) ExtendedPdf* pdfView;

/**
 * Returns the name / title of the loaded pdf.
 * @return NSString - the title
 */
- (NSString *) getPdfName;

@end
