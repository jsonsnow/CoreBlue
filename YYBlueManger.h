//
//  YYBlueManger.h
//  YYBlueTool
//
//  Created by MYO on 16/3/23.
//  Copyright © 2016年 MYO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

FOUNDATION_EXPORT  NSString *const BlueCharacteristicRead;
FOUNDATION_EXPORT  NSString *const BlueCharacteristicWrite;

typedef NS_ENUM(NSUInteger, YYBlueConnectState) {
    
    YYBlueConnectStateDefault = 0,
    YYBlueConnectStateConnecting,
    YYBlueConnectStateConnected,
    YYBlueConnectStateCutConnect,
    YYBlueConnectStateFailedConnect
};

typedef NS_OPTIONS(NSUInteger, YYBlueManagerState) {
    
    YYBlueManagerStateDefault = 0,
    YYBlueManagerStatePoweredOn,
    YYBlueManagerStateStateUnknown,
    YYBlueManagerStateUnsupported,
    YYBlueManagerStateUnauthorized,
    YYBlueManagerStatePoweredOff,
    YYBlueManagerStateResetting
};
@class YYBlueManger;
@protocol YYBlueMangerDelegate <NSObject>

@required

/**
 *  扫描蓝牙设备时，当搜索到新的蓝牙设备时候执行，一般在这个回调中进行对应外设的连接
 *
 *  @param manager self
 *  @param peripheral 搜索到的新蓝牙设备
 */
-(void)blueManagerblescanBluDevice:(YYBlueManger *)manager andTheDevice:(CBPeripheral *)peripheral;

/**
 连接成功的时候外设需要进行查找的服务地址

 @param manager    self
 @param peripheral 所连接的外设

 @return 该外设存在的服务地址
 */
-(NSArray *)blueManagerServerAdrres:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral;

/**
 服务对应的特性值，特性值分write 和 read 存在返回的字典中，分别以BlueCharacteristicWrite 和 BlueCharacteristicRead指定
 
 @see BlueCharacteristicWrite
 @see BlueCharacteristicRead

 @param manager    self
 @param peripheral peripheral

 @return 特性值地址
 */
-(NSDictionary *)blueManagerCharacteristicsAdrres:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral;


/**
 外设连接成功

 @param manager    self
 @param peripheral peripheral
 */
-(void)blueManagerdidConnectSuccees:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral;


/**
 外设断开连接

 @param manager    self
 @param peripheral peripheral
 @param error      error
 */
-(void)blueManagerCutConnect:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral error:(NSError *)error;


/**
 外设连接失败

 @param manager    self
 @param peripheral peripheral
 @param error      error
 */
-(void)blueManagerFailedConnect:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral error:(NSError *)error;

@optional

-(void)blueManagerdidWriteError:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral error:(NSError *)error;
/**
 *  回传用户手机的蓝牙状态
 *
 *  @param manager self
 *  @param status  蓝牙状态
 */

-(void)blueManagerbleStausForCurerntPhone:(YYBlueManger *)manager andTheStauts:(YYBlueManagerState)status;


/**
 这个方法当手机无法正常开启蓝牙的时候调用，建议实现来提示用户检测蓝牙设置,-(void)blueManagerbleStausForCurerntPhone:(YYBlueManger *)manager andTheStauts:(YYBlueManagerState)status该方法回调所有状态

 @param manager self
 @param statu   statu;
 */
-(void)blueManagerFailedState:(YYBlueManger *)manager statu:(YYBlueManagerState)statu;

/**
 *  接收到蓝牙设备发送的数据时候执行
 *
 *  @param manager self
 *  @param data    蓝牙设备发送回来的数据
 */

-(void)blueManagerblereceiveData:(YYBlueManger *)manager andTheData:(NSData *)data;


@end

@interface YYBlueManger : NSObject

@property (nonatomic, weak) id<YYBlueMangerDelegate> delegate;
@property (nonatomic, assign,readonly) BOOL needMacAddress;
@property (nonatomic, assign, readonly) YYBlueConnectState connectState;
@property (nonatomic, assign, readonly) YYBlueManagerState managerState;

-(instancetype)init UNAVAILABLE_ATTRIBUTE;
+(instancetype)new UNAVAILABLE_ATTRIBUTE;

+(instancetype)sharedManger;

/**
 *  扫描蓝牙设备
 */
-(void)scan;

///停止搜索
-(void)stop;

/**
 搜索指定名称的外设，sameNameDeviceArray回调结果,get == YES用于初始化界面的时候，managerCenter不scan，拿已存在的数据进行回调，NO:如点击搜索的时候managerCenter进行scan

 @param sameNameDeviceArray sameNameDeviceArray
 @param string              name
 @param isGet               get
 @warning 不搜索指定外设的时候，最好调用一下stopSearchSameNameDevice
 */
-(void)scanTheSameNameDeviceByTheSpeicfedName:(NSString *)string
                                   isGet:(BOOL)isGet
                               needMacAddress:(BOOL)needMacAddress
                                        block:(void (^)(NSArray *array))sameNameDeviceArray;
-(void)stopSearchSameNameDevice;

-(void)connect:(CBPeripheral *)peripheral orTheDeviceName:(NSString *)name;

-(void)cancelPeripheralConnection:(CBPeripheral *)peripheral;


/**
 同类型外设之间进行切换的时候调用词方法

 @param peripheral 指定的外设
 */
-(void)resetPeripheralConnention:(CBPeripheral *)peripheral;

-(void)removeAllDevice;


/**
 写数据

 @param data        data
 @param writeHandle nil(通过delegate回调)
 */
-(void)writeDataToDevice:(NSData *)data writeHandle:(void(^)(NSError *error))writeHandle;



@end
