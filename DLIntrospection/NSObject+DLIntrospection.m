
//  NSObject+DLIntrospection.m
//  DLIntrospection
//
//  Created by Denis Lebedev on 12/27/12.
//  Copyright (c) 2012 Denis Lebedev. All rights reserved.
//

@import CoreGraphics;
@import ObjectiveC.runtime;
#import "NSObject+DLIntrospection.h"

#pragma clang diagnostic ignored "-Wcstring-format-directive"

///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - 用于格式化的辅助函数

static NSString * DLDecodeType(const char *typeString)
{
    // 列举了一些常用类型，缺啥补啥吧 ಥ_ಥ.
    if (!strcmp(typeString, @encode(BOOL)))          return @"BOOL";
    if (!strcmp(typeString, @encode(float)))         return @"float";
    if (!strcmp(typeString, @encode(double)))        return @"double";
    if (!strcmp(typeString, @encode(long)))          return @"long";
    if (!strcmp(typeString, @encode(unsigned long))) return @"unsigned long";
    if (!strcmp(typeString, @encode(int)))           return @"int";
    if (!strcmp(typeString, @encode(unsigned int)))  return @"unsigned int";
    if (!strcmp(typeString, @encode(void)))          return @"void";
    if (!strcmp(typeString, @encode(char)))          return @"char";
    if (!strcmp(typeString, @encode(unsigned char))) return @"unsigned char";
    if (!strcmp(typeString, @encode(char *)))        return @"char *";
    if (!strcmp(typeString, @encode(unichar)))       return @"unichar";
    if (!strcmp(typeString, @encode(va_list)))       return @"va_list";
    if (!strcmp(typeString, @encode(SEL)))           return @"SEL";
    if (!strcmp(typeString, @encode(Class)))         return @"Class";
    if (!strcmp(typeString, @encode(bool)))          return @"bool";
    if (!strcmp(typeString, "Vv"))                   return @"oneway void";

    NSString *result = [NSString stringWithUTF8String:typeString];

    // @ 表示对象类型，而 @? 表示 block 类型
    if ([result hasPrefix:@"@"])
    {
        // 单个 @ 表示 id 类型
        if (!strcmp(typeString, "@")) return @"id";
        // @? 表示某种 block 类型，但是无法确定具体类型
        if (!strcmp(typeString, "@?")) return @"Block";
        // 某种对象类型，形如 @"NSString"
        return [[result substringWithRange:(NSRange){2, result.length - 3}] stringByAppendingString:@" *"];
    }

    // 某种结构体，类似 {CGPoint=dd} 这种形式
    if ([result hasPrefix:@"{"])
    {
        // NSRange 比较特殊，是 _NSRange，因此单独处理
        if (!strcmp(typeString, @encode(NSRange))) return @"NSRange";
        return [result substringWithRange:(NSRange){1, [result rangeOfString:@"="].location - 1}];
    }

    // ^ 表示指针类型，例如 ^i 表示 int *，^{CGColor=} 表示 CGColorRef，^? 表示函数指针类型
    if ([result hasPrefix:@"^"])
    {
        // 各种结构体指针.
        if (!strcmp(typeString, @encode(CGColorRef)))      return @"CGColorRef";
        if (!strcmp(typeString, @encode(CGImageRef)))      return @"CGImageRef";
        if (!strcmp(typeString, @encode(CGContextRef)))    return @"CGContextRef";
        if (!strcmp(typeString, @encode(CFStringRef)))     return @"CFStringRef";
        if (!strcmp(typeString, @encode(CFArrayRef)))      return @"CFArrayRef";
        if (!strcmp(typeString, @encode(CFDictionaryRef))) return @"CFDictionaryRef";
        if (!strcmp(typeString, @encode(NSZone *)))        return @"NSZone *";
        if (!strcmp(typeString, @encode(CGPathRef)))       return @"CGPathRef";

        // ^? 表示函数指针类型，但是无法确定具体类型
        if (!strcmp(typeString, "^?")) return @"FunctionPointer";

        // 进一步确定具体的指针类型，二级指针不空格，例如 unichar **
        NSString *type = DLDecodeType([result substringFromIndex:1].UTF8String);
        return [NSString stringWithFormat:@"%@%@*", type, [type hasSuffix:@"*"] ? @"" : @" "];
    }

    // r 表示 const 类型
    if ([result hasPrefix:@"r"]) {
        // CGPathRef 作为属性类型时就会解析成这样.
        if (!strcmp(typeString, "r^{CGPath=}")) return @"CGPathRef";
        NSString *type = DLDecodeType([result substringFromIndex:1].UTF8String);
        return [NSString stringWithFormat:@"const %@", type];
    }

    // 无法确定类型，例如用 ? 表示的类型，只能原样返回
    return result;
}

