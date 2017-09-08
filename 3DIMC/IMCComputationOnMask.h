//
//  IMCComputationOnMask.h
//  3DIMC
//
//  Created by Raul Catena on 2/18/17.
//  Copyright © 2017 University of Zürich. All rights reserved.
//

#import "IMCNodeWrapper.h"
#import "IMCMaskTraining.h"
#import "IMCChannelWrapper.h"

@class IMCPixelClassification;

@interface IMCComputationOnMask : IMCNodeWrapper

@property (nonatomic, weak) IMCPixelClassification *mask;
@property (nonatomic, readonly) NSMutableArray *channels;
@property (nonatomic, readonly) NSMutableArray *originalChannels;
@property (nonatomic, strong) NSMutableArray *channelSettings;
@property (nonatomic, assign) float ** computedData;

@property (nonatomic, readonly) NSInteger segmentedUnits;

@property (nonatomic, strong) NSMutableArray<IMCMaskTraining *> *trainingNodes;

-(void)addFeaturesFromCellProfiler:(NSURL *)url;
-(void)extractDataForMask:(NSIndexSet *)computations;
-(float *)createImageForMaskWithCellData:(float *)data maskOption:(NSInteger)option maskType:(MaskType)maskType maskSingleColor:(NSColor *)maskSingleColor;
-(CGImageRef)coloredMaskForChannel:(NSInteger)channel color:(NSColor *)color maskOption:(NSInteger)maskOption maskType:(MaskType)maskType maskSingleColor:(NSColor *)maskSingleColor brightField:(BOOL)brightField;
-(BOOL)hasBackData;
-(void)saveData;

-(float)maxForIndex:(NSInteger)index;
-(float *)xCentroids;
-(float *)yCentroids;
-(IMCChannelWrapper *)wrappedChannelAtIndex:(NSInteger)index;
-(NSString *)descriptionWithIndexes:(NSIndexSet *)indexSet;
//Buffer operations
-(void)addBuffer:(float *)buffer withName:(NSString *)name atIndex:(NSInteger)index;
-(void)removeChannelsWithIndexSet:(NSIndexSet *)indexSet;
-(void)addChannelsWithIndexSet:(NSIndexSet *)indexSet toInlineIndex:(NSInteger)index;
-(void)multiplyChannelsWithIndexSet:(NSIndexSet *)indexSet toInlineIndex:(NSInteger)index;

//Prepare and Operations
-(NSMutableArray *)arrayNumbersForIndex:(NSInteger)index;//--
-(NSArray *)arrayOfChannelArrays:(NSIndexSet *)indexSet;
-(NSDictionary *)statsForIndex:(NSInteger)index;//--
-(NSArray *)statsForIndexSet:(NSIndexSet *)indexSet;
-(NSArray *)countStatsForStack:(NSIndexSet *)indexSet;
-(NSString *)countForChannelArray:(NSArray *)array;
-(NSString *)meanForChannelArray:(NSArray *)array;
-(NSString *)modeForChannelArray:(NSArray *)array;
-(NSString *)stddForChannelArray:(NSArray *)array;
-(NSString *)totalForChannelArray:(NSArray *)array;
-(float)averagedSumOfSquaresForArray:(NSArray *)arrayOfChannelArrays;
-(NSString *)shannonForCountStatsArray:(NSArray *)countStatsArray;
-(NSString *)simpsonForCountStatsArray:(NSArray *)countStatsArray;

@end
