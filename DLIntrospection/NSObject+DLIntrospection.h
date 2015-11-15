//
//  NSObject+DLIntrospection.h
//  DLIntrospection
//
//  Created by Denis Lebedev on 12/27/12.
//  Copyright (c) 2012 Denis Lebedev. All rights reserved.
//

@import Foundation;

/** 开启后会通过分类方法覆盖 NSArray 和 NSDictionary 的 debugDescription 方法. */
#define ENABLE_LOG_ALIGNMENT 1

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (DLIntrospection)

/**
 *  获取继承层级关系的描述.
 */
+ (NSString *)dl_inheritanceTree;

/**
 *  获取类中所有属性的描述.
 */
+ (NSArray<NSString *> *)dl_properties;

/**
 *  获取类中所有实例变量的描述.
 */
+ (NSArray<NSString *> *)dl_instanceVariables;

/**
 *  获取类中所有类方法的描述.
 */
+ (NSArray<NSString *> *)dl_classMethods;

/**
 *  获取类中所有实例方法的描述.
 */
+ (NSArray<NSString *> *)dl_instanceMethods;

/**
 *  获取类采纳的所有协议的描述.
 */
+ (NSArray<NSString *> *)dl_adoptedProtocols;

@end

/**
 *  获取系统中注册的所有类的类名.
 */
NSArray<NSString *> * DLClassList();

/**
 *  获取协议中的方法和属性的描述.
 */
NSDictionary<NSString *, NSString *> * DLDescriptionForProtocol(Protocol *proto);

NS_ASSUME_NONNULL_END
