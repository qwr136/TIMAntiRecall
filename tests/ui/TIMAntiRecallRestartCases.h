static void timantirecall_testRestartStart(void) {
    timantirecall_failures=[NSMutableArray array];timantirecall_coverage=[NSMutableSet set];
    NSData *raw=[NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"tim-inline-build" ofType:@"json"]];
    NSDictionary *build=[NSJSONSerialization JSONObjectWithData:raw options:0 error:NULL];
    NSData *expectedRaw=[NSData dataWithContentsOfFile:timantirecall_document(@"tim-inline-restart-expected.json")];
    NSDictionary *expected=expectedRaw?[NSJSONSerialization JSONObjectWithData:expectedRaw options:0 error:NULL]:nil;
    timantirecall_check(expected!=nil,@"previous process wrote sealed restart expectation");
    timantirecall_check([build[@"runToken"] isEqual:expected[@"runToken"]],@"same source/run across process restart");
    timantirecall_check([expected[@"pid"] intValue]!=NSProcessInfo.processInfo.processIdentifier,@"restoration uses genuinely different application process");
    timantirecall_check(timantirecall_installInlineIndicator(),@"production hooks install after cold relaunch");
    timantirecall_check(timantirecall_installColdRecallProtection(),@"cold recall-time hook installs before database sync");
    OCMsgRecord *record=timantirecall_record(1,601,@"peer_a",7001);
    NSDictionary *identity=timantirecall_recordIdentity(record,@"self_uid");
    NSDictionary *event=[timantirecall_sharedMarks() timantirecall_eventForIdentity:identity];
    timantirecall_check([event[@"capturedAt"] isEqual:expected[@"capturedAt"]],@"cold process reloads first interception timestamp");
    UIView *root=timantirecall_window.rootViewController.view;
    TIMAntiRecallTestBaseView *row=timantirecall_row(root,CGRectMake(8,120,root.bounds.size.width-16,100));
    [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:record]];
    timantirecall_layout(row);timantirecall_count(row,1,@"cold relaunch renders restored red frame without any push or mark call");
    NSObject *unmarked=[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,602,@"peer_a",7001)];
    [row bindViewModel:unmarked];timantirecall_count(row,0,@"unmarked sibling remains clean after restart");
    [session init:config depends:nil dispatcherDepends:nil listener:nil];
    [record setRecallTime:1700000000];
    timantirecall_check(record.recallTime==0 && record.timantirecall_recallSetterCalls==0,
                       @"persisted exact recall identity blocks cold recall setter before any push");
    OCMsgRecord *coldOther=timantirecall_record(1,602,@"peer_a",7001);
    [coldOther setRecallTime:1700000001];
    timantirecall_check(coldOther.recallTime==1700000001 && coldOther.timantirecall_recallSetterCalls==1,
                       @"unmarked message retains original recall setter behavior");
    [record setRecallTime:0];
    timantirecall_check(record.timantirecall_recallSetterCalls==1,
                       @"zero recall-time updates and ordinary clearing are forwarded");
    [record setRecallTime:1700000000];
    timantirecall_check(record.timantirecall_recallSetterCalls==1,
                       @"marked cold recall setter stays intercepted on repeated sync");
    NSDictionary *disabled=@{@"owner":@"self_uid",@"kind":@2,@"group":@9988};
    timantirecall_check(![timantirecall_settings() timantirecall_enabledForChat:disabled],@"per-chat switch survives actual app process restart");
    timantirecall_writeJSON(@{@"status":timantirecall_failures.count?@"FAIL":@"PASS",@"checks":@(timantirecall_checks),
        @"failures":timantirecall_failures,@"runToken":build[@"runToken"]?:@"",@"sourceDigest":build[@"sourceDigest"]?:@"",
        @"oldPID":expected[@"pid"]?:@0,@"newPID":@(NSProcessInfo.processInfo.processIdentifier),
        @"restoredBeforePush":@YES},@"tim-inline-restart-result.json");
}
