//
//  NSObject+LXIntrospection.m
//
//  Created by 从今以后 on 15/11/16.
//  Copyright © 2015年 从今以后. All rights reserved.
//

@import ObjectiveC.runtime;
#import "NSObject+LXIntrospection.h"

#pragma clang diagnostic ignored "-Wcstring-format-directive"

#pragma mark - 格式化辅助函数 -

static NSString * LXDecodeType(const char *typeStr)
{
    // @ 开头表示对象
    if (typeStr[0] == '@') {
        // 单个 @ 表示 id 类型
        if (strlen(typeStr) == 1) return @"id";
        // @? 表示 block 类型，无法确定具体类型
        if (!strcmp(typeStr, "@?")) return @"Block";
        // 某种对象类型，类似 @"NSString" 这种格式
        NSString *result = [NSString stringWithUTF8String:typeStr];
        return [[result substringWithRange:(NSRange){2, result.length - 3}] stringByAppendingString:@" *"];
    }

    // { 开头表示结构体，类似 {CGPoint=dd} 这种格式，如果是结构体二级指针，例如 CGPoint **，格式为 {CGPoint}
    if (typeStr[0] == '{') {
        NSString *result = [NSString stringWithUTF8String:typeStr];
        NSUInteger location = [result rangeOfString:@"="].location;
        NSRange range = {1, location == NSNotFound ? result.length - 2: location - 1};
        return [result substringWithRange:range];
    }

    // ^ 开头表示指针类型，例如 ^i 表示 int *
    if (typeStr[0] == '^') {
        // ^? 表示函数指针类型，但是无法确定具体类型
        if (typeStr[1] == '?') return @"FunctionPointer";
        // 进一步确定指针类型
        NSString *decodeTypeStr = LXDecodeType([[NSString stringWithUTF8String:typeStr]
                                          substringFromIndex:1].UTF8String);
        return [NSString stringWithFormat:@"%@%@*",
                decodeTypeStr, [decodeTypeStr hasSuffix:@"*"] ? @"" : @" "];
    }

    // 某些特殊限定符
    NSString *qualifiers = nil;
    switch (typeStr[0]) {
        case 'r': qualifiers = @"const";  break;
        case 'n': qualifiers = @"in";     break;
        case 'N': qualifiers = @"inout";  break;
        case 'o': qualifiers = @"out";    break;
        case 'O': qualifiers = @"bycopy"; break;
        case 'R': qualifiers = @"byref";  break;
        case 'V': qualifiers = @"oneway"; break;
    }
    if (qualifiers) {
        return [NSString stringWithFormat:@"%@ %@", qualifiers,
                LXDecodeType([[NSString stringWithUTF8String:typeStr]
                              substringFromIndex:1].UTF8String)];
    }

    // 普通类型
    switch (typeStr[0]) {
        case 'c': return @"char";
        case 'C': return @"unsigned char";
        case 's': return @"short";
        case 'S': return @"unichar";
        case 'i': return @"int";
        case 'I': return @"unsigned int";
        case 'q': return @"long";
        case 'Q': return @"unsigned long";
        case 'f': return @"float";
        case 'd': return @"double";
        case 'D': return @"long double";
        case 'B': return @"bool";
        case 'v': return @"void";
        case '*': return @"char *";
        case '#': return @"Class";
        case ':': return @"SEL";
    }

    if (!strcmp(typeStr, @encode(va_list))) return @"va_list";

    return @"?"; // 无法确定
}

static NSString * LXFormattedPropery(objc_property_t prop)
{
    char *atomic             = "atomic";
    char *policy             = "assign";
    char getter[100]         = {};
    char setter[100]         = {};
    char *readwrite          = "";
    NSString *propertyType   = nil;
    const char *propertyName = property_getName(prop);

    uint attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(prop, &attrCount);
    for (uint idx = 0; idx < attrCount; ++idx) {
        const char *name  = attrs[idx].name;
        const char *value = attrs[idx].value;
        switch (name[0]) {
            case 'N': atomic    = "nonatomic";  break;
            case '&': policy    = "strong";     break;
            case 'C': policy    = "copy";       break;
            case 'W': policy    = "weak";       break;
            case 'R': readwrite = ", readonly"; break;
            case 'G': strcpy(getter, ", getter="); strcat(getter, value); break;
            case 'S': strcpy(setter, ", setter="); strcat(setter, value); break;
            case 'T': propertyType = LXDecodeType(value); break;
        }
    }
    free(attrs);

    return [NSString stringWithFormat:@"@property (%s, %s%s%s%s) %@%@%s",
            atomic,
            policy,
            setter,
            getter,
            readwrite,
            propertyType,
            [propertyType hasSuffix:@"*"] ? @"": @" ",
            propertyName];
}

