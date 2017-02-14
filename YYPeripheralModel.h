//
//  YYPeripheralModel.h
//  优悦一族
//
//  Created by MYO on 16/6/13.
//  Copyright © 2016年 umed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface YYPeripheralModel : NSObject
@property (nonatomic,copy) NSString *deviceName;
@property (nonatomic,copy) NSString *macAddress;
@property (nonatomic,weak) CBPeripheral *peripheral;
+(instancetype)peripheralModel:(NSString *)name
                       address:(NSString *)address
                    peripheral:(CBPeripheral *)peripheral;

@end
