//
//  HLSCursor.m
//  nut
//
//  Created by Samuel Défago on 09.06.11.
//  Copyright 2011 Hortis. All rights reserved.
//

#import "HLSCursor.h"

#import "HLSFloat.h"
#import "HLSLogger.h"
#import "HLSUserInterfaceLock.h"

static const CGFloat kDefaultSpacing = 20.f;

@interface HLSCursor ()

- (void)initialize;

@property (nonatomic, retain) NSArray *elementViews;

- (CGFloat)xPosForIndex:(NSUInteger)index;
- (NSUInteger)indexForXPos:(CGFloat)xPos;

- (CGRect)pointerFrameForIndex:(NSUInteger)index;
- (CGRect)pointerFrameForXPos:(CGFloat)xPos;

- (void)movePointerToIndex:(NSUInteger)index animated:(BOOL)animated duration:(NSTimeInterval)duration;

- (void)pointerAnimationWillStart:(NSString *)animationID context:(void *)context;
- (void)pointerAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

@end

@implementation HLSCursor

#pragma mark Object creation and destruction

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self initialize];
    }
    return self;
}

- (void)dealloc
{
    self.elementViews = nil;
    self.pointerView = nil;
    self.defaultPointerColor = nil;
    self.highlightImage = nil;
    self.dataSource = nil;
    
    [super dealloc];
}

- (void)initialize
{
    self.spacing = kDefaultSpacing;
    self.pointerViewOffset = CGSizeMake(-kDefaultSpacing / 2.f, -kDefaultSpacing / 2.f);
}

#pragma mark Accessors and mutators

@synthesize elementViews = m_elementViews;

@synthesize spacing = m_spacing;

@synthesize pointerView = m_pointerView;

- (void)setPointerView:(UIView *)pointerView
{
    if (m_pointerView) {
        HLSLoggerError(@"A pointer view has already been defined and cannot be changed");
        return;
    }
    
    [m_pointerView release];
    m_pointerView = [pointerView retain];
}

@synthesize pointerViewOffset = m_pointerViewOffset;

@synthesize defaultPointerColor = m_defaultPointerColor;

@synthesize highlightImage = m_highlightImage;

@synthesize highlightContentStretch = m_highlightContentStretch;

@synthesize dataSource = m_dataSource;

@synthesize delegate = m_delegate;

#pragma mark Layout

