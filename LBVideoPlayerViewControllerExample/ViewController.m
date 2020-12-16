//
//  ViewController.m
//  LBVideoPlayerViewControllerExample
//
//  Created by 刘彬 on 2020/11/20.
//

#import "ViewController.h"
#import "LBVideoPlayerViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.view.frame)-300)/2, 150, 300, 400)];
    btn.backgroundColor = [UIColor lightGrayColor];
    btn.layer.cornerRadius = 10;
    [btn setTitle:@"播放视频" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(videoPlay:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}
-(void)videoPlay:(UIButton *)sender{
    LBVideoPlayerViewController *videoPlayer = [[LBVideoPlayerViewController alloc] initWithVideoUrl:[NSURL URLWithString:@"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"] sourceView:sender];
    [self presentViewController:videoPlayer animated:YES completion:NULL];
}

@end
