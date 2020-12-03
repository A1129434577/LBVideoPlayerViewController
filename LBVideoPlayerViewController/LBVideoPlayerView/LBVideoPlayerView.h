//
//  LBVideoPlayerView.h
//  LBVideoPlayerView
//
//  Created by 刘彬 on 2020/5/19.
//  Copyright © 2020 yc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "LBUIMacro.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, YCVideoViewState) {
    YCVideoViewStateLoading = 1,
    YCVideoViewStateReadyToPlay,
    YCVideoViewStatePlaying,
    YCVideoViewStatePause,
    YCVideoViewStateLoadFaild,
};

@interface LBVideoPlayerView : UIView
@property (nonatomic, strong, nullable) NSURL *mediaUrl;
@property (nonatomic, assign) YCVideoViewState status;
@property (nonatomic, strong) UIView   *topActionsView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, strong) UIButton *fullScreenButton;
@property (nonatomic, strong, readonly) UIPanGestureRecognizer *panGesture;//声音、亮度、进度手势
- (instancetype)initWithFrame:(CGRect)frame url:(nullable NSURL *)url viewController:(UIViewController *)vc;
-(void)hiddenToolBars:(BOOL)hidden animation:(BOOL)animation;
@end

@interface YCVideoLoadingButton : UIButton
@property (nonatomic, strong) UIActivityIndicatorView *activity;
@property (nonatomic, assign) YCVideoViewState videoStatus;
@end


@interface YCVideoCoverView : UIView
@property (nonatomic, strong) YCVideoLoadingButton *loadingBtn;
@property (nonatomic, strong,nullable) NSString *prompt;
@property (nonatomic, assign) YCVideoViewState status;
@end

NS_ASSUME_NONNULL_END
