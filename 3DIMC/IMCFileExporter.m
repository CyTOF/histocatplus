//
//  IMCFileExporter.m
//  3DIMC
//
//  Created by Raul Catena on 1/28/17.
//  Copyright © 2017 University of Zürich. All rights reserved.
//

#import "IMCFileExporter.h"
#import "IMCImageGenerator.h"
#import "IMCImageStack.h"
#import "IMCPixelClassification.h"
#import "IMCComputationOnMask.h"
#import "IMC3DMask.h"
#import "NSString+MD5.h"
#import "tiffio.h"
#import "IMCScrollView.h"
#import "NSView+Utilities.h"
#import "NSImage+Utilities.h"
#import "IMCLoader.h"

@implementation IMCFileExporter

#pragma mark save TIFFs

//Quick save as tiff
+(void)saveTIFFFromImageStack:(IMCImageStack *)stack atIndex:(int)index atPath:(NSString *)path bits:(int)bits{
    CGImageRef imageRef = [IMCImageGenerator rawImageFromImage:stack index:index numberOfBits:bits];
    NSImage *image = [[NSImage alloc]initWithCGImage:imageRef size:NSMakeSize(stack.width, stack.height)];
    NSData *data = [image TIFFRepresentation];
    [data writeToFile:path atomically:YES];
    CFRelease(imageRef);
}

//Save imagewise stack for miCAT
+(NSString *)saveTIFFsFolder:(IMCImageStack *)stack atFolderPath:(NSString *)dirpath{//Force to 16 bits
    if(![General isDirectory:[NSURL fileURLWithPath:dirpath]])
        return nil;
    
    NSString *folderCreated = [NSString stringWithFormat:@"%@/TIFF_%@", dirpath, [stack.itemName sanitizeFileNameString]];
    for (int i = 0; i < stack.channels.count; i++) {
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@.tif",
                              folderCreated,
                              [(NSString *)[stack.channels objectAtIndex:i]sanitizeFileNameString]];
        
        [General checkAndCreateDirectory:[NSString stringWithFormat:@"%@/TIFF_%@", dirpath, [stack.itemName sanitizeFileNameString]]];
        [IMCFileExporter saveTIFFFromImageStack:stack atIndex:i atPath:fullPath bits:16];
    }
    return folderCreated;
}

//Saving subroutines
+(TIFF *)writterForPath:(NSString *)path{
    return TIFFOpen(path.UTF8String, "w");
}

//Add Tags
//http://stackoverflow.com/questions/24059421/adding-custom-tags-to-a-tiff-file
+(void)writer:(TIFF *)tiff writeBuffer:(unsigned char *)buffer width:(int)width height:(int)height page:(int)page bpPixel:(int)bitsPixel samplesPerPixel:(int)samplesPixel totalPages:(int)totalPages imageName:(NSString *)name{//page -1 if no multipage
    
    if(name.length < 4)name = [name stringByAppendingString:@"_channel"];    
    if(name)name = [name sanitizeFileNameString];
    
    TIFFSetField(tiff, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
    TIFFSetField(tiff, TIFFTAG_IMAGEWIDTH, width);
    TIFFSetField(tiff, TIFFTAG_IMAGELENGTH, height);
    TIFFSetField(tiff, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_UINT);
    //TIFFSetField(tiff, TIFFTAG_ROWSPERSTRIP, TIFFDefaultStripSize(tiff, (unsigned int) - 1));
    TIFFSetField(tiff, TIFFTAG_BITSPERSAMPLE, bitsPixel);
    TIFFSetField(tiff, TIFFTAG_SAMPLESPERPIXEL, samplesPixel);
    TIFFSetField(tiff, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    if(name){
        name = [name sanitizeFileNameString];
        char cname[name.length];
        for(int a = 0; a < name.length; a++)cname[a] = [name characterAtIndex:a];
        TIFFSetField(tiff, TIFFTAG_IMAGEDESCRIPTION, &cname);
    }
    
    if(page >=0){
        TIFFSetField(tiff, TIFFTAG_PAGENUMBER, page, totalPages);
        TIFFSetField(tiff, TIFFTAG_SUBFILETYPE, FILETYPE_PAGE);
    }
    
    int bytesPix = 32/bitsPixel;//Improve RCF
    
    for (int i = 0; i < height; i++) {
        
        TIFFWriteScanline(tiff, &buffer[i * width * bytesPix], i, 0);//1 because there is always a leading 0
    }
    
    if(page >= 0)TIFFWriteDirectory(tiff);
    
    
}
+(void)writeArrayOfRefImages:(NSArray *)images withTitles:(NSArray *)titles atPath:(NSString *)path in16bits:(BOOL)sixteenBits{
    
    BOOL writeTitles = NO;
    if(titles.count == images.count)writeTitles = YES;
    
    TIFF *writer = TIFFOpen(path.UTF8String, "w");
    
    for (int i = 0; i < images.count; i++) {
        
        CGImageRef ref = (__bridge CGImageRef)[images objectAtIndex:i];
        NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]initWithCGImage:ref];
        
        unsigned char * bytes = imageRep.bitmapData;
        
        NSInteger bitsPerPixel = imageRep.bitsPerPixel;
        //NSInteger bytesRow = imageRep.bytesPerRow;
        //int sampleBits = imageRep.bitsPerSample;
        int samples = sixteenBits == YES?1:3;
        //NSBitmapFormat format = imageRep.bitmapFormat;
        
        size_t stride = CGImageGetWidth(ref);
        
        [self writer:writer writeBuffer:bytes width:(int)stride height:(int)CGImageGetHeight(ref) page:i bpPixel:(int)bitsPerPixel samplesPerPixel:samples totalPages:(int)images.count imageName:writeTitles == YES?[titles objectAtIndex:i]:nil];
    }
    TIFFClose(writer);
}

