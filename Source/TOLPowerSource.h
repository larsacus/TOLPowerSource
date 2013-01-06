//
//  TOLPowerSourceObject.h
//  Outage
//
//  Created by Lars Anderson on 1/1/13.
//  Copyright (c) 2013 Lars Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TOLPowerSourceBatteryHealth){
    TOLPowerSourceBatteryHealthGood = 0,
    TOLPowerSourceBatteryHealthFair,
    TOLPowerSourceBatteryHealthPoor,
};

typedef NS_ENUM(NSInteger, TOLPowerSourceState){
    TOLPowerSourceStateACPower = 0,
    TOLPowerSourceStateBatteryPower,
    TOLPowerSourceStateOffline,
};

typedef NS_ENUM(NSInteger, TOLPowerSourceTransportType){
    TOLPowerSourceTransportTypeInternal = 0,
    TOLPowerSourceTransportTypeNetwork,
    TOLPowerSourceTransportTypeUSB,
    TOLPowerSourceTransportTypeSerial,
};

typedef NS_ENUM(NSInteger, TOLPowerSourceType){
    TOLPowerSourceTypeInternalBattery = 0,
    TOLPowerSourceTypeUPS,
};

typedef NS_ENUM(NSInteger, TOLPowerSourceBatteryHealthCondition){
    TOLPowerSourceBatteryHealthConditionCheckBattery = 0,
    TOLPowerSourceBatteryHealthConditionPermanentFailure,
};

@interface TOLPowerSource : NSObject

@property (nonatomic, readonly) BOOL batteryProvidesTimeRemaining;
@property (nonatomic, readonly) TOLPowerSourceBatteryHealth batteryHealth;
@property (nonatomic, readonly) TOLPowerSourceBatteryHealthCondition batteryHealthCondition;
@property (nonatomic, readonly) CGFloat currentCapacity;
@property (nonatomic, readonly) NSInteger designCycleCount;
@property (nonatomic, copy, readonly) NSString *hardwareSerialNumber;
@property (nonatomic, readonly) BOOL isCharged;
@property (nonatomic, readonly) BOOL isCharging;
@property (nonatomic, readonly) BOOL isPresent;
@property (nonatomic, readonly) CGFloat maxCapacity;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *powerSourceStateString;
@property (nonatomic, readonly) TOLPowerSourceState powerSourceState;
@property (nonatomic, readonly) NSInteger timeToEmpty;
@property (nonatomic, readonly) NSInteger timeToFullCharge;
@property (nonatomic, copy, readonly) NSString *transportTypeString;
@property (nonatomic, readonly) TOLPowerSourceTransportType transportType;
@property (nonatomic, readonly) TOLPowerSourceType type;
@property (nonatomic, readonly) CGFloat batteryPercentage;

+ (TOLPowerSource *)powerSourceObjectFromIOPowerSource:(CFTypeRef)powerSourceObject;
+ (TOLPowerSource *)powerSourceObjectFromIOPowerSource:(CFTypeRef)powerSourceObject
                                      powerSourcesInfo:(CFTypeRef)powerSourcesInfo;
+ (NSArray *)allPowerSources;
+ (TOLPowerSource *)internalBatterySource;
+ (TOLPowerSource *)upsBatterySource;
+ (BOOL)isOnBatteryPower;
+ (TOLPowerSource *)providingPowerSource;

@end
