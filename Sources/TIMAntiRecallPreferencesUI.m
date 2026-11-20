#import "TIMAntiRecallPreferencesUI.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallMarks.h"
@interface TIMAntiRecallSettingsSwitch : UISwitch
@property(nonatomic,copy) NSDictionary *timantirecall_chat;
@end
@implementation TIMAntiRecallSettingsSwitch @end
@interface TIMAntiRecallPreferencesController ()
@property(nonatomic,copy) NSString *timantirecall_owner;
@property(nonatomic,copy) NSDictionary *timantirecall_chat;
@property(nonatomic) unsigned timantirecall_mode; // 0 settings, 1 chats
@property(nonatomic,copy) NSArray<NSDictionary *> *timantirecall_items;
@property(nonatomic,copy) NSArray *timantirecall_observers;
@end
static NSArray<NSDictionary *> *timantirecall_optionRows(void) {
    return @[@{@"key":@"enabled",@"title":@"启用防撤回",@"icon":@"shield.checkered"},
             @{@"key":@"persistMarks",@"title":@"重启后保留撤回标记",@"icon":@"externaldrive"},
             @{@"key":@"showTime",@"title":@"标记旁显示拦截时间",@"icon":@"clock"},
             @{@"key":@"packetDiagnostics",@"title":@"红包诊断日志",@"icon":@"doc.text.magnifyingglass"},
             @{@"key":@"autoClaimRedPackets",@"title":@"自动领取红包",@"icon":@"gift"},
              @{ @"key":@"claimOwnRedPackets",@"title":@"自动领取自己发的红包",@"icon":@"person.crop.circle.badge.checkmark"},
             @{ @"key":@"messageReplay",@"title":@"消息双击复读",@"icon":@"arrow.2.squarepath"}];
}
static NSString *timantirecall_chatTitle(NSDictionary *chat) {
    BOOL group=[chat[@"kind"] intValue]==2;
    NSString *identifier=group?[chat[@"group"] stringValue]:chat[@"alias"]?:chat[@"peer"];
    return [NSString stringWithFormat:@"%@ · %@",group?@"群聊":@"私聊",identifier?:@"身份待确认"];
}
@implementation TIMAntiRecallPreferencesController
- (instancetype)initWithOwner:(NSString *)owner chat:(NSDictionary *)chat {
    self=[super initWithStyle:UITableViewStyleInsetGrouped];
    if(self){_timantirecall_owner=[owner copy];_timantirecall_chat=[chat copy];_timantirecall_items=@[];self.title=@"TIM 防撤回";}
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight=56;self.tableView.accessibilityIdentifier=@"TIMAntiRecall.preferences";
    if(self.navigationController.viewControllers.firstObject==self)
        self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(timantirecall_done)];
    __weak typeof(self) weakSelf=self;NSMutableArray *tokens=[NSMutableArray array];
    for(NSNotificationName name in @[TIMAntiRecallSettingsChangedNotification,TIMAntiRecallStateChangedNotification,UIApplicationDidBecomeActiveNotification])
        [tokens addObject:[NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){[weakSelf timantirecall_reload];}]];
    self.timantirecall_observers=[tokens copy];[self timantirecall_reload];
}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self timantirecall_reload];}
- (void)dealloc {for(id token in _timantirecall_observers)[NSNotificationCenter.defaultCenter removeObserver:token];}
- (void)timantirecall_done {[self dismissViewControllerAnimated:YES completion:nil];}
- (BOOL)timantirecall_validOwner {return [self.timantirecall_owner isEqual:timantirecall_currentAccount()];}
- (void)timantirecall_reload {
    if(!self.isViewLoaded)return;
    if(![self timantirecall_validOwner])self.timantirecall_items=@[];
    else if(self.timantirecall_mode==1)self.timantirecall_items=[timantirecall_settings() timantirecall_chatsForOwner:self.timantirecall_owner];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {(void)tableView;return self.timantirecall_mode?1:2;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;if(self.timantirecall_mode)return (NSInteger)self.timantirecall_items.count;
    return section==0?(NSInteger)timantirecall_optionRows().count:(self.timantirecall_chat?2:1);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if(self.timantirecall_mode==1)return @"已识别的聊天";
    return section==0?@"功能":@"聊天";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(![self timantirecall_validOwner])return @"账号已切换，请关闭面板后重新打开；不会显示或修改其他账号的数据。";
    NSError *error=[timantirecall_settings() timantirecall_lastError]?:[timantirecall_sharedMarks() timantirecall_lastError];
    if(error)return [@"保存/读取失败：" stringByAppendingString:error.localizedDescription];
    if(self.timantirecall_mode==1)return @"先打开目标聊天即可识别。关闭只放行此聊天之后的撤回；不会删除已经保留的消息。总开关关闭时所有聊天均放行。";
    if(section==0)return @"自动领取处理 TIM 新到的群聊和私聊普通红包，不呈现普通领取小窗；资格与验证仍由 TIM 原生流程判定。后台仅在 TIM 进程确实得到执行时间并收到消息时尝试，不保活或唤醒。本人发送红包须同时开启两个领取开关；两个领取开关及诊断日志均默认关闭。消息双击复读默认关闭；开启后双击纯文字消息立即发送原文，替代 TIM 双击朗读；@消息、链接和混合内容不复读。";
    return @"标记与开关保存在TIM沙盒，仅本机有效，不上传；不恢复TIM已删除的原消息。移除插件不会删除TIM聊天记录。";
}
- (void)timantirecall_icon:(NSString *)name cell:(UITableViewCell *)cell {
    static NSCache *cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=12;});
    UIImage *icon=[cache objectForKey:name];
    if(!icon) {
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(28,28)];
        icon=[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context){
            [UIColor.systemBlueColor setFill];[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0,28,28) cornerRadius:7] fill];
            UIImageSymbolConfiguration *configuration=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
            UIImage *symbol=[[UIImage systemImageNamed:name withConfiguration:configuration] imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            [symbol drawInRect:CGRectMake(6,6,16,16)];
        }];
        [cache setObject:icon forKey:name];
    }
    cell.imageView.image=icon;
    cell.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.font=[UIFont systemFontOfSize:17];cell.detailTextLabel.font=[UIFont systemFontOfSize:12];
    cell.textLabel.numberOfLines=0;cell.detailTextLabel.numberOfLines=0;
}
- (UISwitch *)timantirecall_switch:(NSString *)key value:(BOOL)value enabled:(BOOL)enabled index:(NSInteger)index {
    TIMAntiRecallSettingsSwitch *control=[TIMAntiRecallSettingsSwitch new];control.on=value;control.enabled=enabled;control.onTintColor=UIColor.systemBlueColor;
    control.accessibilityIdentifier=key;control.tag=index;
    [control addTarget:self action:@selector(timantirecall_changed:) forControlEvents:UIControlEventValueChanged];return control;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    BOOL active=[self timantirecall_validOwner],enabled=[timantirecall_settings() timantirecall_enabled];
    if(self.timantirecall_mode==1) {
        NSDictionary *chat=self.timantirecall_items[(NSUInteger)path.row];
        cell.textLabel.text=timantirecall_chatTitle(chat);[self timantirecall_icon:@"bubble.left.and.bubble.right" cell:cell];
        cell.accessoryView=[self timantirecall_switch:@"chat-enabled" value:[timantirecall_settings() timantirecall_enabledForChat:chat] enabled:active&&enabled index:1000+path.row];
        ((TIMAntiRecallSettingsSwitch *)cell.accessoryView).timantirecall_chat=chat;
    }else if(path.section==0) {
        NSDictionary *row=timantirecall_optionRows()[(NSUInteger)path.row];NSString *key=row[@"key"];
        cell.textLabel.text=row[@"title"];[self timantirecall_icon:row[@"icon"] cell:cell];
        BOOL value=path.row==0?enabled:path.row==1?[timantirecall_settings() timantirecall_persistMarks]:path.row==2?[timantirecall_settings() timantirecall_showTime]:path.row==3?[timantirecall_settings() timantirecall_packetDiagnostics]:path.row==4?[timantirecall_settings() timantirecall_autoClaimRedPackets]:path.row==5?[timantirecall_settings() timantirecall_claimOwnRedPackets]:[timantirecall_settings() timantirecall_messageReplay];
        cell.accessoryView=[self timantirecall_switch:key value:(path.row<3||active)&&value enabled:active&&(path.row==0||path.row>=3||enabled) index:path.row];
    }else {
        if(self.timantirecall_chat && path.row==0) {
            cell.textLabel.text=@"当前聊天防撤回";cell.detailTextLabel.text=timantirecall_chatTitle(self.timantirecall_chat);
            [self timantirecall_icon:@"bubble.left.and.bubble.right" cell:cell];
            cell.accessoryView=[self timantirecall_switch:@"current-chat" value:[timantirecall_settings() timantirecall_enabledForChat:self.timantirecall_chat] enabled:active&&enabled index:2000];
            ((TIMAntiRecallSettingsSwitch *)cell.accessoryView).timantirecall_chat=self.timantirecall_chat;
        }else {
            cell.textLabel.text=@"按聊天单独设置";
            [self timantirecall_icon:@"list.bullet" cell:cell];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    cell.selectionStyle=cell.accessoryView?UITableViewCellSelectionStyleNone:UITableViewCellSelectionStyleDefault;
    if(!active){cell.userInteractionEnabled=NO;cell.textLabel.textColor=UIColor.secondaryLabelColor;}
    return cell;
}
- (void)timantirecall_error:(NSError *)error {
    if(self.presentedViewController)return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"未保存" message:error.localizedDescription?:@"账号已切换或身份未确认" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)timantirecall_commitSwitch:(UISwitch *)control {
    NSError *error=nil;BOOL ok=NO;
    if([self timantirecall_validOwner]) {
        if(control.tag>=1000) {
            NSDictionary *chat=[control isKindOfClass:TIMAntiRecallSettingsSwitch.class]?((TIMAntiRecallSettingsSwitch *)control).timantirecall_chat:nil;
            ok=[timantirecall_settings() timantirecall_setChat:chat enabled:control.isOn error:&error];
        }else if(control.tag>=0 && control.tag<3) {
            NSString *key=timantirecall_optionRows()[(NSUInteger)control.tag][@"key"];
            ok=[timantirecall_settings() timantirecall_updateOptions:@{key:@(control.isOn)} error:&error];
            if(ok && control.tag==1)[timantirecall_sharedMarks() timantirecall_setPersistent:control.isOn];
        }else if(control.tag>=3 && control.tag<=5) {
            NSString *key=@[@"diagnostics",@"autoClaim",@"claimOwn"][(NSUInteger)control.tag-3];
            ok=[timantirecall_settings() timantirecall_setPacketOption:key enabled:control.isOn owner:self.timantirecall_owner error:&error];
        }else if(control.tag==6) {
            ok=[timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@(control.isOn)} error:&error];
        }
    }
    if(!ok)[self timantirecall_error:error];[self timantirecall_reload];
}
- (void)timantirecall_changed:(UISwitch *)control {
    if(control.tag==1 && !control.isOn) {
        control.on=YES;
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"关闭重启保留？" message:@"将移除本插件已保存的标记文件；本次进程中的红框仍保留，不会删除TIM聊天消息。" preferredStyle:UIAlertControllerStyleAlert];
        __weak typeof(self) weakSelf=self;
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"关闭保存" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action){control.on=NO;[weakSelf timantirecall_commitSwitch:control];}]];
        [self presentViewController:alert animated:YES completion:nil];return;
    }
    [self timantirecall_commitSwitch:control];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];if(![self timantirecall_validOwner])return;
    if(self.timantirecall_mode || path.section!=1 || path.row!=(self.timantirecall_chat?1:0))return;
    TIMAntiRecallPreferencesController *next=[[TIMAntiRecallPreferencesController alloc] initWithOwner:self.timantirecall_owner chat:self.timantirecall_chat];
    next.timantirecall_mode=1;next.title=@"按聊天单独设置";
    [self.navigationController pushViewController:next animated:NO];
}
@end
