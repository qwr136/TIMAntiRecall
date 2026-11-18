#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallPreferencesUI.h"

static void timantirecall_testRecallSettings(UIView *root) {
    TIMAntiRecallTestSession *session=[TIMAntiRecallTestSession new];
    OCInitSessionConfig *config=[OCInitSessionConfig new];config.selfUid=@"self_uid";
    TIMAntiRecallTestBaseView *row=timantirecall_row(root,CGRectMake(8,80,root.bounds.size.width-16,100));
    OCMsgRecord *record=timantirecall_record(1,1151,@"peer_a",123456);
    NSDictionary *chat=timantirecall_recordIdentity(record,@"self_uid");
    NSData *packet=timantirecall_private(@"peer_a",@"self_uid",1151);NSObject *extra=NSObject.new;
    timantirecall_step(^{
        [session init:config depends:nil dispatcherDepends:nil listener:nil];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:record]];
        NSError *error=nil;
        timantirecall_check([timantirecall_settings() timantirecall_setChat:chat enabled:NO error:&error],@"private chat switch saved");
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush" msgBuffer:packet pushExtraInfo:extra];
        timantirecall_check(session.timantirecall_pushCalls==1 && session.timantirecall_lastPush[1]==packet && session.timantirecall_lastPush[2]==extra,
                           @"disabled private recall forwards exact objects once");
        timantirecall_count(row,0,@"disabled chat produces no new mark");
        [timantirecall_settings() timantirecall_setChat:chat enabled:YES error:&error];
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush" msgBuffer:packet pushExtraInfo:extra];
        timantirecall_check(session.timantirecall_pushCalls==1,@"re-enabled recall is intercepted again");
    });
    timantirecall_step(^{
        timantirecall_count(row,1,@"re-enabled chat displays retained row mark");
        NSDictionary *event=[timantirecall_sharedMarks() timantirecall_eventForIdentity:chat];
        timantirecall_check([event[@"capturedAt"] doubleValue]>0,@"matched message retains first intercept timestamp");
        NSError *error=nil;timantirecall_check([timantirecall_sharedMarks() timantirecall_flush:&error],@"real mark archive flushed successfully");
        TIMAntiRecallMarkStore *loaded=[[TIMAntiRecallMarkStore alloc] initWithURL:timantirecall_stateURL(@"marks.plist") persistent:YES];
        timantirecall_check([[loaded timantirecall_eventForIdentity:chat][@"capturedAt"] isEqual:event[@"capturedAt"]],
                           @"archive reload preserves exact timestamp and row identity");
        [timantirecall_settings() timantirecall_updateOptions:@{@"showTime":@YES} error:&error];
    });
    timantirecall_step(^{
        timantirecall_layout(row);TIMAntiRecallIndicatorView *indicator=timantirecall_indicators(row).firstObject;
        UILabel *label=(UILabel *)indicator.subviews.firstObject;
        timantirecall_check([label.text hasPrefix:@"已撤回 · "] && [label.text componentsSeparatedByString:@":"].count==3,
                           @"time option produces actual clock label on target row");
        timantirecall_check(CGRectContainsRect(indicator.bounds,label.frame),@"time stays within red frame");
        NSError *error=nil;[timantirecall_settings() timantirecall_updateOptions:@{@"enabled":@NO} error:&error];
        NSData *group=timantirecall_group(7001,@"peer_a",1152,33,1700000000);
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush" msgBuffer:group pushExtraInfo:extra];
        timantirecall_check(session.timantirecall_pushCalls==2 && session.timantirecall_lastPush[1]==group,@"global off forwards group recall once");
    });
    timantirecall_step(^{
        timantirecall_count(row,0,@"global off hides existing plugin decoration");
        NSError *error=nil;[timantirecall_settings() timantirecall_updateOptions:@{@"enabled":@YES,@"showTime":@NO} error:&error];
        NSDictionary *groupChat=@{@"owner":@"self_uid",@"kind":@2,@"group":@7001};
        [timantirecall_settings() timantirecall_setChat:groupChat enabled:NO error:&error];
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush" msgBuffer:timantirecall_group(7001,@"peer_a",1153,33,1700000000) pushExtraInfo:extra];
        timantirecall_check(session.timantirecall_pushCalls==3,@"disabled group forwards recall once");
        [timantirecall_settings() timantirecall_setChat:groupChat enabled:YES error:&error];
    });
    timantirecall_step(^{
        timantirecall_count(row,1,@"global on restores retained mark without another recall");
        UILabel *label=(UILabel *)timantirecall_indicators(row).firstObject.subviews.firstObject;
        timantirecall_check([label.text isEqual:@"已撤回"],@"time off preserves exact 0.80 default label");
        [row prepareForReuse];[row removeFromSuperview];[session close:nil];
        [timantirecall_coverage addObjectsFromArray:@[@"chat-forwarding",@"captured-time",@"persist-ui"]];
    });
}
static void timantirecall_testPreferencesPanel(void) {
    __block UIViewController *previous;
    QQSettingsViewController *host=[QQSettingsViewController new];
    UIBarButtonItem *original=[[UIBarButtonItem alloc] initWithTitle:@"原按钮" style:UIBarButtonItemStylePlain target:nil action:NULL];
    host.navigationItem.rightBarButtonItem=original;
    __block UINavigationController *presented;
    __block TIMAntiRecallPreferencesController *panel;
    timantirecall_step(^{
        timantirecall_check(timantirecall_installPreferences() && timantirecall_installPreferences(),@"three settings hooks install idempotently");
        previous=timantirecall_window.rootViewController;
        timantirecall_window.rootViewController=[[UINavigationController alloc] initWithRootViewController:host];
        [timantirecall_window makeKeyAndVisible];[host.view layoutIfNeeded];
    });
    timantirecall_step(^{
        NSUInteger before=host.timantirecall_appearCalls;
        [host viewDidAppear:YES];[host viewDidAppear:NO];
        timantirecall_check(host.timantirecall_appearCalls==before+2 && !host.timantirecall_lastAnimated,@"settings BOOL parameter and original invocation preserved");
        NSArray *buttons=host.navigationItem.rightBarButtonItems;
        timantirecall_check(buttons.count==2 && [buttons containsObject:original],@"original navigation item retained and plugin entry not duplicated");
        UIBarButtonItem *entry=buttons.lastObject;
        [UIApplication.sharedApplication sendAction:entry.action to:entry.target from:entry forEvent:nil];
    });
    timantirecall_step(^{
        presented=(UINavigationController *)host.presentedViewController;
        timantirecall_check([presented isKindOfClass:UINavigationController.class],@"real settings navigation entry presents panel");
        panel=(TIMAntiRecallPreferencesController *)presented.topViewController;
        [panel loadViewIfNeeded];[panel.tableView reloadData];[panel.tableView layoutIfNeeded];
        timantirecall_check([panel isKindOfClass:TIMAntiRecallPreferencesController.class] && [panel numberOfSectionsInTableView:panel.tableView]==2,@"real production card preferences has required sections");
        UITableViewCell *cell=[panel tableView:panel.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
        UISwitch *control=(UISwitch *)cell.accessoryView;
        timantirecall_check([control isKindOfClass:UISwitch.class] && [control.accessibilityIdentifier isEqual:@"showTime"],@"real option control is wired with stable key");
        control.on=YES;[control sendActionsForControlEvents:UIControlEventValueChanged];
        timantirecall_check([timantirecall_settings() timantirecall_showTime],@"actual settings switch commits configuration");
        control.on=NO;[control sendActionsForControlEvents:UIControlEventValueChanged];
        [panel.tableView layoutIfNeeded];
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithBounds:timantirecall_window.bounds];
        UIImage *image=[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context){[timantirecall_window drawViewHierarchyInRect:timantirecall_window.bounds afterScreenUpdates:YES];}];
        timantirecall_check([UIImagePNGRepresentation(image) writeToFile:timantirecall_document(@"tim-inline-settings-preview.png") atomically:YES],@"actual UIKit settings screenshot saved");
        [panel tableView:panel.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
    });
    timantirecall_step(^{
        UIViewController *list=presented.topViewController;
        timantirecall_check([list.title isEqual:@"按聊天单独设置"],@"chat management navigation uses production controller");
        [presented popToRootViewControllerAnimated:NO];
        [panel tableView:panel.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
    });
    timantirecall_step(^{
        TIMAntiRecallPreferencesController *records=(TIMAntiRecallPreferencesController *)presented.topViewController;
        [records loadViewIfNeeded];[records.tableView layoutIfNeeded];
        NSInteger count=[records tableView:records.tableView numberOfRowsInSection:0];
        timantirecall_check([records.title isEqual:@"查看拦截时间"] && count>0,@"timestamp page actually contains saved current-owner captures");
        if(count>0){UITableViewCell *cell=[records tableView:records.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            timantirecall_check([cell.detailTextLabel.text containsString:@"消息序号"],@"timestamp record renders metadata without chat content");}
        QQAccountsManager.GetInstance.currentUid=@"other_uid";
        [records viewWillAppear:NO];
        timantirecall_check([records tableView:records.tableView numberOfRowsInSection:0]==0,@"open time list hides old account records after switch");
        QQAccountsManager.GetInstance.currentUid=@"self_uid";
        [host dismissViewControllerAnimated:NO completion:nil];
    });
    timantirecall_step(^{
        QQChatSettingViewController *private=[QQChatSettingViewController new];private.uin=@"123456";
        QQGroupSettingViewController *group=[QQGroupSettingViewController new];group.groupCode=@"7001";
        for(QQSettingsViewController *controller in @[private,group]) {
            [controller viewDidAppear:YES];
            timantirecall_check(controller.timantirecall_appearCalls==1 && controller.timantirecall_lastAnimated,
                               @"nested chat/settings hooks preserve single superclass callback and BOOL");
            timantirecall_check(controller.navigationItem.rightBarButtonItems.count==1,@"private and group details each receive one settings entry");
        }
        timantirecall_check([timantirecall_settings() timantirecall_chatForAlias:@"123456" kind:1 owner:@"self_uid"]!=nil,@"private settings QQ-number resolves only through observed UID association");
        timantirecall_check([timantirecall_settings() timantirecall_chatForAlias:@"7001" kind:2 owner:@"self_uid"]!=nil,@"group details resolve exact group identity");
        timantirecall_window.rootViewController=previous;[timantirecall_window makeKeyAndVisible];
        presented=nil;panel=nil;previous=nil;
        [timantirecall_coverage addObjectsFromArray:@[@"preferences-entry",@"preferences-controls"]];
    });
}