//Save multipage selected
#define MAX_LENGTH_FILENAME 150
+(void)saveMultipageTiffFromStack:(IMCImageStack *)stack forSelectedIndexes:(NSIndexSet *)indexes atDirPath:(NSString *)dirpath fileName:(NSString *)fileName{
    
    if(![General isDirectory:[NSURL fileURLWithPath:dirpath]])return;
    
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:stack.channels.count];
    NSMutableString *names = @"".mutableCopy;
    [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
        CGImageRef imageRef = [IMCImageGenerator rawImageFromImage:stack index:index numberOfBits:16];
        [arr addObject:(__bridge id _Nonnull)(imageRef)];
        [names appendString:@"_"];
        NSString *comp = stack.channels[index];
        [names appendString:[comp sanitizeFileNameString]];
        CFRelease(imageRef);
    }];
    
    NSString *passName =  fileName?fileName:stack.itemName.stringByDeletingPathExtension;
    
    if(names.length > MAX_LENGTH_FILENAME){
        names = @"".mutableCopy;
        [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
            [names appendString:@"_"];
            [names appendFormat:@"%lu", index];
        }];
    }
    
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@selected%@.tiff", dirpath, [passName sanitizeFileNameString], [names sanitizeFileNameString]];
    
    [IMCFileExporter writeArrayOfRefImages:arr withTitles:stack.channels atPath:fullPath in16bits:YES];
}

+(void)saveMultipageTiffAllChannels:(IMCImageStack *)stack path:(NSString *)path{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:stack.channels.count];
    for (int i = 0; i < stack.channels.count; i++) {
        CGImageRef imageRef = [IMCImageGenerator rawImageFromImage:stack index:i numberOfBits:16];
        [arr addObject:(__bridge id _Nonnull)(imageRef)];
        CFRelease(imageRef);
    }
    path = [path.stringByDeletingPathExtension stringByAppendingString:@".tiff"];
    [IMCFileExporter writeArrayOfRefImages:arr withTitles:nil atPath:path in16bits:YES];
}

+(NSImage *)getNSImageForIMCScrollView:(IMCScrollView *)scroll zoomed:(BOOL)zoomed{
    NSImage *someImage;
    if(zoomed)someImage = [scroll getImageBitMapFull];
    else{
        CGFloat prev = scroll.magnification;
        [scroll setMagnification:1.0];
        someImage = [scroll.imageView getImageBitMapFromRect:scroll.imageView.bounds];
        [scroll setMagnification:prev];
    }
    return someImage;
}
+(NSImage *) mergeImage:(NSImage*)a andB:(NSImage*)b fraction:(float)fraction{
    
    NSBitmapImageRep *bitmap = [a bitmapImageRepresentation];//(NSBitmapImageRep*)[[a representations] objectAtIndex:0];
    NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:ctx];
    CGRect rect = CGRectMake(0, 0, bitmap.size.width, bitmap.size.height);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:ctx];
    [b drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:fraction];
    [NSGraphicsContext restoreGraphicsState];
    
    return [[NSImage alloc]initWithCGImage:bitmap.CGImage size:bitmap.size];
}
+(void)copyToClipBoardFromScroll:(IMCScrollView *)scroll allOrZoomed:(BOOL)zoomed{
    NSImage *im = [IMCFileExporter getNSImageForIMCScrollView:scroll zoomed:zoomed];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[im]];
}
+(void)copyToClipBoardFromView:(NSView *)view{
    NSImage *im = [view getImageBitMapFromRect:view.bounds];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[im]];
}
+(void)saveJPEGFromScroll:(IMCScrollView *)scroll withPath:(NSString *)fullPath allOrZoomed:(BOOL)zoomed{
    [IMCFileExporter saveNSImageAsJpeg:[IMCFileExporter getNSImageForIMCScrollView:scroll zoomed:zoomed] withPath:fullPath];
}