static NSString * DLFormattedPropery(objc_property_t prop)
{
    NSMutableDictionary<NSString *, NSString *> *attributes = [NSMutableDictionary new];
    {
        uint attrCount;
        objc_property_attribute_t *attrs = property_copyAttributeList(prop, &attrCount);
        for (uint idx = 0; idx < attrCount; ++idx)
        {
            NSString *name  = [NSString stringWithUTF8String:attrs[idx].name];
            NSString *value = [NSString stringWithUTF8String:attrs[idx].value];

            attributes[name] = value;
        }
        free(attrs);
    }

    NSMutableArray<NSString *> *attrsArray = [NSMutableArray new];
    {
        [attrsArray addObject:attributes[@"N"] ? @"nonatomic" : @"atomic"];

        if (attributes[@"&"]) {
            [attrsArray addObject:@"strong"];
        }
        else if (attributes[@"C"]) {
            [attrsArray addObject:@"copy"];
        }
        else if (attributes[@"W"]) {
            [attrsArray addObject:@"weak"];
        }
        else {
            [attrsArray addObject:@"assign"];
        }

        if (attributes[@"R"]) {
            [attrsArray addObject:@"readonly"];
        }

        NSString *getter = attributes[@"G"];
        if (getter) {
            [attrsArray addObject:[NSString stringWithFormat:@"getter=%@", getter]];
        }

        NSString *setter = attributes[@"S"];
        if (setter) {
            [attrsArray addObject:[NSString stringWithFormat:@"setter=%@", setter]];
        }
    }

    NSString *propertyType = DLDecodeType(attributes[@"T"].UTF8String);

    // * 和属性名之间不加空格，例如 NSString *name
    return [NSString stringWithFormat:@"@property (%@) %@%@%s",
            [attrsArray componentsJoinedByString:@", "],
            propertyType,
            [propertyType hasSuffix:@"*"] ? @"" : @" ",
            property_getName(prop)];
}

static NSArray<NSString *> * DLMethodsForClass(Class class, NSString * type)
{
    NSMutableArray *result = [NSMutableArray new];
    {
        uint outCount;
        Method *methods = class_copyMethodList([type isEqualToString:@"+"] ?
                                               object_getClass(class) : class, &outCount);
        for (uint i = 0; i < outCount; ++i)
        {
            char *returnType = method_copyReturnType(methods[i]);
            NSString *methodDescription = [NSString stringWithFormat:@"%@ (%@)%s",
                                           type,
                                           DLDecodeType(returnType),
                                           sel_getName(method_getName(methods[i]))];
            free(returnType);

            NSMutableArray *selParts = [methodDescription componentsSeparatedByString:@":"].mutableCopy;

            if (selParts.count > 1) {
                [selParts removeLastObject]; // 移除末尾的 @""
            }

            {
                uint args = method_getNumberOfArguments(methods[i]);
                for (uint idx = 2; idx < args; ++idx)
                {
                    char *argumentType = method_copyArgumentType(methods[i], idx);
                    selParts[idx - 2] = [NSString stringWithFormat:@"%@:(%@)arg%d",
                                         selParts[idx - 2],
                                         DLDecodeType(argumentType),
                                         idx - 2];
                    free(argumentType);
                }
            }

            if (selParts.count > 1) {
                [result addObject:[selParts componentsJoinedByString:@" "]];
            } else {
                [result addObject:selParts[0]];
            }
        }
        free(methods);
    }
    return result;
}

static NSArray<NSString *> * DLFormattedMethodsForProtocol(Protocol *proto, BOOL isRequiredMethod, BOOL isInstanceMethod)
{
    NSMutableArray *methodsDescription = [NSMutableArray new];
    {
        uint methodCount;
        struct objc_method_description *methods = protocol_copyMethodDescriptionList(proto, isRequiredMethod, isInstanceMethod, &methodCount);
        for (uint i = 0; i < methodCount; ++i)
        {
            NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:methods[i].types];

            NSString *methodDescription = [NSString stringWithFormat:@"%@ (%@)%s",
                                           isInstanceMethod ? @"-" : @"+",
                                           DLDecodeType(methodSignature.methodReturnType),
                                           sel_getName(methods[i].name)];


            NSMutableArray *selParts = [methodDescription componentsSeparatedByString:@":"].mutableCopy;

            if (selParts.count > 1) {
                [selParts removeLastObject]; // 移除末尾的 @""
            }

            {
                NSUInteger args = methodSignature.numberOfArguments;
                for (NSUInteger idx = 2; idx < args; ++idx)
                {
                    const char *argumentType = [methodSignature getArgumentTypeAtIndex:idx];
                    selParts[idx - 2] = [NSString stringWithFormat:@"%@:(%@)arg%lu",
                                         selParts[idx - 2],
                                         DLDecodeType(argumentType),
                                         idx - 2];
                }
            }

            if (selParts.count > 1) {
                [methodsDescription addObject:[selParts componentsJoinedByString:@" "]];
            } else {
                [methodsDescription addObject:selParts[0]];
            }
        }
        free(methods);
    }
    return methodsDescription;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - 查看所有类的类名

