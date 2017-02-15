# CoreBlue
a sample Package for ios blue4.0
first set the blueManager delegate property then call the scan method
```
 [YYBlueManger sharedManger].delegate = self;
 [[YYBlueManger sharedManger] scan];
```
Now in bellow method connect you device
```
-(void)blueManagerblescanBluDevice:(YYBlueManger *)manager andTheDevice:(CBPeripheral *)peripheral {
    
    //NSLog(@"%@",peripheral.name);
    if ([peripheral.name isEqualToString:@"you peripheral name"]) {
        [[YYBlueManger sharedManger] connect:peripheral orTheDeviceName:nil];
    }
}
```
give me the servic address by
```
-(NSArray *)blueManagerServerAdrres:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral {
    
    return @[@"0xXXXX"];
}

```
give me the Charact address,BlueCharacteristicWrite and BlueCharacteristicRead the key for write chara and read chara
```
-(NSDictionary *)blueManagerCharacteristicsAdrres:(YYBlueManger *)manager peripheral:(CBPeripheral *)peripheral {
    
    return @{BlueCharacteristicWrite:@"0xXXXX",BlueCharacteristicRead:@"0xXXXX"};
}

```
now you can use bellow method write data ,it have 10 seconds timeout , you can review  the detail implement
```
[[YYBlueManger sharedManger] writeDataToDevice:nil writeHandle:nil];
```
of course,privde the connect state callback you can see the .h file

when you want to search the same kind perpheral,you can use
```
-(void)scanTheSameNameDeviceByTheSpeicfedName:(NSString *)string
                                   isGet:(BOOL)isGet
                               needMacAddress:(BOOL)needMacAddress
                                        block:(void (^)(NSArray *array))sameNameDeviceArray;

```
if you want to Mac address needMacAddress set YES,you can obtain the mac address in YYPeripheralModel's property,
of course only the connected device can obtain Mac address
in the end ,i segguset you set the delegate be nil when the controller dealloc
