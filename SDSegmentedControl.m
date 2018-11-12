//
//  SDSegmentedControl.m
//  Created by Olivier Poitrey on 22/09/12.
//  Contributed by Marius Rackwitz on 19/10/12
//

#import "SDSegmentedControl.h"
#import <UIScrollView+AtkDragAndDrop.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Constants

const NSTimeInterval kSDSegmentedControlDefaultDuration = 0.2;
const NSTimeInterval kSDSegmentedControlInsertionRemovingDuration = 0.4;
const CGFloat kSDSegmentedControlArrowSize = 6.5;
const CGFloat kSDSegmentedControlInterItemSpace = 30.0;
const UIEdgeInsets kSDSegmentedControlStainEdgeInsets = {-2, -14, -4, -14};
const CGSize kSDSegmentedControlImageSize = {18, 18};

const CGFloat kSDSegmentedControlScrollOffset = 20;
const CGFloat kSDSegmentViewIsNewCircleDiameter = 6;

struct SDSegmentedStainViewDistanceStruct {
    NSInteger index;
    CGFloat distance;
};

@interface SDSegmentView (Private)

- (CGRect)innerFrame;

@end

@interface SDSegmentedControl () <UIScrollViewDelegate>

@property (strong, nonatomic) NSMutableArray *items;
@property (strong, nonatomic) UIView *selectedStainView;
@property (assign, nonatomic) NSInteger lastSelectedSegmentIndex;
@property (strong, nonatomic) CAShapeLayer *borderBottomLayer;
@property (assign, nonatomic) BOOL isScrollingBySelection;
@property (copy,   nonatomic) void (^lastCompletionBlock)();
@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;
@property (assign, nonatomic) CGPoint previousScrollViewOffset;
@property (strong, nonatomic) UIScrollView *scrollView;

@end

@implementation SDSegmentedControl
{
    NSInteger _selectedSegmentIndex;
}

