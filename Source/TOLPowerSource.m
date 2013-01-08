//
//  TOLPowerSourceObject.m
//  Outage
//
//  Created by Lars Anderson on 1/1/13.
//  Copyright (c) 2013 Lars Anderson. All rights reserved.
//

#import "TOLPowerSource.h"
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

NSString * const kTOLPowerSourcePowerTypeUPSPower = @"UPS Power"; //This key is returned by IOPSGetProvidingPowerSourceType sometimes, but is not defined in IOPSKeys.h

@interface TOLPowerSource ()

@property (nonatomic, readwrite) BOOL batteryProvidesTimeRemaining;
@property (nonatomic, readwrite) TOLPowerSourceBatteryHealth batteryHealth;
@property (nonatomic, readwrite) TOLPowerSourceBatteryHealthCondition batteryHealthCondition;
@property (nonatomic, readwrite) CGFloat currentCapacity;
@property (nonatomic, readwrite) NSInteger designCycleCount;
@property (nonatomic, copy, readwrite) NSString *hardwareSerialNumber;
@property (nonatomic, readwrite) BOOL isCharged;
@property (nonatomic, readwrite) BOOL isCharging;
@property (nonatomic, readwrite) BOOL isPresent;
@property (nonatomic, readwrite) CGFloat maxCapacity;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *powerSourceStateString;
@property (nonatomic, readwrite) TOLPowerSourceState powerSourceState;
@property (nonatomic, readwrite) NSInteger timeToEmpty;
@property (nonatomic, readwrite) NSInteger timeToFullCharge;
@property (nonatomic, copy, readwrite) NSString *transportTypeString;
@property (nonatomic, readwrite) TOLPowerSourceTransportType transportType;
@property (nonatomic, readwrite) TOLPowerSourceType type;
@property (nonatomic, readwrite) CGFloat batteryPercentage;
@property (nonatomic, copy) NSDictionary *rawInfo;

@end

@implementation TOLPowerSource

+ (TOLPowerSource *)powerSourceObjectFromIOPowerSource:(CFTypeRef)powerSourceObject{
    return [self powerSourceObjectFromIOPowerSource:powerSourceObject powerSourcesInfo:nil];
}

+ (TOLPowerSource *)powerSourceObjectFromIOPowerSource:(CFTypeRef)powerSourceObject powerSourcesInfo:(CFTypeRef)powerSourcesInfo{
    
    BOOL shouldRelease = NO;
    if (powerSourcesInfo == nil) {
        powerSourcesInfo = IOPSCopyPowerSourcesInfo();
        shouldRelease = YES;
    }
    
    NSDictionary *powerSourceInfo = (__bridge NSDictionary *)IOPSGetPowerSourceDescription(powerSourcesInfo, powerSourceObject);
    
    if (shouldRelease) {
        CFRelease(powerSourcesInfo);
    }
    
    TOLPowerSource *powerSource = [[TOLPowerSource alloc] init];
    
    powerSource.rawInfo = powerSourceInfo;
    powerSource.batteryProvidesTimeRemaining = [powerSourceInfo[@"Battery Provides Time Remaining"] boolValue];
    powerSource.batteryHealth = [self batteryHealthFromString:powerSourceInfo[@kIOPSBatteryHealthKey]];
    powerSource.currentCapacity = [powerSourceInfo[@kIOPSCurrentCapacityKey] floatValue];
    powerSource.designCycleCount = [powerSourceInfo[@"DesignCycleCount"] integerValue];
    powerSource.hardwareSerialNumber = powerSourceInfo[@kIOPSHardwareSerialNumberKey];
    powerSource.isCharged = [powerSourceInfo[@kIOPSIsChargedKey] boolValue];
    powerSource.isCharging = [powerSourceInfo[@kIOPSIsChargingKey] boolValue];
    powerSource.isPresent = [powerSourceInfo[@kIOPSIsPresentKey] boolValue];
    powerSource.maxCapacity = [powerSourceInfo[@kIOPSMaxCapacityKey] integerValue];
    powerSource.name = powerSourceInfo[@kIOPSNameKey];
    powerSource.powerSourceState = [self powerSourceStateFromString:powerSourceInfo[@kIOPSPowerSourceStateKey]];
    powerSource.timeToEmpty = [powerSourceInfo[@kIOPSTimeToEmptyKey] integerValue];
    powerSource.timeToFullCharge = [powerSourceInfo[@kIOPSTimeToFullChargeKey] integerValue];
    powerSource.transportType = [self transportTypeFromString:powerSourceInfo[@kIOPSTransportTypeKey]];
    powerSource.type = [self typeFromString:powerSourceInfo[@kIOPSTypeKey]];
    powerSource.batteryHealthCondition = [self conditionFromString:powerSourceInfo[@kIOPSBatteryHealthConditionKey]];
    powerSource.batteryPercentage = powerSource.currentCapacity/powerSource.maxCapacity;
    
    return powerSource;
}

+ (NSArray *)allPowerSources{
    CFTypeRef powerSourcesInfo = IOPSCopyPowerSourcesInfo();
    CFArrayRef powerSources = IOPSCopyPowerSourcesList(powerSourcesInfo);
    
    NSMutableArray *sourcesArray = [NSMutableArray array];
    
    if (powerSources != NULL) {
        NSInteger num = CFArrayGetCount(powerSources);
        for (NSInteger i = 0; i < num; i++) {
            CFTypeRef powerSource = CFArrayGetValueAtIndex(powerSources, i);
            
            TOLPowerSource *powerSourceObject = [self powerSourceObjectFromIOPowerSource:powerSource powerSourcesInfo:powerSourcesInfo];
            
            [sourcesArray addObject:powerSourceObject];
        }
    }
    
    CFRelease(powerSourcesInfo);
    
    if (powerSources != NULL) {
        CFRelease(powerSources);
    }
    
    return sourcesArray;
}

