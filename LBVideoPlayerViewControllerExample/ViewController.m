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
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self videoPlayer];
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self videoPlayer];
}
-(void)videoPlayer{
    LBVideoPlayerViewController *videoPlayer = [[LBVideoPlayerViewController alloc] initWithVideoUrl:[NSURL URLWithString:@"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"]];
    [self presentViewController:videoPlayer animated:YES completion:NULL];
}

@end
