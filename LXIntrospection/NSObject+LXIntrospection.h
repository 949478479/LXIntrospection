//
//  NSObject+LXIntrospection.h
//
//  Created by 从今以后 on 15/11/16.
//  Copyright © 2015年 从今以后. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (LXIntrospection)

///---------------------------
/// @name 变量和属性格式化描述列表
///---------------------------

+ (NSArray<NSString *> *)lx_ivarDescriptionList;
+ (NSArray<NSString *> *)lx_propertyDescriptionList;

+ (void)lx_printIvarDescriptionList;
+ (void)lx_printPropertyDescriptionList;

///--------------------------------
/// @name 类方法和实例方法格式化描述列表
///--------------------------------

+ (NSArray<NSString *> *)lx_classMethodDescriptionList;
+ (NSArray<NSString *> *)lx_instanceMethodDescriptionList;

+ (void)lx_printClassMethodDescriptionList;
+ (void)lx_printInstanceMethodDescriptionList;

///----------------------------------------
/// @name 类继承层级关系和采纳的协议格式化描述列表
///----------------------------------------

+ (NSString *)lx_inheritanceTree;
+ (NSArray<NSString *> *)lx_adoptedProtocolDescriptionList;

+ (void)lx_printAdoptedProtocolDescriptionList;
+ (void)lx_printInheritanceTree;

///-----------------------------
/// @name 获取属性名和实例变量名数组
///-----------------------------

/// 获取实例变量名数组
+ (NSArray<NSString *> *)lx_ivarNameList;

/// 获取属性名数组
+ (NSArray<NSString *> *)lx_propertyNameList;

@end

///--------------
/// @name 全部类名
///--------------

/// 获取全部类名
NSArray<NSString *> *LXClassNameList();
/// 打印全部类名
void LXPrintClassNameList();

///---------------------
/// @name 格式化的协议声明
///---------------------

/// 获取指定协议的格式化描述（不包括继承部分）
NSDictionary<NSString *, NSArray<NSString *> *> *LXProtocolDescription(Protocol *proto);
/// 打印指定协议的格式化描述（不包括继承部分）
void LXPrintDescriptionForProtocol(Protocol *proto);

NS_ASSUME_NONNULL_END