+ (Class)layerClass
{
    return CAShapeLayer.class;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithItems:(NSArray *)items
{
    self = [super init];
    if (self)
    {
        [items enumerateObjectsUsingBlock:^(id title, NSUInteger idx, BOOL *stop)
        {
            [self insertSegmentWithTitle:title atIndex:idx animated:NO];
        }];
    }
    return self;
}

- (void)awakeFromNib
{
    [self commonInit];
    _selectedSegmentIndex = super.selectedSegmentIndex;
    for (NSInteger i = 0; i < super.numberOfSegments; i++)
    {
        [self insertSegmentWithTitle:[super titleForSegmentAtIndex:i] atIndex:i animated:NO];
    }
    [super removeAllSegments];
}

- (void)commonInit
{
    // Default height
    CGRect frame = self.frame;
    frame.size.height = 43;
    self.frame = frame;

    // Init properties
    self.lastSelectedSegmentIndex = UISegmentedControlNoSegment;
    _selectedSegmentIndex = UISegmentedControlNoSegment;
    _arrowHeightFactor = -1.0;
    _arrowPosition = SDSegmentedArrowPositionBottom;
    _interItemSpace = kSDSegmentedControlInterItemSpace;
    _stainEdgeInsets = kSDSegmentedControlStainEdgeInsets;

    _items = NSMutableArray.new;
    // Appearance properties
    _animationDuration = kSDSegmentedControlDefaultDuration;
    _arrowSize = kSDSegmentedControlArrowSize;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Reset UIKit original widget
    for (UIView *subview in self.subviews)
    {
        [subview removeFromSuperview];
    }
    
    // Init layer
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    self.backgroundColor = [UIColor clearColor];
    
    // Init border bottom layer
    self.borderBottomLayer = CAShapeLayer.layer;
    [self.layer addSublayer:self.borderBottomLayer];
    self.borderColor = UIColor.blackColor;
    self.borderWidth = .25;
    
    self.borderBottomLayer.fillColor = nil;
    // Init scrollView
    self.scrollView = [UIScrollView new];
    [self addSubview:self.scrollView];
    
    self.scrollView.delegate = self;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    // Init stain view
    [self.scrollView addSubview:self.selectedStainView = SDStainView.new];
    
    // Init pan gesture
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    self.panGestureRecognizer.maximumNumberOfTouches = 1;
    [self.selectedStainView addGestureRecognizer:self.panGestureRecognizer];
}

- (UIColor *)backgroundColor
{
    return [UIColor colorWithCGColor:((CAShapeLayer *)self.layer).fillColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    ((CAShapeLayer *)self.layer).fillColor = backgroundColor.CGColor;
}

- (UIColor *)shadowColor
{
    return [UIColor colorWithCGColor:self.layer.shadowColor];
}

- (void)setShadowColor:(UIColor *)color
{
    self.layer.shadowColor = color.CGColor;
}

- (CGFloat)shadowRadius
{
    return self.layer.shadowRadius;
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
    self.layer.shadowRadius = shadowRadius;
}

- (CGFloat)shadowOpacity
{
    return self.layer.shadowOpacity;
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{
    self.layer.shadowOpacity = shadowOpacity;
}

- (CGSize)shadowOffset
{
    return self.layer.shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
    self.layer.shadowOffset = shadowOffset;
}

- (CGFloat)borderWidth
{
    return _borderBottomLayer.lineWidth;
}

- (void)setBorderWidth:(CGFloat)borderWidth
{
    _borderBottomLayer.lineWidth = borderWidth;
}

- (UIColor *)borderColor
{
    return [UIColor colorWithCGColor:self.borderBottomLayer.strokeColor];
}

- (void)setBorderColor:(UIColor *)borderColor
{
    self.borderBottomLayer.strokeColor = borderColor.CGColor;
}

- (void)setTitleFont:(UIFont *)titleFont
{
    _titleFont = titleFont;
    
    for (int i = 0; i < self.items.count; i++)
    {
        SDSegmentView *segmentView = (SDSegmentView *)self.items[i];
        segmentView.titleFont = titleFont;
    }
}

- (void)setSelectedTitleFont:(UIFont *)selectedTitleFont
{
    _selectedTitleFont = selectedTitleFont;
    
    for (int i = 0; i < self.items.count; i++)
    {
        SDSegmentView *segmentView = (SDSegmentView *)self.items[i];
        segmentView.selectedTitleFont = selectedTitleFont;
    }
}


#pragma mark - UIKit API

- (void)insertSegmentWithImage:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated
{
    [self insertSegmentWithTitle:nil image:image atIndex:index animated:animated];
}

- (UIImage *)imageForSegmentAtIndex:(NSUInteger)index
{
    return [[self segmentAtIndex:index] imageForState:UIControlStateNormal];
}

- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)index
{
    SDSegmentView* segmentView = [self segmentAtIndex:index];
    [segmentView setImage:image forState:UIControlStateNormal];
    [segmentView sizeToFit];
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)index
{
    index = MAX(MIN(index, self.numberOfSegments - 1), 0);
    UIButton *segmentView = self.items[index];
    [segmentView setTitle:title forState:UIControlStateNormal];
    [segmentView sizeToFit];
    [self setNeedsLayout];
}

- (NSString *)titleForSegmentAtIndex:(NSUInteger)index
{
    index = MAX(MIN(index, self.numberOfSegments - 1), 0);
    UIButton *segmentView = self.items[index];
    return [segmentView titleForState:UIControlStateNormal];
}

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)index animated:(BOOL)animated
{
    [self insertSegmentWithTitle:title image:nil atIndex:index animated:animated];
}

- (void)removeSegmentAtIndex:(NSUInteger)index animated:(BOOL)animated
{
    if (self.items.count == 0) return;
    index = MAX(MIN(index, self.numberOfSegments - 1), 0);
    UIView *segmentView = self.items[index];
    [self.items removeObject:segmentView];
    if (self.selectedSegmentIndex >= 0)
    {
        BOOL changed = NO;
        
        if (self.items.count == 1)
        {
            // Deselect if there is no item
            self.selectedSegmentIndex = UISegmentedControlNoSegment;
            changed = YES;
        }
        else if (self.selectedSegmentIndex == index)
        {
            // Inform that the old value doesn't exist anymore
            changed = YES;
            self.selectedSegmentIndex = [self firstEnabledSegmentIndexNearIndex:self.selectedSegmentIndex];
        }
        else if (self.selectedSegmentIndex > index)
        {
            self.selectedSegmentIndex = [self firstEnabledSegmentIndexNearIndex:self.selectedSegmentIndex - 1];
        }

        // It is important to set both, this will fix the animation.

        self.lastSelectedSegmentIndex = self.selectedSegmentIndex;
        if (changed)
        {
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }

    if (animated)
    {
        [UIView animateWithDuration:kSDSegmentedControlInsertionRemovingDuration animations:^
        {
            segmentView.alpha = 0;
            [self layoutSegments];
        }
        completion:^(BOOL finished)
        {
            [segmentView removeFromSuperview];
        }];
    }
    else
    {
        [segmentView removeFromSuperview];
        [self setNeedsLayout];
    }
}

- (void)removeAllSegments
{
    [self.items makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.items removeAllObjects];
    self.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self setNeedsLayout];
}

- (NSUInteger)numberOfSegments
{
    return self.items.count;
}

- (void)setEnabled:(BOOL)enabled forSegmentAtIndex:(NSUInteger)index
{
    [self segmentAtIndex:index].enabled = enabled;

    if (index == self.selectedSegmentIndex)
    {
        self.selectedSegmentIndex = [self firstEnabledSegmentIndexNearIndex:index];
    }
}

- (BOOL)isEnabledForSegmentAtIndex:(NSUInteger)index
{
    return  [self segmentAtIndex:index].enabled;
}

- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex
{
    if (_selectedSegmentIndex != selectedSegmentIndex)
    {
        if (selectedSegmentIndex >= (NSInteger)self.items.count)
        {
            selectedSegmentIndex = self.items.count - 1;
        }
        self.lastSelectedSegmentIndex = _selectedSegmentIndex;
        _selectedSegmentIndex = selectedSegmentIndex;
        [self setNeedsLayout];
    }
}

- (NSInteger)selectedSegmentIndex
{
    return _selectedSegmentIndex;
}

- (void)setWidth:(CGFloat)width forSegmentAtIndex:(NSUInteger)index
{
    SDSegmentView *segmentView = [self segmentAtIndex:index];
    CGRect frame = segmentView.frame;
    frame.size.width = width;
    segmentView.frame = frame;
    [self setNeedsLayout];
}

- (CGFloat)widthForSegmentAtIndex:(NSUInteger)index
{
    return CGRectGetWidth([self segmentAtIndex:index].frame);
}

#pragma mark - Public

- (void)insertIsNewAtSegmentIndex:(NSInteger)index
{
    SDSegmentView *segmentView = self.items[index];
    segmentView.isNew = YES;
}

- (void)removeIsNewAtSegmentIndex:(NSInteger)index
{
    SDSegmentView *segmentView = self.items[index];
    segmentView.isNew = NO;
}

# pragma mark - Private

- (void)insertSegmentWithTitle:(NSString *)title image:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated
{
    SDSegmentView *segmentView = SDSegmentView.new;
    [segmentView addTarget:self action:@selector(handleSelect:) forControlEvents:UIControlEventTouchUpInside];
    segmentView.alpha = 0;
    [segmentView setTitle:title forState:UIControlStateNormal];
    [segmentView setImage:image forState:UIControlStateNormal];
    [segmentView setTitleFont:self.titleFont];
    [segmentView setSelectedTitleFont:self.selectedTitleFont];
    [segmentView sizeToFit];

    index = MAX(MIN(index, self.numberOfSegments), 0);
    if (index < self.items.count)
    {
        segmentView.center = ((UIView *)self.items[index]).center;
        [self.scrollView insertSubview:segmentView belowSubview:self.items[index]];
        [self.items insertObject:segmentView atIndex:index];
    }
    else
    {
        segmentView.center = self.center;
        [self.scrollView addSubview:segmentView];
        [self.items addObject:segmentView];
    }

    if (self.selectedSegmentIndex >= index && self.selectedSegmentIndex + 1 < self.items.count)
    {
        self.selectedSegmentIndex++;
    }

    self.lastSelectedSegmentIndex = self.selectedSegmentIndex;
    if (animated)
    {
        [UIView animateWithDuration:kSDSegmentedControlInsertionRemovingDuration animations:^
         {
             [self layoutSegments];
         }];
    }
    else
    {
        [self setNeedsLayout];
    }
}

- (NSInteger)firstEnabledSegmentIndexNearIndex:(NSUInteger)index
{
    // Select the first enabled segment
    for (int i = index; i < self.items.count; i++)
    {
        if (((SDSegmentView *)self.items[i]).enabled)
        {
            return i;
        }
    }

    for (int i = index; i >= 0; i--)
    {
        if (((SDSegmentView *)self.items[i]).enabled)
        {
            return i;
        }
    }

    return UISegmentedControlNoSegment;
}

- (SDSegmentView *)segmentAtIndex:(NSUInteger)index
{
    NSParameterAssert(index >= 0 && index < self.items.count);
    return self.items[index];
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    CGRect frame = self.frame;
    if (frame.size.height == 0)
    {
        frame.size.height = 43;
    }
    if (frame.size.width == 0)
    {
        frame.size.width = CGRectGetWidth(newSuperview.bounds);
    }
}

// Layout Needed when switching from and to the View embedding an SDSegmentedControl using a Tab Bar
- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    [self setNeedsLayout];
}

