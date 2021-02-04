# LBVideoPlayerViewController
一个超轻量级的视频播放器，支持屏幕旋转、手动旋转、下拉关闭。
# 安装方式
```ruby
pod 'LBVideoPlayerViewController'
```
# 使用方法
```Objc
LBVideoPlayerViewController *videoPlayer = [[LBVideoPlayerViewController alloc] initWithVideoUrl:[NSURL URLWithString:@"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"] sourceView:sender];
[self presentViewController:videoPlayer animated:YES completion:NULL];
```
![](https://github.com/A1129434577/LBVideoPlayerViewController/blob/main/LBVideoPlayerViewController.gif?raw=true)
