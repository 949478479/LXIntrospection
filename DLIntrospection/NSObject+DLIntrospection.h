//
//  NSObject+DLIntrospection.h
//  DLIntrospection
//
//  Created by Denis Lebedev on 12/27/12.
//  Copyright (c) 2012 Denis Lebedev. All rights reserved.
//

@import Foundation;

/** 开启后会通过分类方法覆盖 NSArray 和 NSDictionary 的 debugDescription 和 descriptionWithLocale: 方法. */
#define ENABLE_LOG_ALIGNMENT 1

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (DLIntrospection)

/**
 *  获取类中所有属性的描述.
 */
+ (NSArray<NSString *> *)dl_properties;

/**
 *  打印类中所有属性的描述.
 */
+ (void)dl_printProperties;

/**
 *  获取类中所有实例变量的描述.
 */
+ (NSArray<NSString *> *)dl_instanceVariables;

/**
 *  打印类中所有实例变量的描述.
 */
+ (void)dl_printInstanceVariables;

/**
 *  获取类中所有类方法的描述.
 */
+ (NSArray<NSString *> *)dl_classMethods;

/**
 *  打印类中所有类方法的描述.
 */
+ (void)dl_printClassMethods;

/**
 *  获取类中所有实例方法的描述.
 */
+ (NSArray<NSString *> *)dl_instanceMethods;

/**
 *  打印类中所有实例方法的描述.
 */
+ (void)dl_printInstanceMethods;

/**
 *  获取类采纳的所有协议的描述.
 */
+ (NSArray<NSString *> *)dl_adoptedProtocols;

/**
 *  打印类采纳的所有协议的描述.
 */
+ (void)dl_printAdoptedProtocols;

/**
 *  获取继承层级关系的描述.
 */
+ (NSString *)dl_inheritanceTree;

/**
 *  打印继承层级关系的描述.
 */
+ (void)dl_printInheritanceTree;

@end

/**
 *  获取系统中注册的所有类的类名.
 */
NSArray<NSString *> * DLClassList();

/**
 *  打印系统中注册的所有类的类名.
 */
void DLPrintClassList();

/**
 *  获取协议中的方法和属性的描述.
 */
NSDictionary<NSString *, NSArray<NSString *> *> * DLDescriptionForProtocol(Protocol *proto);

/**
 *  打印协议中的方法和属性的描述.
 */
void DLPrintDescriptionForProtocol(Protocol *proto);

NS_ASSUME_NONNULL_END