NSArray<NSString *> * DLClassList()
{
    NSMutableArray<NSString *> *result = [NSMutableArray new];
    {
        uint classesCount;
        Class *classes = objc_copyClassList(&classesCount);
        for (uint i = 0; i < classesCount; ++i) {
            [result addObject:NSStringFromClass(classes[i])];
        }
        free(classes);
    }
    return [result sortedArrayUsingSelector:@selector(compare:)];
}

void DLPrintClassList()
{
    NSLog(@"%@", DLClassList());
}

#pragma mark - 查看协议中的方法和属性

NSDictionary<NSString *, NSArray<NSString *> *> * DLDescriptionForProtocol(Protocol *proto)
{
    NSArray *requiredMethods = nil;
    {
        NSArray *classMethods    = DLFormattedMethodsForProtocol(proto, YES, NO);
        NSArray *instanceMethods = DLFormattedMethodsForProtocol(proto, YES, YES);

        requiredMethods = [classMethods arrayByAddingObjectsFromArray:instanceMethods];
    }

    NSArray *optionalMethods = nil;
    {
        NSArray *classMethods    = DLFormattedMethodsForProtocol(proto, NO, NO);
        NSArray *instanceMethods = DLFormattedMethodsForProtocol(proto, NO, YES);

        optionalMethods = [classMethods arrayByAddingObjectsFromArray:instanceMethods];
    }

    NSMutableArray *propertyDescriptions = [NSMutableArray array];
    {
        uint propertiesCount;
        objc_property_t *properties = protocol_copyPropertyList(proto, &propertiesCount);
        for (uint i = 0; i < propertiesCount; ++i) {
            [propertyDescriptions addObject:DLFormattedPropery(properties[i])];
        }
        free(properties);
    }

    NSMutableDictionary *methodsAndProperties = [NSMutableDictionary dictionary];
    {
        if (requiredMethods.count) {
            methodsAndProperties[@"@required"] = requiredMethods;
        }

        if (optionalMethods.count) {
            methodsAndProperties[@"@optional"] = optionalMethods;
        }

        if (propertyDescriptions.count) {
            methodsAndProperties[@"@properties"] = propertyDescriptions;
        }
    }
    return methodsAndProperties;
}

void DLPrintDescriptionForProtocol(Protocol *proto)
{
    NSLog(@"%s\n%@", protocol_getName(proto), DLDescriptionForProtocol(proto));
}

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation NSObject (DLIntrospection)

#pragma mark - 查看属性

+ (NSArray<NSString *> *)dl_propertyList
{
    NSMutableArray *result = [NSMutableArray new];
    {
        uint outCount;
        objc_property_t *properties = class_copyPropertyList(self, &outCount);
        for (uint i = 0; i < outCount; ++i) {
            [result addObject:DLFormattedPropery(properties[i])];
        }
        free(properties);
    }
    return result;
}

+ (void)dl_printPropertyList
{
    NSLog(@"%s\n%@", class_getName(self), self.dl_propertyList);
}

#pragma mark - 查看实例变量

+ (NSArray<NSString *> *)dl_ivarList
{
    NSMutableArray *result = [NSMutableArray new];
    {
        uint outCount;
        Ivar *ivars = class_copyIvarList(self, &outCount);
        for (uint i = 0; i < outCount; ++i) {
            // * 和实例变量名之间不加空格，例如 NSString *_name
            NSString *type = DLDecodeType(ivar_getTypeEncoding(ivars[i]));
            NSString *ivarDescription = [NSString stringWithFormat:@"%@%@%s",
                                         type,
                                         [type hasSuffix:@"*"] ? @"" : @" ",
                                         ivar_getName(ivars[i])];
            [result addObject:ivarDescription];
        }
        free(ivars);
    }
    return result;
}

+ (void)dl_printIvarList
{
    NSLog(@"%s\n%@", class_getName(self), self.dl_ivarList);
}

///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - 查看类方法

