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
static void timantirecall_waitSettingsCapture(unsigned attempt) {
    if(timantirecall_finished)return;
    NSData *data=[NSData dataWithContentsOfFile:timantirecall_document(@"tim-inline-settings-captured.json")];
    NSDictionary *ack=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
    if([ack[@"runToken"] isEqual:timantirecall_build[@"runToken"]]) {
        [timantirecall_coverage addObject:@"preferences-visible"];
        timantirecall_holdSteps=NO;timantirecall_nextStep();return;
    }
    if(attempt>=200){timantirecall_check(NO,@"no compositor settings screenshot acknowledgement");timantirecall_finish();return;}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_MSEC*100),dispatch_get_main_queue(),^{timantirecall_waitSettingsCapture(attempt+1);});
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
        timantirecall_stepDelay=0.5;
    });
    timantirecall_step(^{
        [host beginAppearanceTransition:NO animated:NO];[host endAppearanceTransition];
        NSUInteger before=host.timantirecall_appearCalls;
        [host beginAppearanceTransition:YES animated:YES];[host endAppearanceTransition];
        [host beginAppearanceTransition:NO animated:NO];[host endAppearanceTransition];
        [host beginAppearanceTransition:YES animated:NO];[host endAppearanceTransition];
        timantirecall_check(host.timantirecall_appearCalls==before+2 && !host.timantirecall_lastAnimated,@"settings BOOL parameter and original invocation preserved");
        NSArray *buttons=host.navigationItem.rightBarButtonItems;
        timantirecall_check(buttons.count==2 && [buttons containsObject:original],@"original navigation item retained and plugin entry not duplicated");
        UIBarButtonItem *entry=buttons.lastObject;
        NSDictionary *normal=[entry titleTextAttributesForState:UIControlStateNormal];
        NSDictionary *highlighted=[entry titleTextAttributesForState:UIControlStateHighlighted];
        timantirecall_check([entry.accessibilityIdentifier isEqual:@"TIMAntiRecall.preferencesEntry"] &&
            [entry.tintColor isEqual:UIColor.blackColor] &&
            [normal[NSForegroundColorAttributeName] isEqual:UIColor.blackColor] &&
            [highlighted[NSForegroundColorAttributeName] isEqual:UIColor.blackColor],
            @"TIM settings entry text is black on light navigation bar");        [UIApplication.sharedApplication sendAction:entry.action to:entry.target from:entry forEvent:nil];
        timantirecall_stepDelay=0.6;
    });
    timantirecall_step(^{
        presented=(UINavigationController *)host.presentedViewController;
        timantirecall_check([presented isKindOfClass:UINavigationController.class],@"real settings navigation entry presents panel");
        panel=(TIMAntiRecallPreferencesController *)presented.topViewController;
        [panel loadViewIfNeeded];[panel.tableView reloadData];[panel.tableView layoutIfNeeded];
        timantirecall_check([panel isKindOfClass:TIMAntiRecallPreferencesController.class] && [panel numberOfSectionsInTableView:panel.tableView]==2,@"real production card preferences has required sections");
        timantirecall_check(panel.view.window==timantirecall_window && !panel.view.hidden && panel.tableView.visibleCells.count>=3,
                           @"settings panel and actual table cells are visible in active window");
        UITableViewCell *cell=[panel.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
        UISwitch *control=(UISwitch *)cell.accessoryView;
        timantirecall_check(control.window==timantirecall_window,@"actual on-screen switch is used, not a detached datasource cell");
        timantirecall_check([control isKindOfClass:UISwitch.class] && [control.accessibilityIdentifier isEqual:@"showTime"],@"real option control is wired with stable key");
        control.on=YES;[control sendActionsForControlEvents:UIControlEventValueChanged];
        timantirecall_check([timantirecall_settings() timantirecall_showTime],@"actual settings switch commits configuration");
        control.on=NO;[control sendActionsForControlEvents:UIControlEventValueChanged];
        timantirecall_stepDelay=0.4;
    });
    timantirecall_step(^{
        [panel.tableView layoutIfNeeded];
        timantirecall_check(panel.view.window==timantirecall_window,@"panel remains visible for compositor capture");
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithBounds:timantirecall_window.bounds];
        UIImage *image=[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context){[timantirecall_window drawViewHierarchyInRect:timantirecall_window.bounds afterScreenUpdates:YES];}];
        timantirecall_check([UIImagePNGRepresentation(image) writeToFile:timantirecall_document(@"tim-inline-settings-preview.png") atomically:YES],@"actual UIKit settings screenshot saved");
        timantirecall_holdSteps=YES;timantirecall_stage(@"settings-ready");
        timantirecall_waitSettingsCapture(0);
    });
    timantirecall_step(^{
        timantirecall_check([panel tableView:panel.tableView numberOfRowsInSection:1]==1,
                           @"global chat section only contains chat management");
        TIMAntiRecallPreferencesController *chatPanel=[[TIMAntiRecallPreferencesController alloc]
            initWithOwner:@"self_uid" chat:@{@"owner":@"self_uid",@"kind":@2,@"group":@7001}];
        timantirecall_check([chatPanel tableView:panel.tableView numberOfRowsInSection:1]==2,
                           @"chat-specific panel only adds the current chat switch");
        [panel tableView:panel.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
        timantirecall_stepDelay=0.3;
    });
    timantirecall_step(^{
        timantirecall_check([presented.topViewController.title isEqual:@"按聊天单独设置"],
                           @"chat management still opens from the real panel");
        [host dismissViewControllerAnimated:NO completion:nil];timantirecall_stepDelay=0.5;
    });
    timantirecall_step(^{
        QQChatSettingViewController *private=[QQChatSettingViewController new];private.uin=@"123456";
        QQGroupSettingViewController *group=[QQGroupSettingViewController new];group.groupCode=@"7001";
        for(QQSettingsViewController *controller in @[private,group]) {
            [controller beginAppearanceTransition:YES animated:YES];[controller endAppearanceTransition];
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
