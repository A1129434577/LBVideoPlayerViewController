//
//  LBVideoPlayerView.m
//  LBVideoPlayerView
//
//  Created by 刘彬 on 2020/5/19.
//  Copyright © 2020 yc. All rights reserved.
//

#import "LBVideoPlayerView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AFNetworking/AFNetworking.h>

static BOOL LBVideoPlayerTrafficPlayHasPrompt = NO;
static BOOL LBVideoPlayerTrafficHasAutoPlay = NO;

@interface LBVideoPlayerView ()
@property (nonatomic, strong) NSURL          *url;
@property (nonatomic, assign) NSTimeInterval loadedTimeInterval;
@property (nonatomic, strong) AVPlayer      *player;
@property (nonatomic, strong) id             playTimeObserver;
@property (nonatomic, assign) BOOL panGestureDirectionH;//手势是水平方向
@property (nonatomic, assign) BOOL panGestureBeforePlaying;//拖动之前在播放
@property (nonatomic, assign) BOOL isProgressSliderAction;

@property (nonatomic, assign) YCVideoViewState lastState;


@property (nonatomic, weak) UIViewController    *viewController;

@property (nonatomic, strong) MPVolumeView      *volumeView;
@property (nonatomic, strong) UISlider          *volumeViewSlider;
@property (nonatomic, strong) YCVideoCoverView  *videoCenterView;
@property (nonatomic, strong) UIView            *bottomActionsView;
@property (nonatomic, strong) UILabel           *muteHitLabel;//静音提示
@property (nonatomic, strong) UIButton          *playBtn;
@property (nonatomic, strong) UIProgressView    *progressView;
@property (nonatomic, strong) UISlider          *progressSlider;
@property (nonatomic, strong) UILabel           *timeLabel;
@end

@implementation LBVideoPlayerView
+(Class)layerClass{
    return AVPlayerLayer.self;
}
- (instancetype)initWithFrame:(CGRect)frame url:(nullable NSURL *)url viewController:(nonnull UIViewController *)vc
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.clipsToBounds = YES;
        //静音状态下播放
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoTapGesture:)];
        [self addGestureRecognizer:tapGesture];
        
        UIPanGestureRecognizer *panGesture =[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGestureAction:)];
        [self addGestureRecognizer:panGesture];
        _panGesture  = panGesture;
        
        
        _url = url;
        _viewController = vc;
        
        //监听程序进入后台
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive)name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive)name:UIApplicationDidBecomeActiveNotification object:nil];
        
        //监听播放结束
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayDidEnd) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
        
        __weak typeof(self) weakSelf = self;
        
        AVPlayer *player = [[AVPlayer alloc] init];
        _player = player;
        if (url) {
            AVPlayerItem * playerItem = [AVPlayerItem playerItemWithURL:url];
            [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionNew context:nil];
//            [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges)) options:NSKeyValueObservingOptionNew context:nil];
            [player replaceCurrentItemWithPlayerItem:playerItem];
        }
        
        AVPlayerLayer * playerLayer = (AVPlayerLayer *)self.layer;
        playerLayer.player = player;
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        
        
        _playTimeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
            //获取当前播放时间
            NSInteger currentTime = CMTimeGetSeconds(weakSelf.player.currentItem.currentTime);
            NSInteger duration = CMTimeGetSeconds(weakSelf.player.currentItem.duration);
            
            float progress = currentTime*1.0/(duration?duration:0);
            if (progress < 0) {
                weakSelf.progressSlider.value = 0;
            }else if (progress > 1.0) {
                weakSelf.progressSlider.value = 1;
            }else{
                weakSelf.progressSlider.value = progress;
            }
            currentTime = progress*duration;
            weakSelf.timeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld/%02ld:%02ld",currentTime/60,currentTime%60,duration/60,duration%60];
            
        }];
        
        
        [self addSubview:self.volumeView];
        
        [self addSubview:self.videoCenterView];
        
        [self addSubview:self.topActionsView];
        
        [self addSubview:self.bottomActionsView];
        
        
        [self addSubview:self.muteHitLabel];
        
        
        [self startNetWorkMonitoring];
    }
    return self;
}

