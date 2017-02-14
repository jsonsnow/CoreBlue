 //
//  YYBlueManger.m
//  YYBlueTool
//
//  Created by MYO on 16/3/23.
//  Copyright © 2016年 MYO. All rights reserved.
//

#import "YYBlueManger.h"
#import "YYPeripheralModel.h"

NSString *const BlueCharacteristicRead = @"BlueCharacteristicRead";
NSString *const BlueCharacteristicWrite = @"BlueCharacteristicWrite";


static YYBlueManger * _manager;
@interface YYBlueManger ()<CBCentralManagerDelegate,CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager * centralManager;
@property (nonatomic, strong) CBPeripheral * currentperipheral;
@property (nonatomic, strong) CBCharacteristic * characteristic;

///写数据发生失败时候调用的block
@property (nonatomic, copy) void(^writeBlock)(NSError *error);

/**
 *  重新搜索时候新加入的设备
 */
@property (nonatomic, strong) NSMutableSet  *searchArray;
/**
 *  标志用户是否正在搜索新相同的设备
 */
@property (nonatomic, getter=isSearch) BOOL search;
@property (nonatomic, strong) NSString *specifedName;
@property (nonatomic, copy) void(^saveNameBlock)(NSArray *);
@property (nonatomic, strong) NSMutableArray *blueDeviceArrays;

@property (nonatomic, assign, readwrite) YYBlueConnectState connectState;
@property (nonatomic, assign, readwrite) YYBlueManagerState managerState;
@property (nonatomic, assign, readwrite) BOOL needMacAddress;

/**
 建议在初始化CBCentralManager的时候给定serailQueue,再把搜索连接等操作加入到这个Queue中(目前没有实现)，能保证操作都是同步的方便控制
 */
@property (nonatomic, strong) NSOperationQueue *serailQueue;

@end
@implementation YYBlueManger

#pragma mark - setters and getters

-(NSOperationQueue *)serailQueue {
    
    if (!_serailQueue) {
        
        _serailQueue = [[NSOperationQueue alloc] init];
        _serailQueue.maxConcurrentOperationCount = 1;
    }
    return _serailQueue;
}
-(NSMutableArray *)blueDeviceArrays {
    
    if (!_blueDeviceArrays) {
        
        _blueDeviceArrays = [NSMutableArray array];
    }
   
    
    return _blueDeviceArrays;
    
}

-(NSMutableSet *)searchArray {
    
    if (!_searchArray) {
        _searchArray = [NSMutableSet set];
    }
    
    return _searchArray;
    
}
-(CBCentralManager *)setCentralManager {
    
    if (!_centralManager) {
        
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    
    return _centralManager ;
}

-(void)setDelegate:(id<YYBlueMangerDelegate>)delegate {
    _delegate = delegate;
    //重新获取蓝牙状态
    if (_delegate)
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    [self resetSatuts];
}
#pragma mark life cycle
+(instancetype)sharedManger {
    
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        
     _manager  = [[self alloc] init];
        
    });
    
    
    return _manager;
}
-(instancetype)init {
    
    self = [super init];
    //[self addObserver:self forKeyPath:@"delegate" options:NSKeyValueObservingOptionNew context:nil];
    return self;
}
-(void)dealloc {
    
    //[self removeObserver:self forKeyPath:@"delegate" context:nil];
}

#pragma mark - KVO
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"delegate"]) {
#ifdef DEBUG
        NSLog(@"current delegate change we should reset the two status");
#endif
        //delegate发生变化一般是contriller改变时候，这是需要重置两个状态
        [self resetSatuts];
    }
}

