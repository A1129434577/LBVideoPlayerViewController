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


@interface LBVideoPlayerViewController ()
@property (nonatomic, assign) CGFloat brightness;

@property (nonatomic, strong) LBVideoPlayerView *videoView;
@property (nonatomic, assign) UIInterfaceOrientation currentOrientation;
@property (nonatomic, strong) NSURL *videoUrl;
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

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl
{
    self = [super init];
    if (self) {
        _videoUrl = videoUrl;
        self.modalPresentationStyle = UIModalPresentationFullScreen;

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    LBVideoPlayerView *videoView = [[LBVideoPlayerView alloc] initWithFrame:self.view.bounds url:self.videoUrl viewController:self];
    [self.view addSubview:videoView];
    _videoView = videoView;
    
    
    __weak typeof(videoView) weakVideoView = videoView;
    __weak typeof(self) weakSelf = self;
    
    videoView.backButton.lb_action = ^(UIButton * _Nonnull sender) {
        if (weakSelf.currentOrientation == UIInterfaceOrientationLandscapeRight) {
            __weak typeof(weakVideoView.fullScreenButton) weakFullScreenButton = weakVideoView.fullScreenButton;
            weakVideoView.fullScreenButton.lb_action?
            weakVideoView.fullScreenButton.lb_action(weakFullScreenButton):NULL;
        }else{
            if (weakSelf.presentingViewController) {
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }else{
                [weakSelf.navigationController popViewControllerAnimated:YES];
            }
        }
    };
    
    
    videoView.fullScreenButton.lb_action = ^(UIButton * _Nonnull sender) {
        sender.selected = !sender.selected;
        if (sender.selected) {
            weakSelf.currentOrientation = UIInterfaceOrientationLandscapeRight;
        }
        else {
            weakSelf.currentOrientation = UIInterfaceOrientationPortrait;
        }
        [weakSelf lb_interfaceOrientation:weakSelf.currentOrientation];
    };
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _videoView.frame = self.view.bounds;
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
@end