- (void)layoutSubviews
{
    HLSLoggerError(@"Called");
    
    // Create subviews views lazily the first time they are needed; not doing this in init allows clients to customize
    // the views before they are displayed
    if (! m_viewsCreated) {
        // Create the subview set
        self.elementViews = [NSArray array];
        
        // Check the data source
        NSUInteger nbrElements = [self.dataSource numberOfElementsForCursor:self];
        if (nbrElements == 0) {
            HLSLoggerError(@"Cursor data source is empty");
            return;
        }
        
        // Fill with views generated from the data source
        if ([self.dataSource respondsToSelector:@selector(cursor:viewAtIndex:selected:)]) {
            for (NSUInteger index = 0; index < nbrElements; ++index) {
                UIView *elementView = [self.dataSource cursor:self viewAtIndex:index selected:NO];
                [self addSubview:elementView];
                self.elementViews = [self.elementViews arrayByAddingObject:elementView];
            }
        }
        else if ([self.dataSource respondsToSelector:@selector(cursor:titleAtIndex:)]) {
            for (NSUInteger index = 0; index < nbrElements; ++index) {
                UIFont *font = nil;
                if ([self.dataSource respondsToSelector:@selector(cursor:fontAtIndex:selected:)]) {
                    font = [self.dataSource cursor:self fontAtIndex:index selected:NO];
                }
                else {
                    font = [UIFont systemFontOfSize:17.f];
                }
                NSString *title = [self.dataSource cursor:self titleAtIndex:index];
                CGSize titleSize = [title sizeWithFont:font];
                
                UILabel *elementLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, titleSize.width, titleSize.height)] autorelease];
                elementLabel.text = title;
                elementLabel.backgroundColor = [UIColor clearColor];
                if ([self.dataSource respondsToSelector:@selector(cursor:textColorAtIndex:selected:)]) {
                    elementLabel.textColor = [self.dataSource cursor:self textColorAtIndex:index selected:NO];
                }
                else {
                    elementLabel.textColor = [self.backgroundColor invertColor];
                }
                if ([self.dataSource respondsToSelector:@selector(cursor:shadowColorAtIndex:selected:)]) {
                    elementLabel.shadowColor = [self.dataSource cursor:self shadowColorAtIndex:index selected:NO];
                }
                if ([self.dataSource respondsToSelector:@selector(cursor:shadowOffsetAtIndex:selected:)]) {
                    elementLabel.shadowOffset = [self.dataSource cursor:self shadowOffsetAtIndex:index selected:NO];
                }
                [self addSubview:elementLabel];
                self.elementViews = [self.elementViews arrayByAddingObject:elementLabel];
            }
        }
        else {
            HLSLoggerError(@"Cursor data source must either implement cursor:viewAtIndex: or cursor:titleAtIndex:");
            return;
        }
    }
        
    // Calculate the needed total width
    CGFloat totalWidth = 0.f;
    for (UIView *elementView in self.elementViews) {
        totalWidth += elementView.frame.size.width + self.spacing;
    }
    totalWidth -= self.spacing;
    
    // Adjust individual frames so that the element views are centered within the available frame; warn if too large (will still
    // be centered)
    CGFloat xPos = floorf(fabs(self.frame.size.width - totalWidth) / 2.f);
    if (floatgt(totalWidth, self.frame.size.width)) {
        HLSLoggerWarn(@"Cursor frame not wide enough");
        xPos = -xPos;
    }
    for (UIView *elementView in self.elementViews) {
        CGFloat yPos = floorf(fabs(self.frame.size.height - elementView.frame.size.height) / 2.f);
        if (floatgt(elementView.frame.size.height, self.frame.size.height)) {
            HLSLoggerWarn(@"Cursor frame not tall enough");
            yPos = -yPos;
        }
        
        elementView.frame = CGRectMake(xPos, yPos, elementView.frame.size.width, elementView.frame.size.height);
        xPos += elementView.frame.size.width + self.spacing;
    }
    
    if (! m_viewsCreated) {
        // If no custom pointer view specified, create a default one
        if (! self.pointerView) {
            // TODO: Better!
            CGRect pointerFrame = [self pointerFrameForIndex:0];
            self.pointerView = [[[UIView alloc] initWithFrame:pointerFrame] autorelease];
            self.pointerView.backgroundColor = [UIColor redColor];
            self.pointerView.alpha = 0.5f;
        }
        [self addSubview:self.pointerView];
    }
    
    m_viewsCreated = YES;
}

#pragma mark Pointer management