#pragma mark Private method
-(void)resetSatuts {
    
    self.connectState = YYBlueConnectStateDefault;
    self.managerState = YYBlueManagerStateDefault;
    self.search = NO;
    self.needMacAddress = NO;
    [self.blueDeviceArrays removeAllObjects];
    [self.searchArray removeAllObjects];
    self.saveNameBlock = nil;
    self.specifedName = nil;

}
#pragma mark Public method
//搜索设备
-(void)scanTheSameNameDeviceByTheSpeicfedName:(NSString *)string
                                   isGet:(BOOL)isGet
                               needMacAddress:(BOOL)needMacAddress
                                        block:(void (^)(NSArray *))sameNameDeviceArray{
    
    self.search = YES;
    self.needMacAddress = needMacAddress;
    [self.searchArray removeAllObjects];
    self.saveNameBlock = sameNameDeviceArray;
    self.specifedName  = string;
    
    if (isGet) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (CBPeripheral *peripheral in self.blueDeviceArrays) {
                
                if ([peripheral.name containsString:string]) {
                    
                    if (peripheral == self.currentperipheral)
                        {
                            if (_needMacAddress)
                            {
                                CBUUID *macServiceUUID = [CBUUID UUIDWithString:@"0x180A"];
                                [peripheral discoverServices:@[macServiceUUID]];
                            } else {
                                
                                YYPeripheralModel *model = [YYPeripheralModel peripheralModel:peripheral.name
                                                                                      address:nil peripheral:peripheral];
                                [self.searchArray addObject:model];

                            }
                           
                        }
                    else
                    {
                        YYPeripheralModel *model = [YYPeripheralModel peripheralModel:peripheral.name
                                                                                  address:nil peripheral:peripheral];
                        [self.searchArray addObject:model];
                        NSMutableArray *array = [NSMutableArray array];
                        for (YYPeripheralModel *temp in self.searchArray) {
                                
                            [array addObject:temp];
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (self.saveNameBlock) self.saveNameBlock([array copy]);
                    });
                }
                        
            }
        }
    });
        
    return ;
    }
    [self scan];
}

-(void)stopSearchSameNameDevice {
    
    self.search = NO;
    self.needMacAddress = NO;
    self.saveNameBlock = nil;
    [self stop];
    
}

-(void)removeAllDevice {
    
    [self.blueDeviceArrays removeAllObjects];
    [self.searchArray removeAllObjects];
    
}

-(void)scan {
    
    if (self.managerState != YYBlueManagerStateDefault && self.managerState != YYBlueManagerStatePoweredOn) {
        if ([self.delegate respondsToSelector:@selector(blueManagerFailedState:statu:)]) {
            [self.delegate blueManagerFailedState:self statu:self.managerState];
        }
#ifdef DEBUG
        NSLog(@"请检查蓝牙设置");
#endif
        return;
    }
    if (self.managerState == YYBlueManagerStateDefault) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // if delegate be nil we should end scan
            if (!self.delegate) {
                return ;
            }
            [self scan];
        });
        return;
    }
    [self stop];
    [self.blueDeviceArrays removeAllObjects];
    [self setCentralManager];
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    
}

-(void)stop {
    
    [self.centralManager stopScan];
    
}
-(void)connect:(CBPeripheral *)peripheral orTheDeviceName:(NSString *)name {
    
    NSAssert(peripheral||name, @"必须指定设备名字或者对应的外设");
    //这个情况主要是为了在切换同一类型外设的时候进行连接，建议调用resetPeripheralConnention:(CBPeripheral *)peripheral法重置一下connect状态
     if (self.currentperipheral) {
         
         if ([peripheral.name containsString:self.currentperipheral.name]&&peripheral != self.currentperipheral) {
             self.connectState = YYBlueConnectStateConnecting;
             [self.centralManager connectPeripheral:peripheral options:nil];
             return;
         }
     }
    if (self.connectState == YYBlueConnectStateConnecting || self.connectState == YYBlueConnectStateConnected) {
        return;
    }
    
    self.connectState = YYBlueConnectStateConnecting;
    //当前外设不存在时候
    if (peripheral) {
        
        [self.centralManager connectPeripheral:peripheral options:nil];
       
    } else {
        
        for (CBPeripheral *tempPeripheral in _blueDeviceArrays) {
            
            if ([tempPeripheral.name containsString:name]) {
                
                [self.centralManager connectPeripheral:tempPeripheral options:nil];
                break;
            }
        }
    }
}

-(void)resetPeripheralConnention:(CBPeripheral *)peripheral {
    
    [self cancelPeripheralConnection:self.currentperipheral];
    [self connect:peripheral orTheDeviceName:nil];
}