- (void)setArrowSize:(CGFloat)arrowSize
{
    _arrowSize = arrowSize;
    [self setNeedsLayout];
}

-(void)setArrowPosition:(SDSegmentedArrowPosition)arrowPosition
{
    _arrowPosition = arrowPosition;
    [self setNeedsLayout];
}

- (void)setArrowHeightFactor:(CGFloat)arrowHeightFactor
{
    _arrowHeightFactor = arrowHeightFactor;
    [self setNeedsLayout];
}


- (void)layoutSubviews
{
    self.scrollView.frame = self.bounds;
    [self layoutSegments];
}

- (void)layoutSegments
{
    CGFloat totalItemWidth = 0;
    for (SDSegmentView *item in self.items)
    {
        totalItemWidth += CGRectGetWidth(item.bounds);
    }

    CGFloat totalWidth = (totalItemWidth + (self.interItemSpace * (self.numberOfSegments - 1)));

    // Apply total to scrollView
    __block CGFloat currentItemPosition = 0;
    CGSize contentSize = self.scrollView.contentSize;
    if (totalWidth > self.bounds.size.width)
    {
        // We must scroll, so add an offset
        totalWidth += 2 * kSDSegmentedControlScrollOffset;
        currentItemPosition += kSDSegmentedControlScrollOffset;
        contentSize.width = totalWidth;
    }
    else
    {
        contentSize.width = CGRectGetWidth(self.bounds);
    }
    contentSize.height = self.bounds.size.height;
    self.scrollView.contentSize = contentSize;

    // Center all items horizontally and each item vertically
    CGFloat spaceLeft = self.scrollView.contentSize.width - totalWidth;
    CGFloat itemHeight = self.scrollView.contentSize.height - self.arrowSize / 2 + .5;

    currentItemPosition += spaceLeft / 2;
    [self.items enumerateObjectsUsingBlock:^(SDSegmentView *item, NSUInteger idx, BOOL *stop)
     {
         item.alpha = 1;
         
         if (self.centerSegmentsIfPossible) {
             // Space items so that they would remain centered if there is enough space to display them without scrolling.
             CGFloat sectionWidth = totalWidth / self.items.count;
             item.frame = CGRectIntegral(CGRectMake(0, 0, CGRectGetWidth(item.bounds), itemHeight));
             item.center = CGPointMake(currentItemPosition + sectionWidth / 2, item.center.y);
             currentItemPosition += sectionWidth;
         }
         else {
             item.frame = CGRectIntegral(CGRectMake(currentItemPosition, 0, CGRectGetWidth(item.bounds), itemHeight));
             currentItemPosition = CGRectGetMaxX(item.frame) + self.interItemSpace;
         }
     }];
    
    // Layout stain view and update items
    BOOL animated = self.animationDuration && !CGRectEqualToRect(self.selectedStainView.frame, CGRectZero);
    BOOL isScrollingSinceNow = NO;
    CGFloat selectedItemCenterPosition;

    if (self.selectedSegmentIndex == UISegmentedControlNoSegment)
    {
        self.selectedStainView.hidden = YES;
        selectedItemCenterPosition = CGFLOAT_MAX;
        for (SDSegmentView *item in self.items)
        {
            item.selected = NO;
        }
    }
    else
    {
        SDSegmentView *selectedItem = self.items[self.selectedSegmentIndex];
        selectedItemCenterPosition = selectedItem.center.x;

        CGRect stainFrame = UIEdgeInsetsInsetRect(selectedItem.innerFrame, self.stainEdgeInsets);
        CGFloat cornerRadius = 0;
        if ([self.selectedStainView isKindOfClass:[SDStainView class]])
        {
            cornerRadius = [(SDStainView *)self.selectedStainView cornerRadius];
        }
        self.selectedStainView.layer.cornerRadius = cornerRadius ? cornerRadius : (CGRectGetHeight(stainFrame) / 2);
        self.selectedStainView.hidden = NO;
        stainFrame.origin.x = roundf(selectedItemCenterPosition - CGRectGetWidth(stainFrame) / 2);
        selectedItemCenterPosition -= self.scrollView.contentOffset.x;

        if (self.scrollView.contentSize.width > self.scrollView.bounds.size.width)
        {
            CGRect scrollRect = {self.scrollView.contentOffset, self.scrollView.bounds.size};
            CGRect targetRect = CGRectInset(stainFrame, -kSDSegmentedControlScrollOffset / 2, 0);

            if (!CGRectContainsRect(scrollRect, targetRect))
            {
                // Adjust position
                CGFloat posOffset = 0;
                if (CGRectGetMinX(targetRect) < CGRectGetMinX(scrollRect))
                {
                    posOffset += CGRectGetMinX(scrollRect) - CGRectGetMinX(targetRect);
                }
                else if (CGRectGetMaxX(targetRect) > CGRectGetMaxX(scrollRect))
                {
                    posOffset -= CGRectGetMaxX(targetRect) - CGRectGetMaxX(scrollRect);
                }

                // Recenter arrow with posOffset
                selectedItemCenterPosition += posOffset;

                // Temporary disable updates, if scrolling is needed, because scrollView will cause a
                // lot of relayouts. The field isScrollBySelection will be reseted by scrollView's delegate
                // call to scrollViewDidEndScrollingAnimation and can't be resetted after called, because
                // the animation is dispatched asynchronously, naturally.
                self.isScrollingBySelection = animated;
                isScrollingSinceNow = YES;
                [self.scrollView scrollRectToVisible:targetRect animated:animated];
            }
        }

        UIView.animationsEnabled = animated;
        for (SDSegmentView *item in self.items)
        {
            if (item == selectedItem)
            {
                [UIView transitionWithView:item duration:self.animationDuration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    item.selected = YES;
                } completion:nil];
            }
            else if (item.selected)
            {
                [UIView transitionWithView:item duration:self.animationDuration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    item.selected = NO;
                } completion:nil];
            }
        }
        [UIView animateWithDuration:animated ? self.animationDuration : 0 animations:^
         {
             self.selectedStainView.frame = stainFrame;
         }
                         completion:^(BOOL finished)
         {
             for (SDSegmentView *item in self.items)
             {
                 item.selected = item == selectedItem;
             }
         }];
        UIView.animationsEnabled = YES;
    }

    // Don't relayout paths while scrolling
    if (!self.isScrollingBySelection || isScrollingSinceNow)
    {
        // Animate from a custom oldPosition if needed
        CGFloat oldPosition = CGFLOAT_MAX;
        if (animated && self.lastSelectedSegmentIndex != self.selectedSegmentIndex && self.lastSelectedSegmentIndex >= 0 && self.lastSelectedSegmentIndex < self.items.count)
        {
            SDSegmentView *lastSegmentView = [self.items objectAtIndex:self.lastSelectedSegmentIndex];
            oldPosition = lastSegmentView.center.x - self.scrollView.contentOffset.x;
        }

        [self drawPathsFromPosition:oldPosition toPosition:selectedItemCenterPosition animationDuration:animated ? self.animationDuration : 0];
    }
}