-(void)layoutSubviews{
    [super layoutSubviews];
    CGRect topActionsViewFrame = _topActionsView.frame;
    CGRect bottomActionsViewFrame = _bottomActionsView.frame;
    
    if (CGRectEqualToRect(self.frame, self.viewController.view.bounds)) {
        topActionsViewFrame.size.height = 30+MAX(LB_SAFE_AREA_TOP_HEIGHT(self.viewController), 20);
        bottomActionsViewFrame.size.height = 50+LB_SAFE_AREA_BOTTOM_HEIGHT(self.viewController);
    }else{
        topActionsViewFrame.size.height = 30;
        bottomActionsViewFrame.size.height = 50;
    }
    if (CGRectGetMinY(topActionsViewFrame) == 0) {
        bottomActionsViewFrame.origin.y = CGRectGetHeight(self.frame)-CGRectGetHeight(bottomActionsViewFrame);
    }else{
        bottomActionsViewFrame.origin.y = CGRectGetHeight(self.frame);
    }
    
    
    _topActionsView.frame = topActionsViewFrame;
    
    _bottomActionsView.frame = bottomActionsViewFrame;
}

-(void)dealloc{
    [_player removeTimeObserver:_playTimeObserver];
    
    AVPlayerItem * playerItem = _player.currentItem;
    if ([self observerKeyPath:NSStringFromSelector(@selector(status))]) {
        [playerItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
    }
    if ([self observerKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))]) {
        [playerItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark getter
-(MPVolumeView *)volumeView{
    if (!_volumeView) {
        MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, -100, CGRectGetWidth(self.frame), 3)];
        volumeView.showsVolumeSlider = NO;
        for (UIView *view in [volumeView subviews]){
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
                self.volumeViewSlider = (UISlider*)view;
                break;
            }
        }
        _volumeView = volumeView;
    }
    return _volumeView;
}
-(UIView *)topActionsView{
    if (!_topActionsView) {
        NSBundle *bundle = [LBVideoPlayerView LBVideoPlayerViewBundle];
        
        UIView *topActionsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), 30+LB_SAFE_AREA_TOP_HEIGHT(self.viewController))];
        topActionsView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        topActionsView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
        
        UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, CGRectGetHeight(topActionsView.frame)-30, 50, 30)];
        backBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        backBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 13, 0);
        backBtn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
        backBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [backBtn setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"back_icon@3x" ofType:@"png"]] forState:UIControlStateNormal];
        [topActionsView addSubview:backBtn];
        _backButton = backBtn;
        
        UIButton *moreBtn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(topActionsView.frame)-CGRectGetMinX(backBtn.frame)-CGRectGetWidth(backBtn.frame), CGRectGetMinY(backBtn.frame), CGRectGetWidth(backBtn.frame), CGRectGetHeight(backBtn.frame))];
        moreBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        moreBtn.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
        moreBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin;
        moreBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [moreBtn setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"more@3x" ofType:@"png"]] forState:UIControlStateNormal];
        moreBtn.hidden = YES;
        [topActionsView addSubview:moreBtn];
        _moreButton = moreBtn;
        
        _topActionsView = topActionsView;
    }
    return _topActionsView;
}

- (YCVideoCoverView *)videoCenterView{
    if (!_videoCenterView) {
        YCVideoCoverView *videoCenterView = [[YCVideoCoverView alloc] initWithFrame:self.bounds];
        [videoCenterView.loadingBtn addTarget:self action:@selector(loadingBtnAction:) forControlEvents:UIControlEventTouchUpInside];
        _videoCenterView = videoCenterView;
    }
    return _videoCenterView;
}