-(void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    
    self.connectState = YYBlueConnectStateDefault;
    if (self.currentperipheral) {
        
        [self.centralManager cancelPeripheralConnection:self.currentperipheral];
        [self.blueDeviceArrays removeObject:self.currentperipheral];
        self.currentperipheral = nil;
        self.characteristic = nil;
        
    }
    
}

#pragma mark 向外设写数据
-(void)writeDataToDevice:(NSData *)data writeHandle:(void (^)(NSError *))writeHandle {
    
    //MyLog(@"写数据");
    if (!data) return;
    //蓝牙连接成功的时候，特性值不一定找到，下面给个十秒的超时处理，在这十秒内等待系统查找特性值或写数据
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        if(!self.characteristic) {
            for (int i = 0; i < 10; i ++) {
                sleep(1);
                if (i == 9 || self.characteristic) {
                    
                    goto loopEnd;
                }
            }
        }
    loopEnd:if(!self.characteristic) {
        // MyLog(@"数据写入失败");
        if (!self.currentperipheral) {
            return ;
        }
        [self.centralManager cancelPeripheralConnection:self.currentperipheral];
        return ;
    }
        // MyLog(@"数据写入成功");
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.currentperipheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
            
            
        });
        
    });
    
}

#pragma mark -- centralManager delegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    switch (central.state) {
        case CBCentralManagerStateUnknown:
            self.managerState = YYBlueManagerStateStateUnknown;
            break;
        case CBCentralManagerStateUnsupported:
            self.managerState = YYBlueManagerStateUnsupported;
            
           // MyLog(@"模拟器不支持蓝牙调试");
            break;
        case CBCentralManagerStateUnauthorized:
            self.managerState = YYBlueManagerStateUnauthorized;
           // MyLog(@"蓝牙未授权");
            break;
        case CBCentralManagerStatePoweredOff:
            self.managerState = YYBlueManagerStatePoweredOff;
            //MyLog(@"蓝牙已关闭");
            break;
        case CBCentralManagerStateResetting:
            self.managerState = YYBlueManagerStateResetting;
           // MyLog(@"蓝牙断开连接");
            break;
        case CBCentralManagerStatePoweredOn:
            //MyLog(@"可以开始扫描");
             self.managerState = YYBlueManagerStatePoweredOn;
            break;
        default:
           // MyLog(@"default");
            self.managerState = YYBlueManagerStateDefault;
            break;
    }
    
    if ([self.delegate respondsToSelector:@selector(blueManagerbleStausForCurerntPhone:andTheStauts:)])
        [self.delegate blueManagerbleStausForCurerntPhone:self andTheStauts:self.managerState];
    
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if (self.isSearch) {
        
        //正在连接设备不会重新被扫描到
        if (self.currentperipheral) {
              if (![self.blueDeviceArrays containsObject:self.currentperipheral]) {
                    [self.blueDeviceArrays addObject:self.currentperipheral];
                  
                  if ([self.currentperipheral.name containsString:self.specifedName]&&(self.currentperipheral.state == CBPeripheralStateConnected||_currentperipheral.state == CBPeripheralStateConnecting) &&_needMacAddress) {
                      CBUUID *macServiceUUID = [CBUUID UUIDWithString:@"0x180A"];
                      [_currentperipheral discoverServices:@[macServiceUUID]];
                  }
                  
                  if ([self.currentperipheral.name containsString:self.specifedName] && !_needMacAddress) {
                      YYPeripheralModel *model = [YYPeripheralModel peripheralModel:self.currentperipheral.name address:nil
                                                                         peripheral:self.currentperipheral];
                      [self.searchArray addObject:model];
                  }
                  
              }
        }
        
        if ([peripheral.name containsString:self.specifedName]) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            YYPeripheralModel *model = [YYPeripheralModel peripheralModel:peripheral.name address:nil
                                                               peripheral:peripheral];
                if (![self.searchArray containsObject:model]) {
                    [self.searchArray addObject:model];
                    NSMutableArray *array = [NSMutableArray array];
                    for (YYPeripheralModel *temp in self.searchArray) {
                        [array addObject:temp];
                    }
                    if (self.saveNameBlock){
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.saveNameBlock([array copy]);
        
                        });
                    }
                }
                
            });
           
        }
        
    }

    // 不管是否在查找相同名字的设备，都需要把当前连接的设备加入到数组中
    if (self.currentperipheral&&self.currentperipheral.state == CBPeripheralStateConnected) {
        if (![self.blueDeviceArrays containsObject:self.currentperipheral]) {
            [self.blueDeviceArrays addObject:self.currentperipheral];
        }
    }
        if (![self.blueDeviceArrays containsObject:peripheral]) {
            
           // MyLog(@"name:%@ , uuid:%@",peripheral.name, peripheral.identifier.UUIDString);
            
            if (self.delegate) {
                
                if ([self.delegate respondsToSelector:@selector(blueManagerblescanBluDevice:andTheDevice:)]) {
                    
                    [self.delegate blueManagerblescanBluDevice:self andTheDevice:peripheral];
                    
                }
            }
            //对该操作进行加锁，防止在遍历数组时候加入新的对象，引起崩溃
            @synchronized(self) {
                
                [self.blueDeviceArrays addObject:peripheral];
            }
        }
}