+(void)saveNSImageAsJpeg:(NSImage *)image withPath:(NSString *)path{
    // Cache the reduced image
    NSData *imageData = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
    [imageData writeToFile:path atomically:NO];
}

+(BOOL)saveCSVWithComputations:(NSArray<IMCComputationOnMask *>*)computations atPath:(NSString *)path columnIndexes:(NSIndexSet *)indexSet dataCoordinator:(IMCLoader *)loader metadataIndexes:(NSIndexSet *)indexSetMetadata{
    IMCComputationOnMask * chosen = computations.firstObject;
    for (IMCComputationOnMask *compo in computations)
        if(compo.channels.count > chosen.channels.count)
            chosen = compo;
    NSInteger width = chosen.channels.count + 1;
    
    NSMutableArray *channs  = @[].mutableCopy;//= @[@"Acquisiton"].mutableCopy;
    NSArray *keys = loader.metadata[JSON_METADATA_KEYS];
    NSMutableArray *selectedKeys = @[].mutableCopy;
    [indexSetMetadata enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
        [selectedKeys addObject:keys[index]];
    }];
    [channs addObjectsFromArray:selectedKeys];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
        [channs addObject:chosen.channels[index]];
    }];
    
    NSMutableString *titles = [NSMutableString stringWithFormat:@"%@\n",[channs componentsJoinedByString:@"\t"]];
    
    for (IMCComputationOnMask *compo in computations){
        
        BOOL wasLoaded = compo.isLoaded;
        if(!wasLoaded)
            [compo loadLayerDataWithBlock:nil];
        while(!compo.isLoaded);
        
        NSInteger cells;
        if([compo isMemberOfClass:[IMCComputationOnMask class]]){
            cells = compo.mask.numberOfSegments;
        }else{
            cells = [(IMC3DMask *)compo segmentedUnits];
        }
        NSInteger channels = compo.channels.count;
        
        NSDictionary *metadataDict;
        if([compo isMemberOfClass:[IMCComputationOnMask class]]){
            metadataDict = [loader metadataForImageStack:compo.mask.imageStack];
        }
        
        for (NSInteger i = 0; i <cells; i++) {
            if(metadataDict){
                [titles appendFormat:@"%@\t", compo.mask.imageStack.itemName];
            }else{
                    [titles appendString:@"\t"];
            }
            for (NSString *key in selectedKeys) {
                [titles appendString:[NSString stringWithFormat:@"%@\t", metadataDict[key]?metadataDict[key]:@""]];
            }
            
            [indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
                [titles appendString:[NSString stringWithFormat:@"%.6f\t", compo.computedData[index][i]]];
            }];
            
            for (NSInteger j = 0; j < width - channels - 1; j++)//Fill if it has less channels than chosen
                [titles appendString:@"\t"];
            
            [titles deleteCharactersInRange:NSMakeRange([titles length]-2, 2)];
            [titles appendString:@"\n"];
        }
        if(!wasLoaded)
            [compo unLoadLayerDataWithBlock:nil];
    }
    [titles deleteCharactersInRange:NSMakeRange([titles length]-2, 2)];
    
    NSError *error;
    [titles writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    return !(error);
}
+(BOOL)saveTSVWithMetadata:(NSArray<IMCImageStack *>*)stacks atPath:(NSString *)path withCoordinator:(IMCLoader *)loader{
    
    NSArray *fixed = METADATA_GIVEN_COLUMNS;
    NSArray *keys = loader.metadata[JSON_METADATA_KEYS];
    NSArray *allHeaders = [fixed arrayByAddingObjectsFromArray:keys];
    NSMutableString *phrase = [NSMutableString stringWithFormat:@"%@\n",[allHeaders componentsJoinedByString:@"\t"]];
    
    for (IMCImageStack *stack in stacks){
        NSDictionary *dict = [loader metadataForImageStack:stack];
        [phrase appendString:stack.itemName];
        [phrase appendString:@"\t"];
        [phrase appendString:stack.itemHash];
        [phrase appendString:@"\t"];
        [phrase appendString:stack.fileWrapper.relativePath];
        [phrase appendString:@"\t"];
        for (NSString *key in keys)
            [phrase appendFormat:@"%@\t", dict[key]];

        [phrase deleteCharactersInRange:NSMakeRange([phrase length]-2, 2)];
        [phrase appendString:@"\n"];
    }
    [phrase deleteCharactersInRange:NSMakeRange([phrase length]-2, 2)];
    
    NSError *error;
    [phrase writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    return !(error);
}

@end
