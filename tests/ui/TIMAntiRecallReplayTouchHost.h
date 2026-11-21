#import "TIMAntiRecallReplay.h"
// Synthetic TIM views and service; XCUI generates touches through UIKit, never calls capture/complete.
@interface TIMAntiRecallReplayTouchHost : NSObject
@property(nonatomic,strong) UILabel *timantirecall_sendLabel,*timantirecall_nativeLabel;
@property(nonatomic,strong) UIViewController *timantirecall_chat;
@property(nonatomic,strong) NSArray<TIMAntiRecallTestBaseView *> *timantirecall_rows;
- (void)timantirecall_start;
@end
@implementation TIMAntiRecallReplayTouchHost
- (UILabel *)timantirecall_label:(NSString *)identifier text:(NSString *)text frame:(CGRect)frame {
    UILabel *label=[[UILabel alloc] initWithFrame:frame];label.text=text;
    label.isAccessibilityElement=YES;label.accessibilityIdentifier=identifier;
    label.backgroundColor=UIColor.systemBackgroundColor;
    [self.timantirecall_chat.view addSubview:label];return label;
}
- (void)timantirecall_nativeDoubleTap:(UITapGestureRecognizer *)tap {
    if(tap.state!=UIGestureRecognizerStateRecognized)return;
    [NTAIOContentDoubleTapService doubleTapGestureActionWithGesture:tap record:NSObject.new viewController:self.timantirecall_chat tappedCellView:tap.view];
    self.timantirecall_nativeLabel.text=[NSString stringWithFormat:@"%lu",(unsigned long)NTAIOContentDoubleTapService.timantirecall_originalCalls];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    (void)change;(void)context;
    if(object==QQMsgService.getInstance&&[keyPath isEqual:@"timantirecall_sendCalls"])
        self.timantirecall_sendLabel.text=[NSString stringWithFormat:@"%lu",(unsigned long)QQMsgService.getInstance.timantirecall_sendCalls];
    else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)timantirecall_start {
    QQAccountsManager.GetInstance.currentUid=@"self_uid";
    [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:NULL];
    QQMsgService.getInstance.timantirecall_sendCalls=0;
    NTAIOContentDoubleTapService.timantirecall_originalCalls=0;
    BOOL installed=timantirecall_installInlineIndicator()&&timantirecall_installMessageReplay();
    self.timantirecall_chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"peer_a" type:1];
    UIViewController *root=timantirecall_window.rootViewController;
    [root addChildViewController:self.timantirecall_chat];
    self.timantirecall_chat.view.frame=root.view.bounds;[root.view addSubview:self.timantirecall_chat.view];
    [self.timantirecall_chat didMoveToParentViewController:root];
    UIViewController *container=[UIViewController new];[self.timantirecall_chat addChildViewController:container];
    container.view.frame=self.timantirecall_chat.view.bounds;[self.timantirecall_chat.view addSubview:container.view];
    [container didMoveToParentViewController:self.timantirecall_chat];
    UIScrollView *scroll=[[UIScrollView alloc] initWithFrame:container.view.bounds];
    scroll.contentSize=CGSizeMake(scroll.bounds.size.width,scroll.bounds.size.height*2);[container.view addSubview:scroll];
    NSMutableArray *rows=[NSMutableArray array];
    CGFloat width=scroll.bounds.size.width;
    for(NSUInteger i=0;i<2;i++) {
        UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.frame=CGRectMake(0,200+i*110,width,72);[scroll addSubview:cell];[cell layoutIfNeeded];
        TIMAntiRecallTestBaseView *row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:cell.contentView.bounds];
        [cell.contentView addSubview:row];[rows addObject:row];
        OCTextElement *text=[OCTextElement new];text.content=@"真实点击测试";text.atNtUid=@"";text.subElementType=@0;text.atChannelId=@0;text.atRoleId=@0;
        OCMsgElement *element=[OCMsgElement new];element.textElement=text;
        OCMsgRecord *record=timantirecall_record(1,2001+(int64_t)i,@"peer_a",0);record.elements=@[element];
        if(i)record.senderUid=@"self_uid";
        NSDictionary<NSString *,UIView *> *views=[TIMAntiRecallRecordBridge timantirecall_replayViewsForRow:row];
        UIView *content=views[@"content"],*avatar=views[@"avatar"];
        content.backgroundColor=UIColor.lightGrayColor;content.layer.cornerRadius=12;
        if(i){content.frame=CGRectMake(width-156,8,100,44);avatar.frame=CGRectMake(width-44,8,36,36);}
        UILabel *textLabel=[[UILabel alloc] initWithFrame:content.bounds];textLabel.text=@"文字";textLabel.textAlignment=NSTextAlignmentCenter;[content addSubview:textLabel];
        if(!i){
            content.isAccessibilityElement=YES;content.accessibilityIdentifier=@"replay-native-text";content.accessibilityLabel=@"文字";
            UITapGestureRecognizer *native=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(timantirecall_nativeDoubleTap:)];
            native.numberOfTapsRequired=2;[content addGestureRecognizer:native];
        }
        CGFloat x=i?12:width-36;
        UIView *blank=[[UIView alloc] initWithFrame:CGRectMake(x,12,24,32)];
        blank.isAccessibilityElement=YES;blank.accessibilityIdentifier=i?@"replay-outgoing-area":@"replay-incoming-area";
        blank.accessibilityLabel=i?@"本人气泡外侧":@"对方气泡外侧";
        // No target/action on this UIView: touch must reach the production row recognizer.
        [row addSubview:blank];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];
        timantirecall_updateReplayRow(row,@"self_uid");
    }
    self.timantirecall_rows=rows;
    self.timantirecall_sendLabel=[self timantirecall_label:@"replay-send-count" text:@"0" frame:CGRectMake(20,100,80,30)];
    self.timantirecall_nativeLabel=[self timantirecall_label:@"replay-native-count" text:@"0" frame:CGRectMake(120,100,80,30)];
    [QQMsgService.getInstance addObserver:self forKeyPath:@"timantirecall_sendCalls" options:0 context:NULL];
    [self timantirecall_label:@"replay-status" text:installed?@"ready":@"install-failed" frame:CGRectMake(220,100,140,30)];
}
@end
static void timantirecall_startReplayTouchHost(void) {
    static TIMAntiRecallReplayTouchHost *host;host=[TIMAntiRecallReplayTouchHost new];[host timantirecall_start];
}
