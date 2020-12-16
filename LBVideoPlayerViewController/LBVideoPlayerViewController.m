//
//  LBVideoPlayerViewController.m
//  LBVideoPlayerViewController
//
//  Created by 刘彬 on 2020/9/24.
//  Copyright © 2020 刘彬. All rights reserved.
//

#import "LBVideoPlayerViewController.h"
#import "NSObject+LBMethodSwizzling.h"
#import "NSObject+LBTopViewController.h"
#import "LBVideoPlayerView.h"

typedef enum {
    LBVideoPlayerAnimationTypePresent,
    LBVideoPlayerAnimationTypeDismiss,
} LBVideoPlayerTransitionsAnimationType;
@interface LBVideoPlayerTransitioning : NSObject<UIViewControllerTransitioningDelegate,UIViewControllerAnimatedTransitioning>
@property (nonatomic,assign)LBVideoPlayerTransitionsAnimationType type;
@end

@interface LBVideoPlayerViewController ()
@property (nonatomic,weak)UIView *sourceView;
@property (nonatomic,strong)LBVideoPlayerTransitioning *transitioning;

@property (nonatomic, assign) CGFloat brightness;

@property (nonatomic, strong) LBVideoPlayerView *videoView;
@property (nonatomic, assign) UIInterfaceOrientation currentOrientation;
@property (nonatomic, strong) NSURL *videoUrl;

@property (nonatomic , assign)BOOL panGestureWorking;
@property (nonatomic , assign)BOOL dismissAnimationInProgress;
@property (nonatomic , assign)CGPoint startPoint;
@property (nonatomic , assign)CGPoint startCenter;

@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation LBVideoPlayerViewController
+(void)load{
    [self lb_swizzleMethodClass:NSClassFromString(@"AppDelegate")
                         method:@selector(application:supportedInterfaceOrientationsForWindow:)
          originalIsClassMethod:NO
                      withClass:self.class
                     withMethod:@selector(lb_application:supportedInterfaceOrientationsForWindow:)
          swizzledIsClassMethod:NO];
}