- (NSInteger)indexOfNearestButtonToPoint:(CGPoint)point
{
    __block struct SDSegmentedStainViewDistanceStruct smallestDistance;
    smallestDistance.index = -1;
    smallestDistance.distance = -1;
    [self.items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        SDStainView *item = (SDStainView *)obj;
        if (smallestDistance.index >= 0)
        {
            CGFloat distance = [self distanceBetweenPoint:point andPoint:item.center];
            if (distance < smallestDistance.distance)
            {
                smallestDistance.index = idx;
                smallestDistance.distance = distance;
            }
        }
        else
        {
            CGFloat distance = [self distanceBetweenPoint:point andPoint:item.center];
            smallestDistance.index = idx;
            smallestDistance.distance = distance;
        }
    }];
    return smallestDistance.index;
}
                
- (CGFloat)distanceBetweenPoint:(CGPoint)firstPoint andPoint:(CGPoint)secondPoint
{
    return hypotf(firstPoint.x - secondPoint.x, firstPoint.y - secondPoint.y);
}

#pragma mark - Draw paths
// Actually paths are not drawn here, instead they are relayouted

- (void)drawPathsToPosition:(CGFloat)position animated:(BOOL)animated
{
    [self drawPathsToPosition:position animationDuration:animated ? self.animationDuration : 0 completion:nil];
}

- (void)drawPathsToPosition:(CGFloat)position animationDuration:(CFTimeInterval)duration completion:(void (^)(void))completion
{
    [self drawPathsFromPosition:CGFLOAT_MAX toPosition:position animationDuration:duration completion:completion];
}

- (void)drawPathsFromPosition:(CGFloat)oldPosition toPosition:(CGFloat)position animationDuration:(CFTimeInterval)duration
{
    [self drawPathsFromPosition:oldPosition toPosition:position animationDuration:duration completion:nil];
}