static NSArray<NSString *> * LXMethodsForClass(Class class, NSString * type)
{
    NSMutableArray *result = [NSMutableArray new];

    uint outCount;
    Method *methods = class_copyMethodList([type isEqualToString:@"+"] ?
                                           object_getClass(class) : class, &outCount);
    for (uint i = 0; i < outCount; ++i) {

        NSString *methodDescription = nil;
        {
            char *returnType = method_copyReturnType(methods[i]);
            methodDescription = [NSString stringWithFormat:@"%@ (%@)%s",
                                 type,
                                 LXDecodeType(returnType),
                                 sel_getName(method_getName(methods[i]))];
            free(returnType);
        }

        NSMutableArray *selParts = [methodDescription componentsSeparatedByString:@":"].mutableCopy;
        {
            if (selParts.count > 1) [selParts removeLastObject]; // 移除末尾的 @""

            uint args = method_getNumberOfArguments(methods[i]);
            for (uint idx = 2; idx < args; ++idx) {
                char *argumentType = method_copyArgumentType(methods[i], idx);
                selParts[idx - 2] = [NSString stringWithFormat:@"%@:(%@)arg%d",
                                     selParts[idx - 2],
                                     LXDecodeType(argumentType),
                                     idx - 2];
                free(argumentType);
            }
        }

        selParts.count > 1 ?
        [result addObject:[selParts componentsJoinedByString:@" "]] :
        [result addObject:selParts[0]];
    }
    free(methods);

    return result;
}

static NSArray<NSString *> * LXFormattedMethodsForProtocol(Protocol *proto, BOOL isRequiredMethod, BOOL isInstanceMethod)
{
    NSMutableArray *methodsDescription = [NSMutableArray new];

    uint methodCount;
    struct objc_method_description *methods =
    protocol_copyMethodDescriptionList(proto, isRequiredMethod, isInstanceMethod,  &methodCount);
    for (uint i = 0; i < methodCount; ++i) {

        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:methods[i].types];

        NSString *methodDescription = [NSString stringWithFormat:@"%@ (%@)%s",
                                       isInstanceMethod ? @"-" : @"+",
                                       LXDecodeType(methodSignature.methodReturnType),
                                       sel_getName(methods[i].name)];

        NSMutableArray *selParts = [methodDescription componentsSeparatedByString:@":"].mutableCopy;
        {
            if (selParts.count > 1) [selParts removeLastObject]; // 移除末尾的 @""

            NSUInteger args = methodSignature.numberOfArguments;
            for (NSUInteger idx = 2; idx < args; ++idx) {
                const char *argumentType = [methodSignature getArgumentTypeAtIndex:idx];
                selParts[idx - 2] = [NSString stringWithFormat:@"%@:(%@)arg%lu",
                                     selParts[idx - 2],
                                     LXDecodeType(argumentType),
                                     idx - 2];
            }
        }

        selParts.count > 1 ?
        [methodsDescription addObject:[selParts componentsJoinedByString:@" "]] :
        [methodsDescription addObject:selParts[0]];
    }
    free(methods);

    return methodsDescription;
}

#pragma mark - 查看所有类的类名 -

NSArray<NSString *> * LXClassList()
{
    NSMutableArray<NSString *> *result = [NSMutableArray new];

    uint classesCount;
    Class *classes = objc_copyClassList(&classesCount);
    for (uint i = 0; i < classesCount; ++i) {
        [result addObject:NSStringFromClass(classes[i])];
    }
    free(classes);

    return [result sortedArrayUsingSelector:@selector(compare:)];
}

void LXPrintClassList()
{
    NSArray *classList = LXClassList();
    NSLog(@"总计：%lu\n%@", classList.count, classList);
}

#pragma mark - 查看协议中的方法和属性 -

NSDictionary<NSString *, NSArray<NSString *> *> * LXDescriptionForProtocol(Protocol *proto)
{
    NSArray *requiredMethods = nil;
    {
        NSArray *classMethods    = LXFormattedMethodsForProtocol(proto, YES, NO);
        NSArray *instanceMethods = LXFormattedMethodsForProtocol(proto, YES, YES);
        requiredMethods = [classMethods arrayByAddingObjectsFromArray:instanceMethods];
    }

    NSArray *optionalMethods = nil;
    {
        NSArray *classMethods    = LXFormattedMethodsForProtocol(proto, NO, NO);
        NSArray *instanceMethods = LXFormattedMethodsForProtocol(proto, NO, YES);
        optionalMethods = [classMethods arrayByAddingObjectsFromArray:instanceMethods];
    }

    NSMutableArray *propertyDescriptions = [NSMutableArray array];
    {
        uint propertiesCount;
        objc_property_t *properties = protocol_copyPropertyList(proto, &propertiesCount);
        for (uint i = 0; i < propertiesCount; ++i) {
            [propertyDescriptions addObject:LXFormattedPropery(properties[i])];
        }
        free(properties);
    }

    NSMutableDictionary *methodsAndProperties = [NSMutableDictionary dictionary];
    {
        if (requiredMethods.count) methodsAndProperties[@"@required"] = requiredMethods;
        if (optionalMethods.count) methodsAndProperties[@"@optional"] = optionalMethods;
        if (propertyDescriptions.count) methodsAndProperties[@"@properties"] = propertyDescriptions;
    }

    return methodsAndProperties;
}

