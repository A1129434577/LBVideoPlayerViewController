//
//  LBVideoPlayerViewController.h
//  LBVideoPlayerViewController
//
//  Created by 刘彬 on 2020/9/24.
//  Copyright © 2020 刘彬. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol LBSupportedInterfaceOrientationsDelegate <NSObject>
- (UIInterfaceOrientationMask)lb_supportedInterfaceOrientations;
- (void)lb_interfaceOrientation:(UIInterfaceOrientation)orientation;
@end

@interface LBVideoPlayerViewController : UIViewController<LBSupportedInterfaceOrientationsDelegate>
- (void)lb_interfaceOrientation:(UIInterfaceOrientation)orientation;
- (UIInterfaceOrientationMask)lb_supportedInterfaceOrientations;

/// 初始化
/// @param videoUrl 视频地址
/// @param sourceView 可以通过设置sourceView改变其推出动画，如果sourceView不为空，推出动画将从sourceView开始，如果sourceView为空，则为系统默认推出动画
- (instancetype)initWithVideoUrl:(nullable NSURL *)videoUrl sourceView:(nullable UIView *)sourceView;
@end

NS_ASSUME_NONNULL_END
