# DLIntrospection

这是一个简单的`NSObject`分类，改进自 [garnett/DLIntrospection](https://github.com/garnett/DLIntrospection)，可以查看类中的方法、实例变量、属性、协议等等，并做了格式化和类型解析处理，使日志信息更加美观、详细。在原作者的基础上修复了一些小问题，完善了对结构体类型的解析，但是对象类型的方法参数依旧只能解析成`id`类型。

## 查看实例方法

```Objective-C
(lldb) po [UIView dl_instanceMethods]
(
    - (void)_web_setSubviews:(id)arg0,
    - (id)_recursiveFindDescendantScrollViewAtPoint:(CGPoint)arg0 withEvent:(id)arg1,
    - (id)_findDescendantViewAtPoint:(CGPoint)arg0 withEvent:(id)arg1,
    - (BOOL)_accessibilityCanBecomeNativeFocused,
    ...
)
```

## 查看类方法

```Objective-C
(lldb) po [UIView dl_classMethods]
(
    + (id)_axFocusedWindowSubviews,
    + (id)_accessibilityTitleForSystemTag:(long)arg0,
    + (Class)safeCategoryBaseClass,
    + (void)_accessibilityPerformValidations:(id)arg0,
    + (id)_accessibilityElementsAndContainersDescendingFromViews:(id)arg0 options:(id)arg1 sorted:(BOOL)arg2,
    ...
)
```

## 查看属性

```Objective-C
(lldb) po [UIView dl_properties]
(
    @property (nonatomic, assign) int action,
    @property (atomic, copy, readonly) NSString *description,
    @property (nonatomic, assign) CGAffineTransform transform,
    @property (nonatomic, assign) BOOL skipsSubviewEnumeration,
    @property (nonatomic, strong) UIColor *interactionTintColor,
    @property (nonatomic, assign, readonly) CGSize _sensitivitySize,
    @property (nonatomic, weak, readonly) UIView *preferredFocusedView,
    @property (atomic, assign, readonly) NSLayoutXAxisAnchor *leadingAnchor,
    @property (nonatomic, assign, getter=_viewDelegate, setter=_setViewDelegate:) UIViewController *viewDelegate,
    ...
)
```

## 查看实例变量

```Objective-C
(lldb) po [UIView dl_instanceVariables]
(
    NSMutableArray *_constraintsExceptingSubviewAutoresizingConstraints,
    UITraitCollection *_cachedTraitCollection,
    CALayer *_layer,
    CALayer *_layerRetained,
    id _gestureInfo,
    NSMutableArray *_gestureRecognizers,
    NSArray *_subviewCache,
    float _charge,
    UIEdgeInsets _inferredLayoutMargins,
    ...
)
```

## 查看继承层级关系

```Objective-C
(lldb) po [UIButton dl_inheritanceTree]

• NSObject
 • UIResponder
  • UIView
   • UIControl
    • UIButton
```

## 查看采纳的协议

```Objective-C
(lldb) po [UIView dl_adoptedProtocols]
(
    _UIScrollNotification <NSObject>,
    UITextEffectsOrdering,
    NSISVariableDelegate <NSObject>,
    _UILayoutItem <NSLayoutItem>,
    NSISEngineDelegate <NSObject>,
    _UITraitEnvironmentInternal <UITraitEnvironment>,
    _UIFocusEnvironmentInternal <UIFocusEnvironment>,
	...
)
```

## 查看协议内容

```Objective-C
NSLog(@"%@", DLDescriptionForProtocol(@protocol(NSObject)));

{
    @optional = (
        - (id)debugDescription,
    );
    @properties = (
        @property (atomic, assign, readonly) unsigned long hash,
        @property (atomic, assign, readonly) Class superclass,
        @property (atomic, copy, readonly) NSString *description,
        @property (atomic, copy, readonly) NSString *debugDescription,
    );
    @required = (
        - (NSZone *)zone,
        - (id)retain,
        - (oneway void)release,
        - (id)autorelease,
        - (unsigned long)retainCount,
        - (id)description,
        - (BOOL)isKindOfClass:(Class)arg0,
        - (unsigned long)hash,
        - (BOOL)isEqual:(id)arg0,
        - (BOOL)respondsToSelector:(SEL)arg0,
        - (id)self,
        - (id)performSelector:(SEL)arg0,
        - (id)performSelector:(SEL)arg0 withObject:(id)arg1,
        - (BOOL)conformsToProtocol:(id)arg0,
        - (id)performSelector:(SEL)arg0 withObject:(id)arg1 withObject:(id)arg2,
        - (BOOL)isProxy,
        - (BOOL)isMemberOfClass:(Class)arg0,
        - (Class)superclass,
        - (Class)class,
    );
}
```

## 查看系统中所有类

```Objective-C
(lldb) po DLClassList()
(
    ABAnyValuePredicate,
    ABCCallbackInvoker,
    ABDataCollection,
    ...
    UIBarItemAccessibility,
    UIBezierPath,
    UIBlurEffect,
    ...
    ___UIViewServiceInterfaceConnectionRequestAccessibility_super,
)
```