void LXPrintDescriptionForProtocol(Protocol *proto)
{
    NSLog(@"%s\n%@", protocol_getName(proto), LXDescriptionForProtocol(proto));
}

#pragma mark -

@implementation NSObject (LXIntrospection)

#pragma mark - 查看属性 -

+ (NSArray<NSString *> *)lx_propertyList
{
    NSMutableArray *result = [NSMutableArray new];

    uint outCount;
    objc_property_t *properties = class_copyPropertyList(self, &outCount);
    for (uint i = 0; i < outCount; ++i) {
        [result addObject:LXFormattedPropery(properties[i])];
    }
    free(properties);

    return result;
}

+ (void)lx_printPropertyList
{
    NSLog(@"%s\n%@", class_getName(self), self.lx_propertyList);
}

#pragma mark - 查看实例变量 -

+ (NSArray<NSString *> *)lx_ivarList
{
    NSMutableArray *result = [NSMutableArray new];

    uint outCount;
    Ivar *ivars = class_copyIvarList(self, &outCount);
    for (uint i = 0; i < outCount; ++i) {
        NSString *type = LXDecodeType(ivar_getTypeEncoding(ivars[i]));
        NSString *ivarDescription = [NSString stringWithFormat:@"%@%@%s",
                                     type,
                                     [type hasSuffix:@"*"] ? @"" : @" ",
                                     ivar_getName(ivars[i])];
        [result addObject:ivarDescription];
    }
    free(ivars);

    return result;
}

+ (void)lx_printIvarList
{
    NSLog(@"%s\n%@", class_getName(self), self.lx_ivarList);
}

#pragma mark - 查看类方法 -

+ (NSArray<NSString *> *)lx_classMethodList
{
    return LXMethodsForClass(self, @"+");
}

+ (void)lx_printClassMethodList
{
    NSLog(@"%s\n%@", class_getName(self), self.lx_classMethodList);
}

#pragma mark - 查看实例方法 -

+ (NSArray<NSString *> *)lx_instanceMethodList
{
    return LXMethodsForClass(self, @"-");
}

+ (void)lx_printInstanceMethodList
{
    NSLog(@"%s\n%@", class_getName(self), self.lx_instanceMethodList);
}

#pragma mark - 查看采纳的协议 -

+ (NSArray<NSString *> *)lx_protocolList
{
    NSMutableArray *result = [NSMutableArray new];

    uint outCount;
    Protocol *__unsafe_unretained *protocols = class_copyProtocolList(self, &outCount);
    for (uint i = 0; i < outCount; ++i) {

        NSMutableArray *adoptedProtocolNames = [NSMutableArray new];
        {
            uint adoptedCount;
            Protocol *__unsafe_unretained *adotedProtocols = protocol_copyProtocolList(protocols[i], &adoptedCount);
            for (uint idx = 0; idx < adoptedCount; ++idx) {
                [adoptedProtocolNames addObject:
                 (NSString *)[NSString stringWithUTF8String:protocol_getName(adotedProtocols[idx])]];
            }
            free(adotedProtocols);
        }

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

    return result;
}

+ (void)lx_printProtocolList
{
    NSLog(@"%s\n%@", class_getName(self), self.lx_protocolList);
}

#pragma mark - 查看继承层级关系 -

+ (NSString *)lx_inheritanceTree
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
                                         [result appendFormat:@"\n%@", className];
                                     }];
    }

    return result;
}

+ (void)lx_printInheritanceTree
{
    NSLog(@"%s%@", class_getName(self), self.lx_inheritanceTree);
}

#pragma mark - 获取属性名数组 -

+ (NSArray<NSString *> *)lx_propertyNameList
{
    NSMutableArray *propertyArray = [NSMutableArray new];

    uint outCount;
    objc_property_t *properties = class_copyPropertyList(self, &outCount);
    for (uint i = 0; i < outCount; ++i) {
        [propertyArray addObject:[NSString stringWithUTF8String:property_getName(properties[i])]];
    }
    free(properties);

    return propertyArray;
}

- (NSArray<NSString *> *)lx_propertyNameList
{
    return self.class.lx_propertyNameList;
}

#pragma mark - 获取实例变量名数组 -

+ (NSArray<NSString *> *)lx_ivarNameList
{
    NSMutableArray *ivarArray = [NSMutableArray new];

    uint outCount;
    Ivar *ivars = class_copyIvarList(self, &outCount);
    for (uint i = 0; i < outCount; ++i) {
        [ivarArray addObject:[NSString stringWithUTF8String:ivar_getName(ivars[i])]];
    }
    free(ivars);

    return ivarArray;
}

- (NSArray<NSString *> *)lx_ivarNameList
{
    return self.class.lx_ivarNameList;
}

@end

#pragma mark - 打印对齐 -

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
