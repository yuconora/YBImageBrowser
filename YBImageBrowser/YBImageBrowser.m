//
//  YBImageBrowser.m
//  YBImageBrowserDemo
//
//  Created by 杨少 on 2018/4/10.
//  Copyright © 2018年 杨波. All rights reserved.
//

#import "YBImageBrowser.h"
#import "YBImageBrowserView.h"
#import <pthread.h>

@interface YBImageBrowser () {
    CGRect frameOfSelfForOrientationPortrait;
    CGRect frameOfSelfForOrientationLandscapeRight;
    CGRect frameOfSelfForOrientationLandscapeLeft;
    CGRect frameOfSelfForOrientationPortraitUpsideDown;
    UIInterfaceOrientationMask supportAutorotateTypes;
    pthread_mutex_t lock;
}

@property (nonatomic, strong) YBImageBrowserView *browserView;

@end

@implementation YBImageBrowser

#pragma mark life cycle

- (void)dealloc {
    pthread_mutex_destroy(&lock);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    return [self initWithFrame:[UIScreen mainScreen].bounds];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        pthread_mutex_init(&lock, NULL);
        [self configSupportAutorotateTypes];
        [self configFrameForStatusBarOrientation];
        [self addNotification];
        [self addDeviceOrientationNotification];
        [self initYBImageBrowserView];
    }
    return self;
}

#pragma mark private

- (void)initYBImageBrowserView {
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _browserView = [[YBImageBrowserView alloc] initWithFrame:self.bounds collectionViewLayout:layout];
}

//找到 keywidow 和 topController 支持屏幕旋转方向的交集
- (void)configSupportAutorotateTypes {
    UIApplication *application = [UIApplication sharedApplication];
    UIInterfaceOrientationMask keyWindowSupport = [application supportedInterfaceOrientationsForWindow:[YBImageBrowserTool getNormalWindow]];
    UIViewController *topController = [YBImageBrowserTool getTopController];
    UIInterfaceOrientationMask topControllerSupport = ![topController shouldAutorotate] ? UIInterfaceOrientationMaskPortrait : topController.supportedInterfaceOrientations;
    supportAutorotateTypes = keyWindowSupport & topControllerSupport;
}

//根据当前 statusBar 的方向，配置 statusBar 在不同方向下 self 的 frame
- (void)configFrameForStatusBarOrientation {
    CGRect frame = self.frame;
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (statusBarOrientation == UIInterfaceOrientationPortrait || statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        frameOfSelfForOrientationPortrait = frame;
        frameOfSelfForOrientationPortraitUpsideDown = frame;
        frameOfSelfForOrientationLandscapeLeft = CGRectMake(frame.origin.y, frame.origin.x, frame.size.height, frame.size.width);
        frameOfSelfForOrientationLandscapeRight = frameOfSelfForOrientationLandscapeLeft;
    } else if(statusBarOrientation == UIInterfaceOrientationLandscapeLeft || statusBarOrientation == UIInterfaceOrientationLandscapeRight) {
        frameOfSelfForOrientationPortrait = CGRectMake(frame.origin.y, frame.origin.x, frame.size.height, frame.size.width);
        frameOfSelfForOrientationPortraitUpsideDown = frameOfSelfForOrientationPortrait;
        frameOfSelfForOrientationLandscapeLeft = frame;
        frameOfSelfForOrientationLandscapeRight = frame;
    } 
}

//根据 statusBar 方向改变 UI
- (void)resetUserInterfaceLayoutByStatusBarOrientation {
    CGRect *tagetRect = NULL;
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (statusBarOrientation == UIInterfaceOrientationPortrait && (supportAutorotateTypes & UIInterfaceOrientationMaskPortrait)) {
        tagetRect = &frameOfSelfForOrientationPortrait;
    } else if(statusBarOrientation == UIInterfaceOrientationLandscapeLeft && (supportAutorotateTypes & UIInterfaceOrientationMaskLandscapeLeft)) {
        tagetRect = &frameOfSelfForOrientationLandscapeLeft;
    } else if (statusBarOrientation == UIInterfaceOrientationLandscapeRight && (supportAutorotateTypes & UIInterfaceOrientationMaskLandscapeRight)) {
        tagetRect = &frameOfSelfForOrientationLandscapeRight;
    } else if (statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown && (supportAutorotateTypes & UIInterfaceOrientationMaskPortraitUpsideDown)) {
        tagetRect = &frameOfSelfForOrientationPortraitUpsideDown;
    } else {
        return;
    }
    self.frame = *tagetRect;
    [_browserView resetUserInterfaceLayout];
}

//根据 device 方向改变 UI
- (void)resetUserInterfaceLayoutByDeviceOrientation {
    CGRect *tagetRect = NULL;
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIDeviceOrientationPortrait && (supportAutorotateTypes & UIInterfaceOrientationMaskPortrait)) {
        tagetRect = &frameOfSelfForOrientationPortrait;
    } else if(deviceOrientation == UIDeviceOrientationLandscapeRight && (supportAutorotateTypes & UIInterfaceOrientationMaskLandscapeLeft)) {
        tagetRect = &frameOfSelfForOrientationLandscapeLeft;
    } else if (deviceOrientation == UIDeviceOrientationLandscapeLeft && (supportAutorotateTypes & UIInterfaceOrientationMaskLandscapeRight)) {
        tagetRect = &frameOfSelfForOrientationLandscapeRight;
    } else if (deviceOrientation == UIInterfaceOrientationPortraitUpsideDown && (supportAutorotateTypes & UIInterfaceOrientationMaskPortraitUpsideDown)) {
        tagetRect = &frameOfSelfForOrientationPortraitUpsideDown;
    } else {
        return;
    }
    self.frame = *tagetRect;
    [_browserView resetUserInterfaceLayout];
}

#pragma mark public

- (void)show {
    [self showToView:[UIApplication sharedApplication].keyWindow];
}

- (void)showToView:(UIView *)view {
    if (!_dataArray || _dataArray.count <= 0) return;
    [self addSubview:self.browserView];
    [view addSubview:self];
}

- (void)hide {
    [self removeFromSuperview];
}

#pragma mark notification

- (void)addNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notice_hide) name:YBImageBrowser_notice_hideSelf object:nil];
}

- (void)notice_hide {
    [self hide];
}

#pragma mark device orientation

- (void)addDeviceOrientationNotification {
    UIDevice *device = [UIDevice currentDevice];
    [device beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChanged:) name:UIDeviceOrientationDidChangeNotification  object:device];
}

- (void)deviceOrientationChanged:(NSNotification *)note{
    if (NO) {
        //自动方向变化单一，不需操作
        YBLog(@"不需变化");
        return;
    }
    pthread_mutex_lock(&lock);
    [self resetUserInterfaceLayoutByDeviceOrientation];
    pthread_mutex_unlock(&lock);
}

#pragma mark setter

- (void)setDataArray:(NSArray<YBImageBrowserModel *> *)dataArray {
    if (!_dataArray) {
        _dataArray = dataArray;
        _browserView.dataArray = dataArray;
    }
}

@end