- (UIView *)bottomActionsView{
    if (!_bottomActionsView) {
        NSBundle *bundle = [LBVideoPlayerView LBVideoPlayerViewBundle];
        
        UIView *bottomActionsView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight([UIScreen mainScreen].bounds)-(50+LB_SAFE_AREA_BOTTOM_HEIGHT(self.viewController)), CGRectGetWidth(self.frame), 50+LB_SAFE_AREA_BOTTOM_HEIGHT(self.viewController))];
        bottomActionsView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        bottomActionsView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
        UIPanGestureRecognizer *panGesture =[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGestureAction:)];
        [bottomActionsView addGestureRecognizer:panGesture];
        
        
        UIButton *playBtn = [[UIButton alloc] initWithFrame:CGRectMake(30, (CGRectGetHeight(bottomActionsView.frame)-15)/2, 13, 15)];
        playBtn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
        [playBtn setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"play_icon@3x" ofType:@"png"]] forState:UIControlStateNormal];
        [playBtn setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"pause_icon@3x" ofType:@"png"]] forState:UIControlStateSelected];
        [playBtn addTarget:self action:@selector(playBtnAction:) forControlEvents:UIControlEventTouchUpInside];
        [bottomActionsView addSubview:playBtn];
        _playBtn = playBtn;
        
        
        UIButton *fullScreenBtn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(bottomActionsView.frame)-25-30, (CGRectGetHeight(bottomActionsView.frame)-25)/2.f, 25, 25)];
        fullScreenBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
        [fullScreenBtn setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"full_screen@3x" ofType:@"png"]] forState:UIControlStateNormal];
        [fullScreenBtn setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"full_screen_close@3x" ofType:@"png"]] forState:UIControlStateSelected];
        [bottomActionsView addSubview:fullScreenBtn];
        _fullScreenButton = fullScreenBtn;
        
        
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMinX(fullScreenBtn.frame)-100, CGRectGetMinY(playBtn.frame), 100, CGRectGetHeight(playBtn.frame))];
        timeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
        timeLabel.textColor = [UIColor whiteColor];
        timeLabel.textAlignment = NSTextAlignmentCenter;
        timeLabel.font = [UIFont systemFontOfSize:11];
        timeLabel.text = @"00:00/00:00";
        [bottomActionsView addSubview:timeLabel];
        _timeLabel = timeLabel;
        
        
        UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(CGRectGetMinX(playBtn.frame)+30, CGRectGetMidY(playBtn.frame)-2/2.f, CGRectGetMinX(timeLabel.frame)-(CGRectGetMinX(playBtn.frame)+25), 2)];
        progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
        progressView.progressTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        progressView.trackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
        [bottomActionsView addSubview:progressView];
        _progressView = progressView;
        
        
        UISlider *progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(progressView.frame)+3*2, 1)];
        progressSlider.center = progressView.center;
        progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
        progressSlider.minimumTrackTintColor = [UIColor whiteColor];
        progressSlider.maximumTrackTintColor = [UIColor clearColor];
        [progressSlider setThumbImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"point_10" ofType:@"png"]] forState:UIControlStateNormal];
        [progressSlider setThumbImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"point_15" ofType:@"png"]] forState:UIControlStateHighlighted];
        [progressSlider addTarget:self action:@selector(progressSliderValueChanged) forControlEvents:UIControlEventValueChanged];
        [progressSlider addTarget:self action:@selector(progressSliderBegainAction) forControlEvents:UIControlEventTouchDown];
        [progressSlider addTarget:self action:@selector(progressSliderEndAction) forControlEvents:UIControlEventTouchUpInside];
        [bottomActionsView addSubview:progressSlider];
        _progressSlider = progressSlider;
        
        
        _bottomActionsView = bottomActionsView;
    }
    return _bottomActionsView;;
}

-(UILabel *)muteHitLabel{
    if (!_muteHitLabel) {
        UILabel *muteHitLabel = [[UILabel alloc] initWithFrame:CGRectMake(-105, CGRectGetMinY(self.bottomActionsView.frame)-30, 105, 20)];
        muteHitLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        muteHitLabel.clipsToBounds = YES;
        muteHitLabel.layer.cornerRadius = CGRectGetHeight(muteHitLabel.frame)/2;
        muteHitLabel.textAlignment = NSTextAlignmentCenter;
        muteHitLabel.font = [UIFont systemFontOfSize:11];
        muteHitLabel.textColor = [UIColor whiteColor];
        muteHitLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
        muteHitLabel.text = @"当前为静音状态";
        _muteHitLabel = muteHitLabel;
    }
    return _muteHitLabel;
}
-(NSURL *)mediaUrl{
    return _url;
}

