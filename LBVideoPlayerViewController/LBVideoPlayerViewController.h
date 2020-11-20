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
- (instancetype)initWithVideoUrl:(NSURL *)videoUrl;
- (void)lb_interfaceOrientation:(UIInterfaceOrientation)orientation;
- (UIInterfaceOrientationMask)lb_supportedInterfaceOrientations;
@end

NS_ASSUME_NONNULL_END