- (void)drawPathsFromPosition:(CGFloat)oldPosition toPosition:(CGFloat)position animationDuration:(CFTimeInterval)duration completion:(void (^)(void))completion
{
    CGRect bounds = self.bounds;
    CGFloat left = CGRectGetMinX(bounds);
    CGFloat right = CGRectGetMaxX(bounds);
    CGFloat top = CGRectGetMinY(bounds);
    CGFloat bottom = CGRectGetMaxY(bounds);

    //
    // Mask
    //
    __block UIBezierPath *path = UIBezierPath.new;
    [path moveToPoint:bounds.origin];
    if(_arrowPosition == SDSegmentedArrowPositionBottom)
    {
        [self addArrowAtPoint:CGPointMake(position, bottom) toPath:path withLineWidth:0.0];
        [path addLineToPoint:CGPointMake(right, top)];
        [path addLineToPoint:CGPointMake(left, top)];
    }
    else
    {
        [self addArrowAtPoint:CGPointMake(position, top) toPath:path withLineWidth:0.0];
        [path addLineToPoint:CGPointMake(right, bottom)];
        [path addLineToPoint:CGPointMake(left, bottom)];
    }

    //
    // Shadow mask
    //
    top += 10;
    __block UIBezierPath *shadowPath = UIBezierPath.new;
    [shadowPath moveToPoint:CGPointMake(left, top)];
    if(_arrowPosition == SDSegmentedArrowPositionBottom)
    {
        [self addArrowAtPoint:CGPointMake(position, bottom) toPath:shadowPath withLineWidth:0.0];
        [shadowPath addLineToPoint:CGPointMake(right, top)];
        [shadowPath addLineToPoint:CGPointMake(left, top)];
    }else
    {
        [self addArrowAtPoint:CGPointMake(position, top) toPath:shadowPath withLineWidth:0.0];
        [shadowPath addLineToPoint:CGPointMake(right, bottom)];
        [shadowPath addLineToPoint:CGPointMake(left, bottom)];
    }

    //
    // Bottom/Top border line
    //
    self.borderBottomLayer.frame = self.bounds;
    __block UIBezierPath *borderBottomPath = UIBezierPath.new;
    CGFloat lineLocation;
    if(_arrowPosition == SDSegmentedArrowPositionBottom)
        lineLocation = bottom - self.borderBottomLayer.lineWidth;
    else
        lineLocation = self.borderBottomLayer.lineWidth;
    const CGFloat lineY = lineLocation;


    [self addArrowAtPoint:CGPointMake(position, lineY) toPath:borderBottomPath withLineWidth:self.borderBottomLayer.lineWidth];
    // Skip current animations and ensure the completion block was applied
    // otherwise this will end up in ugly effects if the selection was changed very fast
    [self.layer removeAllAnimations];
    [self.borderBottomLayer removeAllAnimations];
    if (self.lastCompletionBlock)
    {
        self.lastCompletionBlock();
    }

    // Build block
    void(^assignLayerPaths)() = ^
    {
        ((CAShapeLayer *)self.layer).path = path.CGPath;
        self.layer.shadowPath = shadowPath.CGPath;

        self.borderBottomLayer.path = borderBottomPath.CGPath;
        // Dereference itself to be not executed twice
        self.lastCompletionBlock = nil;
    };

    __block void(^animationCompletion)();
    if (completion)
    {
        animationCompletion = ^
        {
            assignLayerPaths();
            completion();
        };
    }
    else
    {
        animationCompletion = assignLayerPaths;
    }

    // Apply new paths
    if (duration > 0)
    {
        // That's a bit fragile: we detect stop animation call by duration!
        NSString *timingFuncName = duration < self.animationDuration ? kCAMediaTimingFunctionEaseIn : kCAMediaTimingFunctionEaseInEaseOut;

        // Check if we have to do a stop animation, which means that we first
        // animate to have a fully visible arrow and then move the arrow.
        // Otherwise there will be ugly effects.
        CFTimeInterval stopDuration = -1;
        CGFloat stopPosition = -1;
        if (oldPosition < CGFLOAT_MAX)
        {
            if (oldPosition < left+self.arrowSize)
            {
                stopPosition = left+self.arrowSize;
            }
            else if (oldPosition > right-self.arrowSize)
            {
                stopPosition = right-self.arrowSize;
            }

            if (stopPosition > 0)
            {
                float relStopDuration = ABS((stopPosition - oldPosition) / (position - oldPosition));
                if (relStopDuration > 1)
                {
                    relStopDuration = 1.0 / relStopDuration;
                }
                stopDuration = duration * relStopDuration;
                duration -= stopDuration;
                timingFuncName  = kCAMediaTimingFunctionEaseOut;
            }
        }

        void (^animation)() = ^
        {
            [CATransaction begin];
            [CATransaction setAnimationDuration:duration];
            CAMediaTimingFunction *timing = [CAMediaTimingFunction functionWithName:timingFuncName];
            [CATransaction setAnimationTimingFunction:timing];
            [CATransaction setCompletionBlock:animationCompletion];

            [self addAnimationWithDuration:duration onLayer:self.layer forKey:@"path" toPath:path];
            [self addAnimationWithDuration:duration onLayer:self.layer forKey:@"shadow" toPath:shadowPath];

            [self addAnimationWithDuration:duration onLayer:self.borderBottomLayer forKey:@"path" toPath:borderBottomPath];
            [CATransaction commit];
        };

        if (stopPosition > 0)
        {
            [self drawPathsToPosition:stopPosition animationDuration:stopDuration completion:animation];
        }
        else
        {
            animation();
        }

        // Remember completion block
        self.lastCompletionBlock = assignLayerPaths;
    }
    else
    {
        assignLayerPaths();
    }

}

- (void)addAnimationWithDuration:(CFTimeInterval)duration onLayer:(CALayer *)layer forKey:(NSString *)key toPath:(UIBezierPath *)path
{
    NSString *camelCaseKeyPath;
    NSString *keyPath;

    if ([key isEqual:@"path"])
    {
        camelCaseKeyPath = key;
        keyPath = key;
    }
    else
    {
        camelCaseKeyPath = [NSString stringWithFormat:@"%@Path", key];
        keyPath = [NSString stringWithFormat:@"%@.path", key];
    }

    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:camelCaseKeyPath];
    pathAnimation.removedOnCompletion = NO;
    pathAnimation.fillMode = kCAFillModeForwards;
    pathAnimation.duration = duration;
    pathAnimation.fromValue = [layer valueForKey:keyPath];
    pathAnimation.toValue = (id)path.CGPath;
    [layer addAnimation:pathAnimation forKey:key];
}