+ (NSBundle *)LBVideoPlayerViewBundle
{
    NSBundle *videoPlayerViewBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"LBVideoPlayerView" ofType:@"bundle"]];
    return videoPlayerViewBundle;
}
// 进行检索获取Key
- (BOOL)observerKeyPath:(NSString *)key
{
    id info = self.player.currentItem.observationInfo;
    NSArray *array = [info valueForKey:@"_observances"];
    for (id objc in array) {
        id Properties = [objc valueForKeyPath:@"_property"];
        id newObserver = [objc valueForKeyPath:@"_observer"];
        
        NSString *keyPath = [Properties valueForKeyPath:@"_keyPath"];
        if ([key isEqualToString:keyPath] && [newObserver isEqual:self]) {
            return YES;
        }
    }
    return NO;
}
#pragma mark setter
-(void)setMediaUrl:(NSURL *)mediaUrl{
    _url = mediaUrl;

    self.status = YCVideoViewStateLoading;
    
    AVPlayerItem *currentPlayerItem = self.player.currentItem;
    if ([self observerKeyPath:NSStringFromSelector(@selector(status))]) {
        [currentPlayerItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
    }
    if ([self observerKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))]) {
        [currentPlayerItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))];
    }
    
    
    AVPlayerItem * playerItem = [AVPlayerItem playerItemWithURL:_url?_url:[NSURL URLWithString:@""]];
    [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionNew context:nil];
//    [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges)) options:NSKeyValueObservingOptionNew context:nil];
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
}
-(void)setStatus:(YCVideoViewState)status{
    _status = status;
    switch (status) {
        case YCVideoViewStateReadyToPlay:
            if (self.playBtn.selected) {
                self.status = YCVideoViewStatePlaying;
            }
            break;
        case YCVideoViewStatePlaying:
            self.playBtn.selected = YES;
            [self.player play];
            
            if ([self observerKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))] == NO) {
                [self.player.currentItem addObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges)) options:NSKeyValueObservingOptionNew context:nil];
            }
            break;
        case YCVideoViewStatePause:
            self.playBtn.selected = NO;
            [self.player pause];
            break;
            
        default:
            break;
    }
    
    
    self.videoCenterView.status = status;
}


#pragma mark KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(status))]) {
        AVPlayerItem *playerItem = object;
        AVPlayerItemStatus status = playerItem.status;
        
        switch (status) {
            case AVPlayerItemStatusFailed:
            case AVPlayerItemStatusUnknown:
                
                self.status = YCVideoViewStateLoadFaild;
                break;
            case AVPlayerItemStatusReadyToPlay:
                [self setLoadProgress];
                self.progressSlider.value = 0;
                NSInteger duration = CMTimeGetSeconds(_player.currentItem.duration);
                self.timeLabel.text = [NSString stringWithFormat:@"00:00/%02ld:%02ld",duration/60,duration%60];
                
                AFNetworkReachabilityStatus networkReachabilityStatus = [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
                if (networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi || (networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN && LBVideoPlayerTrafficHasAutoPlay == YES)) {//wifi或者以及提示过用流量播放的情况下自动播放
                    self.status = YCVideoViewStatePlaying;
                    [self hiddenToolBars:YES animation:YES];
                }else{
                    self.status = YCVideoViewStateReadyToPlay;
                }
                
                if ([AVAudioSession sharedInstance].outputVolume == 0) {//静音提示
                    [self showMuteView];
                }
                
                
                break;
            default:
                break;
        }
    }
    else if ([keyPath isEqualToString:NSStringFromSelector(@selector(loadedTimeRanges))]){
        NSArray<NSValue *> *loadedTimeRanges = [_player.currentItem loadedTimeRanges];
        CMTimeRange range = [loadedTimeRanges.firstObject CMTimeRangeValue];
        CGFloat start = CMTimeGetSeconds(range.start);
        CGFloat duration = CMTimeGetSeconds(range.duration);
        self.loadedTimeInterval = start + duration;
        [self setLoadProgress];
    }
}