+ (TOLPowerSource *)internalBatterySource{
    NSArray *powerSources = [self allPowerSources];
    
    TOLPowerSource *batterySource = nil;
    NSUInteger numBatteries = 0;
    
    for (TOLPowerSource *powerSource in powerSources) {
        if (powerSource.type == TOLPowerSourceTypeInternalBattery) {
            batterySource = powerSource;
            numBatteries++;
        }
    }
    
    if (numBatteries > 1) {
        NSLog(@"Warning: This system has more than one internal battery source, which one returned is undefined");
    }
    
    return batterySource;
}

+ (TOLPowerSource *)upsBatterySource{
    NSArray *powerSources = [self allPowerSources];
    
    TOLPowerSource *upsSource = nil;
    NSUInteger numBatteries = 0;
    
    for (TOLPowerSource *powerSource in powerSources) {
        if (powerSource.type == TOLPowerSourceTypeUPS) {
            upsSource = powerSource;
            numBatteries++;
        }
    }
    
    if (numBatteries == 0) {
        for (TOLPowerSource *powerSource in powerSources) {
            if (powerSource.transportType == TOLPowerSourceTransportTypeUSB) {
                //why else would you have a power source over USB if not for a UPS??
                upsSource = powerSource;
                numBatteries++;
            }
        }
    }
    
    if (numBatteries > 1) {
        NSLog(@"Warning: This system has more than one UPS source, which one returned is undefined");
    }
    
    return upsSource;
}

+ (TOLPowerSource *)providingPowerSource{
    CFTypeRef powerSourcesInfo = IOPSCopyPowerSourcesInfo();
    NSString *providingPowerSourceType = (__bridge NSString *)IOPSGetProvidingPowerSourceType(powerSourcesInfo);
    
    if (powerSourcesInfo != NULL) {
        CFRelease(powerSourcesInfo);
    }
    
    NSArray *allPowerSources = [self allPowerSources];
    for (TOLPowerSource *powerSource in allPowerSources) {
        if (powerSource.type == [self typeFromString:providingPowerSourceType]) {
            //power source is providing power source
            return powerSource;
        }
    }
    
    return nil;
}

+ (BOOL)isOnBatteryPower{
    
    CFTypeRef powerSourcesInfo = IOPSCopyPowerSourcesInfo();
    CFStringRef providingPowerSourceType = IOPSGetProvidingPowerSourceType(powerSourcesInfo);
    
    if (powerSourcesInfo != NULL) {
        CFRelease(powerSourcesInfo);
    }
    
    NSString *powerSourceType = ((__bridge NSString *)providingPowerSourceType);
    
    return ([powerSourceType isEqualToString:@kIOPSBatteryPowerValue] ||
            [powerSourceType isEqualToString:kTOLPowerSourcePowerTypeUPSPower]);
}

#pragma mark - Internal Helpers
+ (TOLPowerSourceBatteryHealth)batteryHealthFromString:(NSString *)batteryHealthString{
    if ([batteryHealthString isEqualToString:@kIOPSGoodValue]) {
        return TOLPowerSourceBatteryHealthGood;
    }
    else if([batteryHealthString isEqualToString:@kIOPSFairValue]){
        return TOLPowerSourceBatteryHealthFair;
    }
    else if([batteryHealthString isEqualToString:@kIOPSPoorValue]){
        return TOLPowerSourceBatteryHealthPoor;
    }
    
    return -1;
}

+ (TOLPowerSourceState)powerSourceStateFromString:(NSString *)powerSourceStateString{
    if ([powerSourceStateString isEqualToString:@kIOPSACPowerValue]) {
        return TOLPowerSourceStateACPower;
    }
    else if([powerSourceStateString isEqualToString:@kIOPSOffLineValue]){
        return TOLPowerSourceStateOffline;
    }
    else if([powerSourceStateString isEqualToString:@kIOPSBatteryPowerValue]){
        return TOLPowerSourceStateBatteryPower;
    }
    
    return -1;
}

+ (TOLPowerSourceTransportType)transportTypeFromString:(NSString *)powerSourceTransportType{
    if ([powerSourceTransportType isEqualToString:@kIOPSInternalType]) {
        return TOLPowerSourceTransportTypeInternal;
    }
    else if([powerSourceTransportType isEqualToString:@kIOPSNetworkTransportType]){
        return TOLPowerSourceTransportTypeNetwork;
    }
    else if([powerSourceTransportType isEqualToString:@kIOPSUSBTransportType]){
        return TOLPowerSourceTransportTypeUSB;
    }
    else if([powerSourceTransportType isEqualToString:@kIOPSSerialTransportType]){
        return TOLPowerSourceTransportTypeSerial;
    }
    
    return -1;
}

+ (TOLPowerSourceType)typeFromString:(NSString *)powerSourceTypeString{
    if ([powerSourceTypeString isEqualToString:@kIOPSInternalBatteryType]) {
        return TOLPowerSourceTypeInternalBattery;
    }
    else if([powerSourceTypeString isEqualToString:@kIOPSUPSType]){
        return TOLPowerSourceTypeUPS;
    }
    
    return -1;
}

+ (TOLPowerSourceBatteryHealthCondition)conditionFromString:(NSString *)condition{
    if ([condition isEqualToString:@kIOPSCheckBatteryValue]) {
        return TOLPowerSourceBatteryHealthConditionCheckBattery;
    }
    else if([condition isEqualToString:@kIOPSPermanentFailureValue]){
        return TOLPowerSourceBatteryHealthConditionPermanentFailure;
    }
    
    return -1;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"<%@: %p> (%@)", NSStringFromClass(self.class), self, self.rawInfo];
}

@end
