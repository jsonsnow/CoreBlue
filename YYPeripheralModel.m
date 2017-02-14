//
//  YYPeripheralModel.m
//  优悦一族
//
//  Created by MYO on 16/6/13.
//  Copyright © 2016年 umed. All rights reserved.
//

#import "YYPeripheralModel.h"


@implementation YYPeripheralModel
+(instancetype)peripheralModel:(NSString *)name
                       address:(NSString *)address
                    peripheral:(CBPeripheral *)peripheral{
    
    return [[self alloc] initWithModel:name address:address peripheral:peripheral];
}
-(instancetype)initWithModel:(NSString *)name
                     address:(NSString *)address
                  peripheral:(CBPeripheral *)peripheral {
    
    self = [super init];
    self.deviceName = name;
    self.macAddress = address;
    self.peripheral = peripheral;
    return self;
}

-(NSUInteger)hash {
    //long v1 = (long)(__bridge void *)_peripheral;
    return 1;
}
-(BOOL)isEqual:(id)object {

    if (self == object) return YES;
    if (![object isMemberOfClass:self.class]) return NO;
    YYPeripheralModel *other = object;
    if (other.peripheral == _peripheral) {
        return YES;
    }
   
    if ([other.peripheral.identifier.UUIDString isEqualToString:self.peripheral.identifier.UUIDString]) {
        return YES;
    }
    if (!self.peripheral) {
        
        self.peripheral = other.peripheral;
        self.deviceName = other.peripheral.name;
        return YES;
    }
    return NO;
}

-(NSString *)description {
    
    return [NSString stringWithFormat:@"mac:%@,name:%@,uuidString:%@",self.macAddress,self.peripheral.name,self.peripheral.identifier.UUIDString];
}
@end