#pragma mark Notification
//音频播放中断
- (void)movieInterruption:(NSNotification *)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger interuptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    NSNumber  *seccondReason  = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] ;
    switch (interuptionType) {
        case AVAudioSessionInterruptionTypeBegan:
        {
            if (self.status == YCVideoViewStatePlaying) {
                self.status = YCVideoViewStatePause;
            }
            break;
        }
        case AVAudioSessionInterruptionTypeEnded:
            if (self.status == YCVideoViewStatePlaying) {
                self.status = YCVideoViewStatePause;
            }
            break;
    }
    switch ([seccondReason integerValue]) {
        case AVAudioSessionInterruptionOptionShouldResume:
            //恢复播放
            if (self.status == YCVideoViewStatePause) {
                self.status = YCVideoViewStatePlaying;
            }
            break;
        default:
            break;
    }
}
//程序进入后台
- (void)applicationWillResignActive{
    if (self.status == YCVideoViewStatePlaying) {
        self.panGestureBeforePlaying = YES;
        self.status = YCVideoViewStatePause;
    }
}
-(void)applicationDidBecomeActive{
    if (self.panGestureBeforePlaying) {
        self.status = YCVideoViewStatePlaying;
        
        self.panGestureBeforePlaying = NO;
    }
}
//视频播放完毕
-(void)moviePlayDidEnd
{
    if (self.status == YCVideoViewStatePlaying) {
        self.progressSlider.value = 0;
        self.status = YCVideoViewStatePause;
    }
    [_player seekToTime:CMTimeMultiplyByFloat64(_player.currentItem.duration, self.progressSlider.value) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}
#pragma mark ButtonAction
-(void)loadingBtnAction:(UIButton *)sender{
    if (self.status == YCVideoViewStateLoadFaild) {
        self.status = YCVideoViewStateLoading;
        if (self.player.currentItem) {
            AVPlayerItem * playerItem = self.player.currentItem;
            if ([self observerKeyPath:NSStringFromSelector(@selector(status))]) {
                [playerItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
            }
            if ([self observerKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))]) {
                [playerItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))];
            }
            
        }
        AVPlayerItem * playerItem = [AVPlayerItem playerItemWithURL:self.url?self.url:[NSURL URLWithString:@""]];
        [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionNew context:nil];
//        [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges)) options:NSKeyValueObservingOptionNew context:nil];
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }else{
        self.status = YCVideoViewStatePlaying;
        
        //点击了播放，则去除流量播放这个提醒
        if ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN) {
            self.videoCenterView.prompt = nil;
            LBVideoPlayerTrafficPlayHasPrompt = YES;
            LBVideoPlayerTrafficHasAutoPlay = YES;
        }
    }
}
-(void)playBtnAction:(UIButton *)sender{
    if (sender.selected) {
        self.status = YCVideoViewStatePause;
    }else if (self.status == YCVideoViewStateReadyToPlay || self.status == YCVideoViewStatePause) {
        self.status = YCVideoViewStatePlaying;
        
        //点击了播放，则去除流量播放这个提醒
        if ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN) {
            self.videoCenterView.prompt = nil;
            LBVideoPlayerTrafficPlayHasPrompt = YES;
            LBVideoPlayerTrafficHasAutoPlay = YES;
        }
    }
}
#pragma mark private