- (void)addArrowAtPoint:(CGPoint)point toPath:(UIBezierPath *)path withLineWidth:(CGFloat)lineWidth
{
    // The arrow is added like below, whereas P is the point argument
    // and 1-5 are the points which were added to the path. It must be
    // always five points, otherwise animations will look ugly.
    //
    // P: point.x
    // s: self.arrowSize - line.width
    // w: self.bounds.size.width
    //
    //
    //   s < P < w-s:      P < -s:         P = MAX:       w+s < P:
    //
    //        3
    //       / \
    //      /   \
    //  1--2  P  4--5   1234--------5   1--2--3--4--5   1--------2345
    //
    //
    //    0 < P < s:       -s < P:
    //
    //     3
    //    / \           123
    //  12   \             \
    //     P  4-----5    P  4------5
    //

    const CGFloat left = CGRectGetMinX(self.bounds);
    const CGFloat right = CGRectGetMaxX(self.bounds);
    const CGFloat center = (right-left) / 2;
    const CGFloat width = self.arrowSize - lineWidth;
    const CGFloat height = self.arrowSize + lineWidth/2;
    const CGFloat ratio = self.arrowHeightFactor;

    __block NSMutableArray *points = NSMutableArray.new;
    BOOL hasCustomLastPoint = NO;

    void (^addPoint)(CGFloat x, CGFloat y) = ^(CGFloat x, CGFloat y)
    {
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    };

    // Add first point
    addPoint(left, point.y);

    if (_arrowSize <= 0.02)
    {
        addPoint(point.x - lineWidth, point.y);
        addPoint(point.x,             point.y);
        addPoint(point.x + lineWidth, point.y);
    }
    else if (point.x >= left+width && point.x <= right-width)
    {
        // Arrow is completely inside the view
        addPoint(point.x - width, point.y);
        addPoint(point.x,         point.y + ratio * height);
        addPoint(point.x + width, point.y);
    }
    else
    {
        // Just some tricks, to allow correctly cutted arrows and
        // to have always a proper animation.
        if (point.x <= left-width)
        {
            // Left aligned points
            addPoint(left + 0.01, point.y);
            addPoint(left + 0.02, point.y);
            addPoint(left + 0.03, point.y);
        }
        else if (point.x < left+width && point.x > left-width)
        {
            // Left cutted arrow
            [points removeAllObjects]; // Custom first point
            if (point.x < left)
            {
                CGFloat x = width + point.x;
                addPoint(left,        point.y + ratio * x);
                addPoint(left + 0.01, point.y + ratio * (x + 0.01));
                addPoint(left + 0.02, point.y + ratio * (x + 0.02));
                addPoint(left + x,    point.y);
            }
            else
            {
                CGFloat x = width - point.x;
                addPoint(left,            point.y + ratio * x);
                addPoint(left + 0.01,     point.y + ratio * (x + 0.01));
                addPoint(point.x,         point.y + ratio * height);
                addPoint(point.x + width, point.y);
            }
        }
        else if (point.x == CGFLOAT_MAX)
        {
            // Centered "arrow", with zero height
            addPoint(center - width, point.y);
            addPoint(center,         point.y);
            addPoint(center + width, point.y);
        }
        else if (point.x < right+width && point.x > right-width)
        {
            // Right cutted arrow, is like left cutted arrow but:
            //  * swapped if/else case
            //  * inverse point order
            //  * other calculation of x
            hasCustomLastPoint = YES; // Custom last point
            if (point.x < right)
            {
                CGFloat x = width - (right - point.x);
                addPoint(point.x - width, point.y);
                addPoint(point.x,         point.y + ratio * height);
                addPoint(right - 0.01,    point.y + ratio * (x + 0.01));
                addPoint(right,           point.y + ratio * x);
            }
            else
            {
                CGFloat x = width + (right - point.x);
                addPoint(right - x,    point.y);
                addPoint(right - 0.02, point.y + ratio * (x + 0.02));
                addPoint(right - 0.01, point.y + ratio * (x + 0.01));
                addPoint(right,        point.y + ratio * x);
            }
        }
        else
        {
            // Right aligned points
            addPoint(right - 0.03, point.y);
            addPoint(right - 0.02, point.y);
            addPoint(right - 0.01, point.y);
        }
    }

    // Add points from array to path
    CGPoint node = ((NSValue *)[points objectAtIndex:0]).CGPointValue;
    if (path.isEmpty)
    {
        [path moveToPoint:node];
    }
    else
    {
        [path addLineToPoint:node];
    }
    for (int i=1; i<points.count; i++)
    {
        node = ((NSValue *)[points objectAtIndex:i]).CGPointValue;
        [path addLineToPoint:node];
    }

    // Add last point of not replaced
    if (!hasCustomLastPoint)
    {
        [path addLineToPoint:CGPointMake(right, point.y)];
    }
}

- (void)handleSelect:(SDSegmentView *)view
{
    NSUInteger index = [self.items indexOfObject:view];
    if (index != NSNotFound && index != self.selectedSegmentIndex)
    {
        self.selectedSegmentIndex = index;
        [self setNeedsLayout];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

#pragma mark - ScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.isScrollingBySelection || _selectedSegmentIndex == UISegmentedControlNoSegment) return;
    CGFloat selectedItemCenterPosition = ((SDSegmentView *)self.items[self.selectedSegmentIndex]).center.x;
    [self drawPathsToPosition:selectedItemCenterPosition - scrollView.contentOffset.x animated:NO];
    if (self.panGestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        if (!CGPointEqualToPoint(self.previousScrollViewOffset, CGPointZero))
        {
            self.selectedStainView.center = CGPointMake(self.selectedStainView.center.x - (self.previousScrollViewOffset.x - self.scrollView.contentOffset.x), self.selectedStainView.center.y);
        }
        self.previousScrollViewOffset = scrollView.contentOffset;
    }
    else
    {
        self.selectedStainView.center = CGPointMake(selectedItemCenterPosition, self.selectedStainView.center.y);
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    self.isScrollingBySelection = NO;
}

#pragma mark - GenstureRecognizers

- (void)panGestureRecognized:(UIPanGestureRecognizer *)panGestureRecognizer
{
    if (panGestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        CGPoint translation = [panGestureRecognizer translationInView:panGestureRecognizer.view.superview];
        
        // Find the difference in horizontal position between the current and previous touches
        CGFloat xDiff = translation.x;
        
        // Check that the indicator doesn't exit the bounds of the control
        CGRect newSegmentIndicatorFrame = self.selectedStainView.frame;
        newSegmentIndicatorFrame.origin.x += xDiff;
        
        CGFloat selectedSegmentIndicatorCenterX;
        
        CGRect scrollBounds = self.bounds;
        scrollBounds.size.width = self.scrollView.contentSize.width;
        
        if (CGRectContainsRect(CGRectInset(scrollBounds, 0, 0), newSegmentIndicatorFrame))
        {
            selectedSegmentIndicatorCenterX = self.selectedStainView.center.x + xDiff;
        }
        else
        {
            if (self.selectedStainView.center.x < CGRectGetMidX(scrollBounds))
            {
                selectedSegmentIndicatorCenterX = CGRectGetMidX(self.selectedStainView.bounds);
            }
            else
            {
                selectedSegmentIndicatorCenterX = CGRectGetMaxX(scrollBounds) - CGRectGetMidX(self.selectedStainView.bounds);
            }
        }
        
        self.selectedStainView.center = CGPointMake(selectedSegmentIndicatorCenterX, self.selectedStainView.center.y);
        
        [panGestureRecognizer setTranslation:CGPointMake(0, 0) inView:panGestureRecognizer.view.superview];
        [self.scrollView autoScrollDragMoved:[panGestureRecognizer locationInView:panGestureRecognizer.view.superview]];
    }
    
    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        for (SDSegmentView *item in self.items)
        {
            if (item.selected)
            {
                [UIView transitionWithView:item duration:self.animationDuration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    item.selected = NO;
                    self.selectedStainView.alpha = 0.5;
                } completion:nil];
            }
        }
        [self.scrollView autoScrollDragStarted];
    }
    
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded || panGestureRecognizer.state == UIGestureRecognizerStateFailed || panGestureRecognizer.state == UIGestureRecognizerStateCancelled)
    {
        self.selectedStainView.alpha = 1;
        [self.scrollView autoScrollDragEnded];
        [self setSelectedSegmentIndex:[self indexOfNearestButtonToPoint:self.selectedStainView.center]];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        [self setNeedsLayout];
        self.previousScrollViewOffset = CGPointZero;
    }
}

