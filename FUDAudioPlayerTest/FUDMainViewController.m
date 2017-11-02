//
//  FUDMainViewController.m
//  FUDAudioPlayerTest
//
//  Created by LanFudong on 2017/10/17.
//  Copyright © 2017年 LanFudong. All rights reserved.
//

#import "FUDMainViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface FUDMainViewController ()

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSTimer *musicTimer;
@property (weak, nonatomic) IBOutlet UISlider *durationSlider;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (nonatomic, assign) BOOL isPaused;

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) NSDictionary *recordSettings;
@property (nonatomic, strong) NSURL *recordFileURL;

@end

#define AUDIOSESSION [AVAudioSession sharedInstance]

@implementation FUDMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置后台播放
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    // 如何要让自己的Session解除激活后恢复其他App Session的激活状态呢？使用：
    // [[AVAudioSession sharedInstance] setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    
    [self setupUIActions];
    
    [self registerObservers];
}

- (void)registerObservers {
    // 注册音频输出路径变化通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChange:) name:AVAudioSessionRouteChangeNotification object:nil];
    // 播放被中断的通知，比如来电话、闹铃等
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    // 其他APP占据AudioSession的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionOccupied:) name:AVAudioSessionSilenceSecondaryAudioHintNotification object:nil];
}

- (void)setupUIActions {
    [self.durationSlider addTarget:self action:@selector(durationSliderValueChanged) forControlEvents:UIControlEventValueChanged];
    [self.durationSlider addTarget:self action:@selector(durationSliderTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self.durationSlider addTarget:self action:@selector(durationSliderTouchCancel) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressRecordButton:)];
    [self.recordButton addGestureRecognizer:longPress];
}

- (void)routeChange:(NSNotification *)notification {
    NSDictionary *dict = notification.userInfo;
    int changeReason = [dict[AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSession *session = [AVAudioSession sharedInstance];
    // 旧的输出路径不可用(比如拔出耳机，耳机当然就不可用啦)
    if (changeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *previousRoute = dict[AVAudioSessionRouteChangePreviousRouteKey];
        
        for (AVAudioSessionPortDescription *output in previousRoute.outputs) {
            if (output.portType == AVAudioSessionPortHeadphones) {
                if (self.audioPlayer.playing) {
                    [self musicPause:nil];
                }
            }
        }
    }
    // 有新的可用设备
    else if (changeReason == AVAudioSessionRouteChangeReasonNewDeviceAvailable) {
        for (AVAudioSessionPortDescription *output in session.currentRoute.outputs) {
            if (output.portType == AVAudioSessionPortHeadphones) {
                
            }
        }
    }
}

- (void)audioInterrupted:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if ([userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan) {
        
        NSLog(@"中断开始");
    } else if ([userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeEnded) {
        // 检查是否需要恢复播放
        if ([userInfo[AVAudioSessionInterruptionOptionKey] intValue] == AVAudioSessionInterruptionOptionShouldResume) {
            
        }
        
        NSLog(@"中断结束");
    }
}

- (void)audioSessionOccupied:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if ([userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] intValue] == AVAudioSessionSilenceSecondaryAudioHintTypeBegin) {
        NSLog(@"AVAudioSession被占据！");
    } else if ([userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] intValue] == AVAudioSessionSilenceSecondaryAudioHintTypeEnd) {
        NSLog(@"AVAudioSession解除占据！");
    }
}

- (void)onLongPressRecordButton:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan) {
        NSLog(@"长按录音按钮开始");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
        self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.recordFileURL settings:self.recordSettings error:nil];
        self.audioRecorder.meteringEnabled = YES;
        if ([self.audioRecorder prepareToRecord]) {
            [self.audioRecorder record];
        } else {
            NSLog(@"初始化录音失败");
        }
    } else if (longPress.state == UIGestureRecognizerStateEnded) {
         NSLog(@"长按录音按钮结束");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [self.audioRecorder stop];
    } else {
        NSLog(@"长按录音按钮, %ld", longPress.state);
    }
}