-(void)startNetWorkMonitoring{
    __weak typeof(self) weakSelf = self;
    AFNetworkReachabilityManager *manager = [AFNetworkReachabilityManager sharedManager];
    /* AFNetworking的Block内使用self须改为weakSelf, 避免循环强引用, 无法释放 */
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status)
     {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status)
            {
                case AFNetworkReachabilityStatusNotReachable:
                case AFNetworkReachabilityStatusUnknown:
                    weakSelf.videoCenterView.prompt = @"网络连接失败，请检查网络连接";
                    break;
                case AFNetworkReachabilityStatusReachableViaWWAN:
                {
                    if (LBVideoPlayerTrafficPlayHasPrompt == NO) {
                        if (weakSelf.status == YCVideoViewStatePlaying) {
                            weakSelf.status = YCVideoViewStatePause;
                        }
                        weakSelf.videoCenterView.prompt = @"正在使用流量播放，是否继续？";
                    }
                }
                    break;
                case AFNetworkReachabilityStatusReachableViaWiFi:
                    weakSelf.videoCenterView.prompt = nil;
                    break;
                default:
                    break;
            }
        });
    }];
    // 开启网络状态监听
    [manager startMonitoring];
}
-(void)setLoadProgress{
    float progress = self.loadedTimeInterval/CMTimeGetSeconds(self.player.currentItem.duration);
    if (progress >= 0.0 && progress <= 1.0) {
        [self.progressView setProgress:progress animated:YES];
    }
}
-(void)progressSliderBegainAction{
    self.isProgressSliderAction = YES;
    if (self.status == YCVideoViewStatePlaying) {
        self.panGestureBeforePlaying = YES;
        self.status = YCVideoViewStatePause;
    }else{
        self.panGestureBeforePlaying = NO;
    }
}
-(void)progressSliderValueChanged{
    //通过进度条控制播放进度
    if (_player) {
        
        NSInteger duration = CMTimeGetSeconds(_player.currentItem.duration);
        if (duration>0) {
            
            float progress = _progressSlider.value;
            NSInteger currentTime = progress*duration;
            self.timeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld/%02ld:%02ld",currentTime/60,currentTime%60,duration/60,duration%60];
            
        }else{
            self.progressSlider.value = 0;
        }
        
        
    }
}
-(void)progressSliderEndAction{
    self.isProgressSliderAction = NO;
    if (self.panGestureBeforePlaying == YES) {
        self.status = YCVideoViewStatePlaying;
    }
    if (_player.currentItem.canStepForward || _player.currentItem.canStepBackward) {
        //跳转到指定的时间
        [_player seekToTime:CMTimeMultiplyByFloat64(_player.currentItem.duration, self.progressSlider.value) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
}


-(void)showMuteView{
    CGRect muteHitLabelFrame = self.muteHitLabel.frame;
    muteHitLabelFrame.origin.x = -CGRectGetHeight(muteHitLabelFrame)/2;
    [UIView animateWithDuration:0.3 animations:^{
        self.muteHitLabel.frame = muteHitLabelFrame;
    }];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGRect muteHitLabelFrame = weakSelf.muteHitLabel.frame;
        muteHitLabelFrame.origin.x = -CGRectGetWidth(muteHitLabelFrame);
        [UIView animateWithDuration:0.3 animations:^{
            weakSelf.muteHitLabel.frame = muteHitLabelFrame;
        }];
    });
}
-(void)videoTapGesture:(UITapGestureRecognizer *)tapGesture{
    CGPoint point = [tapGesture locationInView:self];
    
    if (!CGRectContainsPoint(self.bottomActionsView.frame, point) && !CGRectContainsPoint(CGRectMake(0, 0, CGRectGetWidth(self.topActionsView.frame), CGRectGetMaxY(self.topActionsView.frame)), point)) {
        [self hiddenToolBars:(CGRectGetMinY(_topActionsView.frame) == 0) animation:YES];
    }
}