+ (NSArray<NSString *> *)dl_classMethodList
{
    return DLMethodsForClass(self, @"+");
}

+ (void)dl_printClassMethodList
{
    NSLog(@"%s\n%@", class_getName(self), self.dl_classMethodList);
}

#pragma mark - 查看实例方法

+ (NSArray<NSString *> *)dl_instanceMethodList
{
    return DLMethodsForClass(self, @"-");
}

+ (void)dl_printInstanceMethodList
{
    NSLog(@"%s\n%@", class_getName(self), self.dl_instanceMethodList);
}

///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - 查看采纳的协议

+ (NSArray<NSString *> *)dl_protocolList
{
    NSMutableArray *result = [NSMutableArray new];
    {
        uint outCount;
        Protocol *__unsafe_unretained *protocols = class_copyProtocolList(self, &outCount);
        for (uint i = 0; i < outCount; ++i)
        {
            uint adoptedCount;
            Protocol *__unsafe_unretained *adotedProtocols = protocol_copyProtocolList(protocols[i], &adoptedCount);

            NSMutableArray *adoptedProtocolNames = [NSMutableArray array];
            {
                for (uint idx = 0; idx < adoptedCount; ++idx) {
                    [adoptedProtocolNames addObject:
                     (NSString *)[NSString stringWithUTF8String:protocol_getName(adotedProtocols[idx])]];
                }
            }

            free(adotedProtocols);

            NSMutableString *protocolDescription = [NSMutableString stringWithUTF8String:protocol_getName(protocols[i])];
            {
                if (adoptedProtocolNames.count) {
                    [protocolDescription appendFormat:@" <%@>",
                     [adoptedProtocolNames componentsJoinedByString:@", "]];
                }
            }
            
            [result addObject:protocolDescription];
        }
        free(protocols);
    }
    return result;
}

+ (void)dl_printProtocolList
{
    NSLog(@"%s\n%@", class_getName(self), self.dl_protocolList);
}

///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - 查看继承层级关系

+ (NSString *)dl_inheritanceTree
{
    NSMutableArray<NSString *> *classNames = [NSMutableArray new];
    {
        Class superClass = self;
        do {
            [classNames addObject:[NSString stringWithFormat:@"• %s", class_getName(superClass)]];
        } while ((superClass = class_getSuperclass(superClass)));
    }

    NSMutableString *result = [NSMutableString new];
    {
        NSUInteger count = classNames.count;
        [classNames enumerateObjectsWithOptions:NSEnumerationReverse
                                     usingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                         NSMutableString *className = obj.mutableCopy;
                                         for (NSUInteger i = 0; count - 1 - idx > i; ++i) {
                                             [className insertString:@" " atIndex:0];
                                         }
                                         [result appendFormat:@"%@%@",
                                          idx == count - 1 ? @"" : @"\n",
                                          className];
                                     }];
    }
    return result;
}

+ (void)dl_printInheritanceTree
{
    NSLog(@"%s\n%@", class_getName(self), self.dl_inheritanceTree);
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - 打印对齐

#if ENABLE_LOG_ALIGNMENT

@implementation NSArray (LXLogAlignment)

- (NSString *)debugDescription
{
    NSMutableString *description = [NSMutableString stringWithString:@"(\n"];

    for (id obj in self) {
        NSMutableString *subDescription = [NSMutableString stringWithFormat:@"    %@,\n", obj];
        if ([obj isKindOfClass:NSArray.self] || [obj isKindOfClass:NSDictionary.self]) {
            [subDescription replaceOccurrencesOfString:@"\n"
                                            withString:@"\n    "
                                               options:(NSStringCompareOptions)0
                                                 range:(NSRange){0,subDescription.length - 1}];
        }
        [description appendString:subDescription];
    }

    [description appendString:@")"];

    return description;
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return self.debugDescription;
}

@end

@implementation NSDictionary (LXLogAlignment)

- (NSString *)debugDescription
{
    NSMutableString *description = [NSMutableString stringWithString:@"{\n"];

    [self enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
        NSMutableString *subDescription = [NSMutableString stringWithFormat:@"    %@ = %@;\n", key, obj];
        if ([obj isKindOfClass:NSArray.self] || [obj isKindOfClass:NSDictionary.self]) {
            [subDescription replaceOccurrencesOfString:@"\n"
                                            withString:@"\n    "
                                               options:(NSStringCompareOptions)0
                                                 range:(NSRange){0,subDescription.length - 1}];
        }
        [description appendString:subDescription];
    }];

    [description appendString:@"}"];

    return description;
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return self.debugDescription;
}

@end

#endif