@end

@interface SDSegmentView ()

@property (nonatomic, strong) UIColor *titleColorNormal;
@property (nonatomic, strong) UIColor *titleColorSelected;
@property (nonatomic, strong) UIColor *titleColorDisabled;
@property (nonatomic, strong) UIView *isNewCircleView;

@end

@implementation SDSegmentView

+ (void)initialize
{
    [super initialize];

    SDSegmentView *appearance = [self appearance];
    [appearance setTitleColor:[UIColor colorWithWhite:0.392 alpha:1] forState:UIControlStateNormal];
    [appearance setTitleColor:[UIColor colorWithWhite:0.235 alpha:1] forState:UIControlStateSelected];
    [appearance setTitleColor:[UIColor colorWithWhite:0.800 alpha:1] forState:UIControlStateDisabled];
    [appearance setIsNewCircleColor:[UIColor orangeColor]];
}

+ (instancetype)new
{
    return [self.class buttonWithType:UIButtonTypeCustom];
}

+ (instancetype)appearance
{
    return [self appearanceWhenContainedIn:SDSegmentedControl.class, nil];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _imageSize = kSDSegmentedControlImageSize;
        self.titleFont = [UIFont systemFontOfSize:14];
        self.selectedTitleFont = [UIFont boldSystemFontOfSize:14];
        
        self.userInteractionEnabled = YES;
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.titleEdgeInsets = UIEdgeInsetsMake(0, 0.0, 0, -8.0); // Space between text and image
        self.imageEdgeInsets = UIEdgeInsetsMake(0, 0.0, 0, 0.0); // Space between image and stain
        self.contentEdgeInsets = UIEdgeInsetsMake(0, 0.0, 0, 8.0); // Enlarge touchable area

#ifdef SDSegmentedControlDebug
        self.backgroundColor = [UIColor colorWithHue:1.00 saturation:1.0 brightness:1.0 alpha:0.5];
        self.imageView.backgroundColor = [UIColor colorWithHue:0.66 saturation:1.0 brightness:1.0 alpha:0.5];
        self.titleLabel.backgroundColor = [UIColor colorWithHue:0.33 saturation:1.0 brightness:1.0 alpha:0.5];
#endif
    }
    return self;
}

- (void)setTitleFont:(UIFont *)titleFont
{
    _titleFont = titleFont;
    if (self.state != UIControlStateSelected)
    {
        self.titleLabel.font = titleFont;
        [self sizeToFit];
    }
}