-(void)hiddenToolBars:(BOOL)hidden animation:(BOOL)animation{
    CGRect topActionsViewFrame = _topActionsView.frame;
    CGRect bottomActionsViewFrame = _bottomActionsView.frame;
    
    if (hidden) {
        topActionsViewFrame.origin.y = -CGRectGetHeight(topActionsViewFrame);
        bottomActionsViewFrame.origin.y = CGRectGetHeight([UIScreen mainScreen].bounds);
    }else{
        self.topActionsView.hidden = self.bottomActionsView.hidden = NO;
        topActionsViewFrame.origin.y = 0;
        bottomActionsViewFrame.origin.y = CGRectGetHeight(self.frame)-CGRectGetHeight(bottomActionsViewFrame);
    }
    [UIView animateWithDuration:(animation?0.2:0) animations:^{
        self.topActionsView.frame = topActionsViewFrame;
        self.bottomActionsView.frame = bottomActionsViewFrame;
    } completion:^(BOOL finished) {
        if (hidden) {
            self.topActionsView.hidden = self.bottomActionsView.hidden = YES;
        }
    }];
}

-(void)panGestureAction:(UIPanGestureRecognizer *)panGesture{
    CGPoint point=[panGesture translationInView:panGesture.view];
    
    
    if (panGesture.state==UIGestureRecognizerStateBegan) {
        CGFloat absX = fabs(point.x);
        CGFloat absY = fabs(point.y);
        
        self.panGestureDirectionH = (absX>absY) || (panGesture.view==self.bottomActionsView);
        
        if (self.panGestureDirectionH && !self.isProgressSliderAction) {
            if (self.status == YCVideoViewStatePlaying) {
                self.panGestureBeforePlaying = YES;
                self.status = YCVideoViewStatePause;
            }else{
                self.panGestureBeforePlaying = NO;
            }
        }
        
    }
    else if(panGesture.state==UIGestureRecognizerStateChanged) {
        if (self.panGestureDirectionH) {
            self.progressSlider.value += point.x/250;
            [self progressSliderValueChanged];
        }else{
            if ([panGesture locationInView:self].x<CGRectGetWidth(self.frame)/2) {
                [UIScreen mainScreen].brightness -= point.y/100;
            }else{
                self.volumeViewSlider.value -= point.y/100;
            }
        }
        
        [panGesture setTranslation:CGPointZero inView:panGesture.view];
    }
    else if (panGesture.state==UIGestureRecognizerStateEnded){
        self.isProgressSliderAction = NO;
        if (self.panGestureDirectionH) {
            if (_player.currentItem.canStepForward || _player.currentItem.canStepBackward) {
                //跳转到指定的时间
                [_player seekToTime:CMTimeMultiplyByFloat64(_player.currentItem.duration, self.progressSlider.value) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            }
        }
        //因为slider的手势和panGesture可能冲突，所以这里不能写在if (self.panGestureDirectionH)里
        if (self.panGestureBeforePlaying == YES) {
            self.status = YCVideoViewStatePlaying;
        }
    }
}


@end


@implementation YCVideoLoadingButton
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
        self.layer.cornerRadius = 3;
        self.titleLabel.font = [UIFont systemFontOfSize:13];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageEdgeInsets = UIEdgeInsetsMake((CGRectGetHeight(self.bounds)-15)/2, 0, (CGRectGetHeight(self.bounds)-15)/2, 0);
        
        _activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activity.center = CGPointMake(20, CGRectGetHeight(frame)/2);
        [self addSubview:_activity];
        [_activity startAnimating];
        
        
        self.videoStatus = YCVideoViewStateLoading;
        
    }
    return self;
}

-(void)setVideoStatus:(YCVideoViewState)videoStatus{
    _videoStatus = videoStatus;
    
    NSBundle *bundle = [LBVideoPlayerView LBVideoPlayerViewBundle];
    switch (videoStatus) {
        case YCVideoViewStateLoading:
            _activity.hidden = NO;
            self.titleEdgeInsets = UIEdgeInsetsMake(0, 30, 0, 0);
            [self setImage:nil forState:UIControlStateNormal];
            [self setTitle:@"正在加载中..." forState:UIControlStateNormal];
            break;
        case YCVideoViewStateLoadFaild:
            _activity.hidden = YES;
            self.titleEdgeInsets = UIEdgeInsetsMake(0, -(CGRectGetHeight(self.bounds)-15), 0, 0);
            [self setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"video_play_icon@3x" ofType:@"png"]] forState:UIControlStateNormal];
            [self setTitle:@"重新加载" forState:UIControlStateNormal];
            break;
            
        default:
            _activity.hidden = YES;
            self.titleEdgeInsets = UIEdgeInsetsMake(0, -(CGRectGetHeight(self.bounds)-15), 0, 0);
            [self setImage:[UIImage imageWithContentsOfFile:[bundle pathForResource:@"video_play_icon@3x" ofType:@"png"]] forState:UIControlStateNormal];
            [self setTitle:@"继续播放" forState:UIControlStateNormal];
            break;
    }
}