#pragma mark -- 外设链接回调

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
   [self.blueDeviceArrays removeObject:self.currentperipheral];
    self.connectState = YYBlueConnectStateCutConnect;
    self.currentperipheral = nil ;
    self.characteristic = nil;
    if (!_search) {
        
        if ([self.delegate respondsToSelector:@selector(blueManagerCutConnect:peripheral:error:)]) {
            
            [self.delegate blueManagerCutConnect:self peripheral:peripheral error:error];
            return;
        }
    }
    
   //在搜索时候回调断开函数和进行数据源更新
    if (self.saveNameBlock && _search) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            YYPeripheralModel *model = [YYPeripheralModel peripheralModel:peripheral.name address:peripheral.identifier.UUIDString peripheral:peripheral];
            [self.searchArray removeObject:model];
            NSMutableArray *array = [NSMutableArray array];
            for (YYPeripheralModel *temp in self.searchArray) {
                [array addObject:temp];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.saveNameBlock([array copy]);
                if ([self.delegate respondsToSelector:@selector(blueManagerFailedConnect:peripheral:error:)])
                {
                    [self.delegate blueManagerCutConnect:self peripheral:peripheral error:error];
                }
            });
        });
    }
}


-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    [self.blueDeviceArrays removeObject:self.currentperipheral];
    self.connectState = YYBlueConnectStateFailedConnect;
    self.currentperipheral = nil;
    self.characteristic = nil;
    if (!_search) {
        
        if ([self.delegate respondsToSelector:@selector(blueManagerFailedConnect:peripheral:error:)]) {
            
            [self.delegate blueManagerFailedConnect:self peripheral:peripheral error:error];
            return;
        }
    }
    if (self.saveNameBlock && _search) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            YYPeripheralModel *model = [YYPeripheralModel peripheralModel:peripheral.name address:peripheral.identifier.UUIDString peripheral:peripheral];
            [self.searchArray removeObject:model];
                NSMutableArray *array = [NSMutableArray array];
            for (YYPeripheralModel *temp in self.searchArray) {
                [array addObject:temp];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.saveNameBlock([array copy]);
                if ([self.delegate respondsToSelector:@selector(blueManagerFailedConnect:peripheral:error:)])
                {
                    [self.delegate blueManagerFailedConnect:self peripheral:peripheral error:error];
                }
            });
        });
    }
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    
    self.connectState = YYBlueConnectStateConnected;
    if ([self.delegate respondsToSelector:@selector(blueManagerdidConnectSuccees:peripheral:)]) {
        
        [self.delegate blueManagerdidConnectSuccees:self peripheral:peripheral];
    }
    self.currentperipheral  = peripheral;
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    
}


