//
//  main.m
//  Demo
//
//  Created by 从今以后 on 15/11/16.
//  Copyright © 2015年 从今以后. All rights reserved.
//

@import Foundation;
#import "NSObject+LXIntrospection.h"

@interface Foo : NSObject {
    id xxx[1];

    NSNumber *fsaf[1][2][3];
//
//    int *i[1];
//    int *ii[2];
//    int **iii[3];
//
//    CGRect c[1];
//    CGRect *cc[2];
//    CGRect **ccc[3];
}
@end
@implementation Foo
@end

int main(int argc, const char * argv[]) {

    [Foo lx_printIvarList];
//    [NSObject lx_printIvarList];
//    [NSObject lx_printPropertyList];

//    [NSObject lx_printClassMethodList];
//    [NSObject lx_printInstanceMethodList];

//    [NSData lx_printProtocolList];
//    [NSMutableArray lx_printInheritanceTree];

//    LXPrintClassList();
//    LXPrintDescriptionForProtocol(@protocol(NSObject));

    
//    NSLog(@"%@", [NSObject lx_ivarList]);
//    NSLog(@"%@", [NSObject lx_propertyList]);

//    NSLog(@"%@", [NSObject lx_classMethodList]);
//    NSLog(@"%@", [NSObject lx_instanceMethodList]);

//    NSLog(@"%@", [NSData lx_protocolList]);
//    NSLog(@"%@", [NSMutableArray lx_inheritanceTree]);

//    NSLog(@"%@", LXClassList());
//    NSLog(@"%@", LXDescriptionForProtocol(@protocol(NSObject)));

    return 0;
}