- (NSUInteger)selectedIndex
{
    return [self indexForXPos:m_xPos];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex animated:(BOOL)animated
{
    m_xPos = [self xPosForIndex:selectedIndex];
    [self movePointerToIndex:selectedIndex animated:animated duration:0.3f];
}

- (CGFloat)xPosForIndex:(NSUInteger)index
{
    if (index >= [self.elementViews count]) {
        HLSLoggerError(@"Invalid index");
        return 0.f;
    }
    
    UIView *elementView = [self.elementViews objectAtIndex:index];
    return elementView.center.x;
}

- (NSUInteger)indexForXPos:(CGFloat)xPos
{
    NSUInteger index = 0;
    for (UIView *elementView in self.elementViews) {
        if (floatge(xPos, elementView.frame.origin.x - self.spacing / 2.f) 
                && floatle(xPos, elementView.frame.origin.x + elementView.frame.size.width + self.spacing / 2.f)) {
            return index;
        }
        ++index;
    }
    
    // No match found; return leftmost or rightmost element view
    UIView *firstElementView = [self.elementViews firstObject];
    if (floatlt(xPos, firstElementView.frame.origin.x - self.spacing / 2.f)) {
        return 0;
    }
    else {
        return [self.elementViews count] - 1;
    }
}

- (CGRect)pointerFrameForIndex:(NSUInteger)index
{
    CGFloat xPos = [self xPosForIndex:index];
    return [self pointerFrameForXPos:xPos];
}

// xPos is here where the pointer is located, i.e. the center of the pointer rectangle
- (CGRect)pointerFrameForXPos:(CGFloat)xPos
{
    // Find the index of the element view whose x center coordinate is the first >= xPos along the x axis
    NSUInteger index = 0;
    for (UIView *elementView in self.elementViews) {
        if (floatle(xPos, elementView.center.x)) {
            break;
        }
        ++index;
    }
    
    // Too far on the left; cursor around the first view
    CGRect pointerRect;
    if (index == 0) {
        UIView *firstElementView = [self.elementViews firstObject];
        pointerRect = firstElementView.frame;
    }
    // Too far on the right; cursor around the last view
    else if (index == [self.elementViews count]) {
        UIView *lastElementView = [self.elementViews lastObject];
        pointerRect = lastElementView.frame;
    }
    // Cursor in between views with indices index-1 and index. Interpolate
    else {
        UIView *previousElementView = [self.elementViews objectAtIndex:index - 1];
        UIView *nextElementView = [self.elementViews objectAtIndex:index];
        
        // Linear interpolation
        CGFloat width = ((xPos - nextElementView.center.x) * previousElementView.frame.size.width 
                         + (previousElementView.center.x - xPos) * nextElementView.frame.size.width) / (previousElementView.center.x - nextElementView.center.x);
        CGFloat height = ((xPos - nextElementView.center.x) * previousElementView.frame.size.height 
                          + (previousElementView.center.x - xPos) * nextElementView.frame.size.height) / (previousElementView.center.x - nextElementView.center.x);
        
        pointerRect = CGRectMake(xPos - width / 2.f, 
                                 previousElementView.frame.origin.y,      /* all element views are aligned vertically; so is the cursor. Can randomly pick one */
                                 width, 
                                 height);
    }
    
    // Adjust the rect according to the offset to be applied
    pointerRect = CGRectMake(pointerRect.origin.x + self.pointerViewOffset.width,
                             pointerRect.origin.y + self.pointerViewOffset.height,
                             pointerRect.size.width - 2 * self.pointerViewOffset.width,
                             pointerRect.size.height - 2 * self.pointerViewOffset.height);
    
    return pointerRect;
}

- (void)movePointerToIndex:(NSUInteger)index animated:(BOOL)animated duration:(NSTimeInterval)duration
{
    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationWillStartSelector:@selector(pointerAnimationWillStart:context:)];
        [UIView setAnimationDidStopSelector:@selector(pointerAnimationDidStop:finished:context:)];
        [UIView setAnimationDuration:duration];
        [UIView setAnimationDelegate:self];
    }
    
    self.pointerView.frame = [self pointerFrameForIndex:index];
    
    if (animated) {
        [UIView commitAnimations];
    }
}

#pragma mark Touch events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // If clicking on the pointer, do not select it again. This corresponds to the user grabbing the pointer
    CGPoint pos = [[touches anyObject] locationInView:self];
    if (! CGRectContainsPoint(self.pointerView.frame, pos)) {
        m_clicked = YES;
        [self setSelectedIndex:[self indexForXPos:pos.x] animated:YES];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint pos = [[touches anyObject] locationInView:self];
    if (! m_dragging && ! m_clicked) {
        m_dragging = YES;
        
        // Check that we are actually grabbing the pointer view
        if (CGRectContainsPoint(self.pointerView.frame, pos)) {
            m_grabbed = YES;
        }
        else {
            m_grabbed = NO;
        }
    }
    
    if (m_grabbed) {
        self.pointerView.frame = [self pointerFrameForXPos:pos.x];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	m_dragging = NO;
    m_grabbed = NO;
    m_clicked = NO;
    
    CGPoint pos = [[touches anyObject] locationInView:self];
    NSUInteger index = [self indexForXPos:pos.x];
    [self movePointerToIndex:index animated:YES duration:0.2f];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    m_dragging = NO;
    m_grabbed = NO;
    m_clicked = NO;
}

#pragma mark Animation callbacks

- (void)pointerAnimationWillStart:(NSString *)animationID context:(void *)context
{
    [[HLSUserInterfaceLock sharedUserInterfaceLock] lock];
}

- (void)pointerAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
    [[HLSUserInterfaceLock sharedUserInterfaceLock] unlock];
}

@end