#pragma mark -- CBPeripheral delegate
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {return;}
    NSArray *serviceArray;
    //这个主要是对于需要读外设MAC地址
    if (_search && _needMacAddress) {
        
        for (CBService *service in peripheral.services) {
            
            if ([service.UUID isEqual:[CBUUID UUIDWithString:@"0x180A"]]) {
                
                [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"0x2A23"]] forService:service];
                return;
            }
        }
    }
    if ([self.delegate respondsToSelector:@selector(blueManagerServerAdrres:peripheral:)]) {
        
        serviceArray = [self.delegate blueManagerServerAdrres:self peripheral:peripheral];
        NSAssert(serviceArray.count > 0, @"peripheral service address must > 0");
    }
    for (CBService *service in peripheral.services) {
        
        for (NSString *addresString in serviceArray) {
            
            if ([service.UUID isEqual:[CBUUID UUIDWithString:addresString]]) {
#ifdef DEBUG
                NSLog(@"the service address:%@",addresString);
#endif
                [peripheral discoverCharacteristics:nil forService:service];
            } else  continue;
        }
    }
    
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    if (error) return;
    NSDictionary *charactDict;
    if (_search && [service.UUID isEqual:[CBUUID UUIDWithString:@"0x180A"]] && _needMacAddress) {
        
        for (CBCharacteristic *characteristic in service.characteristics) {
            
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"0x2A23"]]) {
                [peripheral readValueForCharacteristic:characteristic];
                return;
            }
        }
    }
    if ([self.delegate respondsToSelector:@selector(blueManagerCharacteristicsAdrres:peripheral:)]) {
        
        charactDict = [self.delegate blueManagerCharacteristicsAdrres:self peripheral:peripheral];
        NSAssert(charactDict.count == 2, @"please check you characteristic address! ");
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:charactDict[BlueCharacteristicRead]]]) {
#ifdef DEBUG
            NSLog(@"the charact read address:%@",charactDict[BlueCharacteristicRead]);
#endif
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:charactDict[BlueCharacteristicWrite]]]) {
           
#ifdef DEBUG
            NSLog(@"the charact write address:%@",charactDict[BlueCharacteristicWrite]);
#endif
            self.characteristic = characteristic;
        }
    }
}


#pragma mark CBPeripheralDelegate


-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error {
    
    if (error) {
      
        if ([self.delegate respondsToSelector:@selector(blueManagerdidWriteError:peripheral:error:)]) {
            
            [self.delegate  blueManagerdidWriteError:self peripheral:peripheral error:error];
        }
    }
    
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {

    if (_search && _needMacAddress) {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"0x2A23"]]) {
                
                NSString *value = [NSString stringWithFormat:@"%@",characteristic.value];
                NSMutableString *macString = [[NSMutableString alloc] init];
                [macString appendString:[[value substringWithRange:NSMakeRange(16, 2)] uppercaseString]];
                [macString appendString:@":"];
                [macString appendString:[[value substringWithRange:NSMakeRange(14, 2)] uppercaseString]];
                [macString appendString:@":"];
                [macString appendString:[[value substringWithRange:NSMakeRange(12, 2)] uppercaseString]];
                [macString appendString:@":"];
                [macString appendString:[[value substringWithRange:NSMakeRange(5, 2)] uppercaseString]];
                [macString appendString:@":"];
                [macString appendString:[[value substringWithRange:NSMakeRange(3, 2)] uppercaseString]];
                [macString appendString:@":"];
                [macString appendString:[[value substringWithRange:NSMakeRange(1, 2)] uppercaseString]];
                YYPeripheralModel *model = [YYPeripheralModel peripheralModel:peripheral.name address:macString peripheral:peripheral];
                [self.searchArray addObject:model];
                NSMutableArray *array = [NSMutableArray array];
                for (YYPeripheralModel *temp in self.searchArray) {
                    [array addObject:temp];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                self.saveNameBlock([array copy]);
                });

                return;
            }

        });
    }
    if (_search && [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"0x2A23"]]) {
        return;
    }
    if (self.delegate) {

        if ([self.delegate respondsToSelector:@selector(blueManagerblereceiveData:andTheData:)]) {
            
            [self.delegate blueManagerblereceiveData:self andTheData:characteristic.value];
        }
    }
}

@end