- (UIInterfaceOrientationMask)lb_application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window{
    UIViewController<LBSupportedInterfaceOrientationsDelegate> *topVC = ( UIViewController<LBSupportedInterfaceOrientationsDelegate> *)[NSObject topViewControllerWithRootViewController:window.rootViewController];

    if ([topVC respondsToSelector:@selector(lb_supportedInterfaceOrientations)]) {
        UIInterfaceOrientationMask orientations = [topVC lb_supportedInterfaceOrientations];
        //如果现在视频是横屏，但是由于用户把手机立起来了导致系统设备成竖屏，再强制使系统设备变横屏
        if (orientations == UIInterfaceOrientationMaskLandscapeRight && [UIDevice currentDevice].orientation != UIDeviceOrientationLandscapeRight) {
            [topVC lb_interfaceOrientation:UIInterfaceOrientationLandscapeRight];
        }
        if (orientations == UIInterfaceOrientationMaskPortrait && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
            [topVC lb_interfaceOrientation:UIInterfaceOrientationPortrait];
        }
        return orientations;
    }

    return [[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:window];
}

///强制转换屏幕方向
- (void)lb_interfaceOrientation:(UIInterfaceOrientation)orientation {
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = @selector(setOrientation:);
        NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        UIInterfaceOrientation val = orientation;
        // 从2开始是因为前两个参数已经被selector和target占用
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}
- (UIInterfaceOrientationMask)lb_supportedInterfaceOrientations {
    if (self.currentOrientation == UIInterfaceOrientationLandscapeRight) {

        return UIInterfaceOrientationMaskLandscapeRight;
    }
    return UIInterfaceOrientationMaskPortrait;
}
//必须返回YES
- (BOOL)shouldAutorotate{
    return YES;
}


- (instancetype)init
{
    return [self initWithVideoUrl:nil sourceView:nil];
}

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl sourceView:(UIView *)sourceView
{
    self = [super init];
    if (self) {
        _videoUrl = videoUrl;
        
        self.modalPresentationStyle = UIModalPresentationCustom;
        
        if (sourceView) {
            self.sourceView = sourceView;
            _transitioning = [[LBVideoPlayerTransitioning alloc] init];
            self.transitioningDelegate = _transitioning;
        }

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor];
    
    LBVideoPlayerView *videoView = [[LBVideoPlayerView alloc] initWithFrame:self.view.bounds url:self.videoUrl viewController:self];
    [videoView.backButton addTarget:self action:@selector(backButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [videoView.fullScreenButton addTarget:self action:@selector(fullScreenButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:videoView];
    _videoView = videoView;
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureAction:)];
    [self.view addGestureRecognizer:panGesture];
    _panGesture = panGesture;
    self.videoView.panGesture.enabled = NO;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (self.panGestureWorking == NO && self.dismissAnimationInProgress == NO) {
        _videoView.frame = self.view.bounds;
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.brightness = [UIScreen mainScreen].brightness;
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
    [UIScreen mainScreen].brightness = self.brightness;
}
#pragma mark ButtonAction
-(void)backButtonAction:(UIButton *)sender{
    if (self.currentOrientation == UIInterfaceOrientationLandscapeRight) {
        [self fullScreenButtonAction:self.videoView.fullScreenButton];
    }else{
        if (self.presentingViewController) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }else{
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}
-(void)fullScreenButtonAction:(UIButton *)sender{
    sender.selected = !sender.selected;
    if (sender.selected) {
        self.currentOrientation = UIInterfaceOrientationLandscapeRight;
        [self.panGesture requireGestureRecognizerToFail:self.videoView.panGesture];
        self.videoView.panGesture.enabled = YES;
        self.panGesture.enabled = NO;
    }
    else {
        self.currentOrientation = UIInterfaceOrientationPortrait;
        self.videoView.panGesture.enabled = NO;
        self.panGesture.enabled = YES;
    }
    [self lb_interfaceOrientation:self.currentOrientation];
}
#pragma mark - 手势处理

- (void)panGestureAction:(UIPanGestureRecognizer *)pan {
    AVPlayerLayer *layer = (AVPlayerLayer *)self.videoView.layer;
    
    CGPoint location = [pan locationInView:self.view];
    CGPoint point = [pan translationInView:self.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
        {
            _panGestureWorking = YES;
            _startPoint = location;
            _startCenter = self.videoView.center;
            
            if (CGRectIsEmpty(layer.videoRect) == NO) {
                self.videoView.frame = layer.videoRect;
            }
            [self.videoView hiddenToolBars:YES animation:NO];
        }
            break;
        case UIGestureRecognizerStateChanged:
        {
            if (location.y - _startPoint.y < 0) {
                return;
            }
            double percent = 1 - fabs(point.y) / CGRectGetHeight(self.view.frame);// 移动距离 / 整个屏幕
            double scalePercent = MAX(percent, 0.3);
            if (location.y - _startPoint.y < 0) {
                scalePercent = 1.0;
            }
            CGAffineTransform scale = CGAffineTransformMakeScale(scalePercent, scalePercent);
            self.videoView.transform = scale;
            self.videoView.center = CGPointMake(self.startCenter.x + point.x, self.startCenter.y + point.y);
            self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:scalePercent/1.f];
            self.view.superview.backgroundColor = [UIColor clearColor];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (point.y > 100 ) {
                [self dismissViewControllerAnimated:YES completion:nil];
            }else {
                [UIView animateWithDuration:0.25 animations:^{
                    self.videoView.transform = CGAffineTransformIdentity;
                    self.videoView.center = self.startCenter;
                    self.view.backgroundColor = [UIColor blackColor];
                    self.view.superview.backgroundColor = [UIColor blackColor];
                }completion:^(BOOL finished) {
                    self.videoView.frame = self.view.bounds;
                    self.videoView.center = self.startCenter;
                    [self.videoView hiddenToolBars:NO animation:NO];
                }];
            }
            
            _panGestureWorking = NO;
        }
            break;

        default:
            break;
    }
}
@end


@implementation LBVideoPlayerTransitioning

#pragma mark - UIViewControllerAnimatedTransitioning
-(void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIView *containerView = [transitionContext containerView];
    
    if (self.type == LBVideoPlayerAnimationTypePresent) {
        //目标控制器
        LBVideoPlayerViewController *toViewController = (LBVideoPlayerViewController *)[transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        [containerView addSubview:toViewController.view];
                
        toViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, CGRectGetWidth(toViewController.sourceView.bounds)/CGRectGetWidth(toViewController.view.bounds), CGRectGetHeight(toViewController.sourceView.bounds)/CGRectGetHeight(toViewController.view.bounds));
        toViewController.view.center = [LB_KEY_WINDOW convertPoint:toViewController.sourceView.center fromView:toViewController.sourceView.superview];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            toViewController.view.transform = CGAffineTransformIdentity;
            toViewController.view.center = LB_KEY_WINDOW.center;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    }
    else if (self.type == LBVideoPlayerAnimationTypeDismiss){
        containerView.backgroundColor = [UIColor clearColor];
        
        //源控制器
        LBVideoPlayerViewController *fromViewController = (LBVideoPlayerViewController *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
        [fromViewController.videoView hiddenToolBars:YES animation:NO];
        fromViewController.view.backgroundColor = [UIColor clearColor];
        
        fromViewController.dismissAnimationInProgress = YES;
        
        fromViewController.videoView.layer.cornerRadius = fromViewController.sourceView.layer.cornerRadius;
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            fromViewController.videoView.transform = CGAffineTransformScale(CGAffineTransformIdentity, CGRectGetWidth(fromViewController.sourceView.bounds)/CGRectGetWidth(fromViewController.videoView.bounds), CGRectGetHeight(fromViewController.sourceView.bounds)/CGRectGetHeight(fromViewController.videoView.bounds));
            
            fromViewController.videoView.center = [LB_KEY_WINDOW convertPoint:fromViewController.sourceView.center fromView:fromViewController.sourceView.superview];
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
            fromViewController.dismissAnimationInProgress = NO;
        }];
    }
    
}

-(NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.25;
}

#pragma mark - UIViewControllerTransitioningDelegate
-(id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    self.type = LBVideoPlayerAnimationTypePresent;
    return self;
}

-(id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    self.type = LBVideoPlayerAnimationTypeDismiss;
    return self;
}

@end
