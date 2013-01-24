//
//  TOLPowerSourceObject.m
//  Outage
//
//  Created by Lars Anderson on 1/1/13.
// Copyright (c) 2013 Lars Anderson, theonlylars
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TOLPowerSource.h"
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
//#import <IOKit/ps/IOUPSPlugIn.h>
#import <objc/runtime.h>

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
    CFRelease(powerSources);
    
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

+ (BOOL)isOnBatteryPower{
    
    CFTypeRef powerSourcesInfo = IOPSCopyPowerSourcesInfo();
    CFStringRef providingPowerSourceType = IOPSGetProvidingPowerSourceType(powerSourcesInfo);
    
    //TODO: might have to iterate through sources
    
    return [((__bridge NSString *)providingPowerSourceType) isEqualToString:@kIOPSBatteryPowerValue];
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