- (void)setSelectedTitleFont:(UIFont *)selectedTitleFont
{
    _selectedTitleFont = selectedTitleFont;
    if (self.state == UIControlStateSelected)
    {
        self.titleLabel.font = selectedTitleFont;
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (selected)
    {
        if (self.isNew)
        {
            self.isNewCircleView.hidden = YES;
        }
        self.userInteractionEnabled = NO;
        self.titleLabel.font = self.selectedTitleFont ?: self.titleFont;
    }
    else
    {
        if (self.isNew)
        {
            self.isNewCircleView.hidden = NO;
        }
        self.userInteractionEnabled = YES;
        self.titleLabel.font = self.titleFont;
    }
}

- (CGSize)titleShadowOffset
{
    return self.titleLabel.shadowOffset;
}

- (void)setTitleShadowOffset:(CGSize)titleShadowOffset
{
    self.titleLabel.shadowOffset = titleShadowOffset;
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state
{
    [super setImage:[self scaledImageWithImage:image] forState:state];
}

- (UIImage *)scaledImageWithImage:(UIImage*)image
{
    if (!image) return nil;

    // Scale down images that are too large 
    if (image.size.width > self.imageSize.width || image.size.height > self.imageSize.height)
    {
        UIImageView *imageView = [UIImageView.alloc initWithFrame:CGRectMake(0, 0, self.imageSize.width, self.imageSize.height)];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.image = image;

        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, NO, 0.0);
        [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

	return image;

}

- (CGRect)innerFrame
{
    const CGPoint origin = self.frame.origin;
    CGRect innerFrame = CGRectOffset(self.titleLabel.frame, origin.x, origin.y);

    if (innerFrame.size.width > 0)
    {
        innerFrame.size.width = self.titleEdgeInsets.left + self.titleLabel.frame.size.width + self.titleEdgeInsets.right;
    }

    if ([self imageForState:self.state])
    {
        const CGRect imageViewFrame = self.imageView.frame;
        if (innerFrame.size.height > 0)
        {
            innerFrame.origin.y -= (imageViewFrame.size.height - innerFrame.size.height) / 2;
        }
        else
        {
            innerFrame.origin.y = imageViewFrame.origin.y;
        }
        innerFrame.size.height = imageViewFrame.size.height;
        innerFrame.size.width += self.imageEdgeInsets.left + imageViewFrame.size.width + self.imageEdgeInsets.right;
    }

    return innerFrame;
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    
    switch (self.tintAdjustmentMode)
    {
        case UIViewTintAdjustmentModeAutomatic:
        case UIViewTintAdjustmentModeNormal:
            
            if (self.titleColorNormal)
            {
                [self setTitleColor:self.titleColorNormal forState:UIControlStateNormal];
                self.titleColorNormal = nil;
            }
            
            if (self.titleColorSelected)
            {
                [self setTitleColor:self.titleColorSelected forState:UIControlStateSelected];
                self.titleColorSelected = nil;
            }
            
            if (self.titleColorDisabled)
            {
                [self setTitleColor:self.titleColorDisabled forState:UIControlStateDisabled];
                self.titleColorDisabled = nil;
            }
            
            break;
        case UIViewTintAdjustmentModeDimmed:
            
            self.titleColorNormal = [self titleColorForState:UIControlStateNormal];
            self.titleColorSelected = [self titleColorForState:UIControlStateSelected];
            self.titleColorDisabled = [self titleColorForState:UIControlStateDisabled];
            
            [self setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
            [self setTitleColor:[UIColor grayColor] forState:UIControlStateSelected];
            [self setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
            
            break;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    return;
}

- (void)setIsNewCircleColor:(UIColor *)isNewCircleColor
{
    _isNewCircleColor = isNewCircleColor;
    if (isNewCircleColor != nil)
    {
        self.isNewCircleView.backgroundColor = isNewCircleColor;
    }
}

- (void)setIsNew:(BOOL)isNew
{
    _isNew = isNew;
    if (isNew)
    {
        if (self.isNewCircleView == nil)
        {
            self.isNewCircleView = [[UIView alloc] init];
            self.isNewCircleView.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:self.isNewCircleView];
            self.isNewCircleView.backgroundColor = self.isNewCircleColor;
            self.isNewCircleView.layer.cornerRadius = kSDSegmentViewIsNewCircleDiameter / 2;
            [self.isNewCircleView addConstraint:[NSLayoutConstraint constraintWithItem:self.isNewCircleView
                                                                             attribute:NSLayoutAttributeWidth
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:nil
                                                                             attribute:NSLayoutAttributeWidth
                                                                            multiplier:1.f
                                                                              constant:kSDSegmentViewIsNewCircleDiameter]];
            
            [self.isNewCircleView addConstraint:[NSLayoutConstraint constraintWithItem:self.isNewCircleView
                                                                             attribute:NSLayoutAttributeHeight
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:nil attribute:NSLayoutAttributeHeight
                                                                            multiplier:1.f
                                                                              constant:kSDSegmentViewIsNewCircleDiameter]];
            
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.isNewCircleView
                                                             attribute:NSLayoutAttributeTrailing
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeTrailing
                                                            multiplier:1.f
                                                              constant:3]];
            
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.isNewCircleView
                                                             attribute:NSLayoutAttributeTop
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.titleLabel
                                                             attribute:NSLayoutAttributeTop
                                                            multiplier:1.f
                                                              constant:0]];
            
        }
        else
        {
            if (self.selected)
            {
                self.isNewCircleView.hidden = YES;
            }
            else
            {
                self.isNewCircleView.hidden = NO;
            }
        }
    }
    else
    {
        if (self.isNewCircleView != nil)
        {
            self.isNewCircleView.hidden = YES;
        }
    }
}

@end


@implementation SDStainView

+ (void)initialize
{
    [super initialize];
    SDStainView *appearance = [self appearance];
    appearance.edgeInsets = UIEdgeInsetsMake(-.5, -.5, -.5, -.5);
    appearance.backgroundColor = [UIColor clearColor];
}

+ (instancetype)appearance
{
    return [self appearanceWhenContainedIn:SDSegmentedControl.class, nil];
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    _backgroundColor = backgroundColor;
    [self setNeedsDisplay];
}

- (void)setEdgeInsets:(UIEdgeInsets)edgeInsets
{
    _edgeInsets = edgeInsets;
    [self setNeedsDisplay];
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
    [self setNeedsDisplay];
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
    _shadowOffset = shadowOffset;
    [self setNeedsDisplay];
}

- (void)setShadowBlur:(CGFloat)shadowBlur
{
    _shadowBlur = shadowBlur;
    [self setNeedsDisplay];
}

- (void)setShadowColor:(UIColor *)shadowColor
{
    _shadowColor = shadowColor;
    [self setNeedsDisplay];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *shadowColor = self.shadowColor;
    UIColor *innerStrokeColor = self.innerStrokeColor;
    [self.backgroundColor setFill];
    
    if ([self respondsToSelector:@selector(tintAdjustmentMode)]) {
    
        switch (self.tintAdjustmentMode) {
            case UIViewTintAdjustmentModeAutomatic:
            case UIViewTintAdjustmentModeNormal:
                break;
            case UIViewTintAdjustmentModeDimmed:
                
                if (self.backgroundColor && ![self.backgroundColor isEqual:[UIColor clearColor]]) {
                    [[UIColor lightGrayColor] setFill];
                }
        
                if (self.shadowColor && ![self.shadowColor isEqual:[UIColor clearColor]]) {
                    shadowColor = [UIColor lightGrayColor];
                }
                
                if (self.innerStrokeColor && ![self.innerStrokeColor isEqual:[UIColor clearColor]]) {
                    innerStrokeColor = [UIColor lightGrayColor];
                }
                
                break;
        }
    }
    
    CGContextFillRect(context, self.bounds);

    CGPathRef roundedRect = [UIBezierPath bezierPathWithRoundedRect:UIEdgeInsetsInsetRect(rect, self.edgeInsets) cornerRadius:self.layer.cornerRadius].CGPath;
    CGContextAddPath(context, roundedRect);
    CGContextClip(context);

    CGContextAddPath(context, roundedRect);
    CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), self.shadowOffset, self.shadowBlur, shadowColor.CGColor);
    CGContextSetStrokeColorWithColor(context, self.backgroundColor.CGColor);
    CGContextStrokePath(context);

    CGContextTranslateCTM(context, 0, -1);
    CGContextAddPath(context, roundedRect);
    CGContextSetLineWidth(context, self.innerStrokeLineWidth);
    CGContextSetStrokeColorWithColor(context, innerStrokeColor.CGColor);
    CGContextStrokePath(context);
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self setNeedsDisplay];
}

@end