- (NSURL *)recordFileURL {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    NSDateFormatter *formater = [[NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *nowDateString = [formater stringFromDate:[NSDate date]];
    NSString *recordFilePath = [docPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.caf", nowDateString]];
    NSURL *url = [NSURL fileURLWithPath:recordFilePath];
    
    return url;
}

- (NSDictionary *)recordSettings {
    if (_recordSettings == nil) {
        NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
        // 设置录音格式
        [settings setValue:[NSNumber numberWithInt:kAudioFormatAppleLossless] forKey:AVFormatIDKey];
        // 设置采样频率: 8000/44100/96000
        [settings setValue:[NSNumber numberWithFloat:44100] forKey:AVSampleRateKey];
        // 设置录音通道数: 1 or 2
        [settings setValue:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
        // 设置线性采样位数: 8/16/24/32
        [settings setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
        // 设置录音质量
        [settings setValue:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
        
        _recordSettings = [NSDictionary dictionaryWithDictionary:settings];
    }
    
    return _recordSettings;
}

- (NSTimer *)musicTimer {
    if (_musicTimer == nil) {
        _musicTimer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(musicTimerAction) userInfo:nil repeats:YES];
        [_musicTimer setFireDate:[NSDate distantFuture]];
    }
    return _musicTimer;
}

- (void)musicTimerAction {
    self.durationSlider.maximumValue = self.audioPlayer.duration;
    self.durationSlider.minimumValue = 0;
    self.durationSlider.value = self.audioPlayer.currentTime;
}

- (void)setPlayingMusicInfo {
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"avatar"]];
    NSDictionary *dic = @{
                          MPMediaItemPropertyTitle:@"What You Made Me Do",
                          MPMediaItemPropertyArtist:@"Taylor Swift",
                          MPMediaItemPropertyArtwork:artwork
                          };
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dic];
}

- (IBAction)startPlayAudio:(id)sender {
    [self playeAudio:@"sms-received.caf"];
}
- (IBAction)startPlayMusic:(id)sender {
    [self playMusicWithAVAudioPlayer:@"Taylor+Swift+-+Look+What+You+Made+Me+Do.mp3"];
    [self setPlayingMusicInfo];
}
- (IBAction)musicPause:(UIButton *)sender {
    if (!self.isPaused) {
        self.isPaused = YES;
        [self.audioPlayer pause];
        [sender setTitle:@"播放" forState:UIControlStateNormal];
        [self.musicTimer setFireDate:[NSDate distantFuture]];
    } else {
        BOOL isPlay = [self.audioPlayer play];
        if (isPlay) {
            self.isPaused = NO;
            [sender setTitle:@"暂停" forState:UIControlStateNormal];
            [self.musicTimer setFireDate:[NSDate distantPast]];
        } else {
            NSLog(@"音乐播放失败！");
        }
    }
    
}
- (IBAction)musicStop:(UIButton *)sender {
    [self.audioPlayer stop];
    self.audioPlayer.currentTime = 0;
    [self.musicTimer invalidate];
    self.musicTimer = nil;
    self.durationSlider.value = 0;
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)durationSliderValueChanged {
    [self.musicTimer setFireDate:[NSDate distantFuture]];
}

- (void)durationSliderTouchUp {
    self.audioPlayer.currentTime = self.durationSlider.value;
    [self.audioPlayer play];
    [self.musicTimer setFireDate:[NSDate distantPast]];
}
- (void)durationSliderTouchCancel {
    self.audioPlayer.currentTime = self.durationSlider.value;
    [self.audioPlayer play];
    [self.musicTimer setFireDate:[NSDate distantPast]];
}

void audioFinishPlayCallback(SystemSoundID soundID,void * clientData) {
    NSLog(@"系统声音播放完了");
}

- (void)playeAudio:(NSString *)audioName {
    NSString *path = [[NSBundle mainBundle] pathForResource:audioName ofType:nil];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    
    SystemSoundID soundID = 0;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)(fileURL), &soundID);
    AudioServicesAddSystemSoundCompletion(soundID, NULL, NULL, audioFinishPlayCallback, NULL);
    AudioServicesPlaySystemSound(soundID);
//    AudioServicesPlayAlertSound(soundID); // 带振动的
}

- (void)playMusicWithAVAudioPlayer:(NSString *)musicName {
    // 激活AVAudioSession
    // 因为AVAudioSession会影响其他App的表现，当自己App的Session被激活，其他App的就会被解除激活。
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:musicName ofType:nil];
    NSURL *musicURL = [NSURL fileURLWithPath:musicPath];
    NSError *error;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:musicURL error:&error];
    self.audioPlayer.volume = 1;
    self.audioPlayer.numberOfLoops = 1;
    self.audioPlayer.currentTime = 0;
    [self.audioPlayer prepareToPlay];
    BOOL isPlay = [self.audioPlayer play];
    
    if (isPlay) {
        [self.musicTimer setFireDate:[NSDate distantPast]];
    } else {
        NSLog(@"音乐播放失败！");
    }
}

// 响应控制中心的事件
- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPlay:
                [self musicPause:nil];
                NSLog(@"暂停播放");
                break;
            case UIEventSubtypeRemoteControlPause:
                [self musicPause:nil];
                NSLog(@"继续播放");
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                NSLog(@"下一曲");
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                NSLog(@"上一曲");
                break;
            default:
                break;
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    self.audioPlayer = nil;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