@end


@interface YCVideoCoverView ()
@property (nonatomic, assign) CGFloat statusLabelInitHeight;
@property (nonatomic, strong) UILabel *networkStatusLabel;

@end
@implementation YCVideoCoverView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        _statusLabelInitHeight = 50;
        
        UILabel *networkStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.frame)/2-50, CGRectGetWidth(self.frame), _statusLabelInitHeight)];
        networkStatusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        networkStatusLabel.backgroundColor = [UIColor clearColor];
        networkStatusLabel.textColor = [UIColor whiteColor];
        networkStatusLabel.font = [UIFont systemFontOfSize:13];
        networkStatusLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:networkStatusLabel];
        _networkStatusLabel = networkStatusLabel;
        
        
        YCVideoLoadingButton *loadingBtn = [[YCVideoLoadingButton alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.frame)-120)/2, CGRectGetHeight(self.frame)/2, 120, 40)];
        loadingBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:loadingBtn];
        _loadingBtn = loadingBtn;
        
        
        NSLayoutConstraint *loadingBtnLayout = [NSLayoutConstraint constraintWithItem:loadingBtn attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:networkStatusLabel attribute:NSLayoutAttributeBottom multiplier:1 constant:0];
        NSLayoutConstraint *loadingBtnLayout1 = [NSLayoutConstraint constraintWithItem:loadingBtn attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:120];
        NSLayoutConstraint *loadingBtnLayout2 = [NSLayoutConstraint constraintWithItem:loadingBtn attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:40];
        NSLayoutConstraint *loadingBtnLayout3 = [NSLayoutConstraint constraintWithItem:loadingBtn attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
        [self addConstraint:loadingBtnLayout];
        [self addConstraint:loadingBtnLayout1];
        [self addConstraint:loadingBtnLayout2];
        [self addConstraint:loadingBtnLayout3];
        
        self.status = YCVideoViewStateLoading;
        self.prompt = nil;
    }
    return self;
}

-(void)setStatus:(YCVideoViewState )status{
    _status = status;
    if (status==YCVideoViewStatePlaying) {
        self.hidden = YES;
    }
    else if (status==YCVideoViewStateReadyToPlay){
        self.hidden = !self.prompt.length;
    }
    else{
        self.hidden = NO;
        if (status == YCVideoViewStateLoading) {
            self.prompt = nil;
        }else if (status == YCVideoViewStateLoadFaild){
            self.prompt = @"加载失败";
        }
    }
    self.loadingBtn.videoStatus = status;
}
-(void)setPrompt:(NSString *)prompt{
    _prompt = prompt;
    self.networkStatusLabel.text = prompt;
    if (prompt.length) {
        self.hidden = NO;
        __block CGRect networkStatusLabelFrame = self.networkStatusLabel.frame;
        
        [UIView animateWithDuration:0.3 animations:^{
            networkStatusLabelFrame.size.height = self.statusLabelInitHeight;
            self.networkStatusLabel.frame = networkStatusLabelFrame;
            [self layoutIfNeeded];
        }];
        
    }else{
        __block CGRect networkStatusLabelFrame = self.networkStatusLabel.frame;
        [UIView animateWithDuration:0.3 animations:^{
            networkStatusLabelFrame.size.height = self.statusLabelInitHeight-CGRectGetHeight(self.loadingBtn.frame)/2;
            self.networkStatusLabel.frame = networkStatusLabelFrame;
            [self layoutIfNeeded];
        }];
        
    }
}
@end
