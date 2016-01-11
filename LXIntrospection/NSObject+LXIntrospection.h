//
//  NSObject+LXIntrospection.h
//
//  Created by 从今以后 on 15/11/16.
//  Copyright © 2015年 从今以后. All rights reserved.
//

@import Foundation;

/*
 开启后会通过分类方法覆盖 NSArray 和 NSDictionary 的 debugDescription 和 descriptionWithLocale: 方法。
 */
#define ENABLE_LOG_ALIGNMENT 1

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (LXIntrospection)

///-----------------------------
/// @name 格式化的变量列表和属性列表
///-----------------------------

+ (NSArray<NSString *> *)lx_ivarList;
+ (NSArray<NSString *> *)lx_propertyList;

+ (void)lx_printIvarList;
+ (void)lx_printPropertyList;

///-------------------------------
/// @name 格式化的类方法和实例方法列表
///-------------------------------

+ (NSArray<NSString *> *)lx_classMethodList;
+ (NSArray<NSString *> *)lx_instanceMethodList;

+ (void)lx_printClassMethodList;
+ (void)lx_printInstanceMethodList;

///---------------------------------------
/// @name 格式化的类继承层级关系和采纳的协议列表
///---------------------------------------

+ (NSString *)lx_inheritanceTree;
+ (NSArray<NSString *> *)lx_protocolList;

+ (void)lx_printProtocolList;
+ (void)lx_printInheritanceTree;

///-----------------------------
/// @name 获取属性名和实例变量名数组
///-----------------------------

/// 获取实例变量名数组。
+ (NSArray<NSString *> *)lx_ivarNameList;
/// 获取实例变量名数组。
- (NSArray<NSString *> *)lx_ivarNameList;

/// 获取属性名数组。
+ (NSArray<NSString *> *)lx_propertyNameList;
/// 获取属性名数组。
- (NSArray<NSString *> *)lx_propertyNameList;

@end

///--------------
/// @name 全部类名
///--------------

/// 获取全部类名。
NSArray<NSString *> * LXClassList();
/// 打印全部类名。
void LXPrintClassList();

///---------------------
/// @name 格式化的协议声明
///---------------------

/// 获取格式化的指定协议声明。
NSDictionary<NSString *, NSArray<NSString *> *> * LXDescriptionForProtocol(Protocol *proto);
/// 打印格式化的指定协议声明。
void LXPrintDescriptionForProtocol(Protocol *proto);

NS_ASSUME_NONNULL_END
