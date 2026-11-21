#pragma once
// Native TIM payload types are synthetic here; UIKit and production replay decisions are real.
static void timantirecall_testReceivedTextReplay(UIView *root) {
    __block UIViewController *chat;__block UITableViewCell *host;__block TIMAntiRecallTestBaseView *row;
    __block OCMsgRecord *record;__block OCTextElement *mention;__block UITextView *draft;
    __block CGPoint outside=CGPointMake(180,30);__block NSUInteger before;
    timantirecall_step(^{
        [QQAccountsManager GetInstance].currentUid=@"self_uid";
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:NULL];
        chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"91091" type:2];
        chat.view.frame=root.bounds;[root addSubview:chat.view];
        host=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        host.frame=CGRectMake(0,80,root.bounds.size.width,64);[chat.view addSubview:host];[host layoutIfNeeded];
        row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:host.contentView.bounds];[host.contentView addSubview:row];
        draft=[[UITextView alloc] initWithFrame:CGRectMake(0,root.bounds.size.height-70,220,40)];draft.text=@"接收消息回归草稿";[chat.view addSubview:draft];
        record=timantirecall_record(2,1451,@"91091",91091);record.senderUid=@"received_author";
        record.elements=@[timantirecall_richElement(timantirecall_richText(@"多段"),@"textElement",1),
            timantirecall_richElement(timantirecall_richText(@" "),@"textElement",1),
            timantirecall_richElement(timantirecall_richText(@"消息正文"),@"textElement",1)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        before=[QQMsgService getInstance].timantirecall_sendCalls;
    });
    timantirecall_step(^{
        QQMsgService *service=[QQMsgService getInstance];
        NSDictionary *snapshot=timantirecall_richReplaySnapshot(record);
        timantirecall_richCheckClone(record,snapshot,timantirecall_richReplayElements(snapshot),@[@"textElement",@"textElement",@"textElement"]);
        timantirecall_check(timantirecall_richDoubleTap(row,outside,140)&&service.timantirecall_sendCalls==before+1&&service.timantirecall_lastElements.count==3,@"received three-text-element body is replayed once without flattening or no-rich rejection");
        mention=timantirecall_richText(@"@原有成员");mention.atType=2;mention.atUid=7654321;mention.atNtUid=@"original_mention_target";mention.needNotify=@YES;
        record.elements=@[timantirecall_richElement(mention,@"textElement",1),
            timantirecall_richElement(timantirecall_richText(@" "),@"textElement",1),
            timantirecall_richElement(timantirecall_richText(@"保留这段正文"),@"textElement",1)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,141)&&service.timantirecall_sendCalls==before+2,@"received targeted mention and text body submit through native element sender");
        OCTextElement *sent=[service.timantirecall_lastElements.firstObject textElement];
        timantirecall_check(sent!=mention&&sent.atType==2&&sent.atUid==7654321&&[sent.atNtUid isEqual:@"original_mention_target"]&&[sent.needNotify isEqual:@YES],@"mention recipient, native type and notify metadata are retained instead of sending display text");
        sent.atNtUid=@"sender_mutated_target";
        timantirecall_check([mention.atNtUid isEqual:@"original_mention_target"]&&[draft.text isEqual:@"接收消息回归草稿"],@"mention reconstruction never changes source recipient or input draft");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,142),@"target replacement negative control captures original mention");
        mention.atNtUid=@"changed_target";
        timantirecall_testReplayCapture(row,outside,142.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside)&&service.timantirecall_sendCalls==before+2,@"changed mention target between taps cannot send stale or new recipient");
        mention.atNtUid=@"original_mention_target";
        NSArray *valid=record.elements;
        record.elements=@[timantirecall_richElement(mention,@"textElement",1)];
        timantirecall_check(timantirecall_richReplaySnapshot(record)!=nil,@"single targeted mention uses metadata-preserving rich fallback");
        mention.atUid=0;mention.atNtUid=@"";
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"mention without original recipient stays rejected");
        mention.atUid=7654321;mention.atNtUid=@"original_mention_target";mention.atRoleId=@1;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"unsupported role metadata is not admitted by new text-only fallback");
        mention.atRoleId=@YES;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"boxed boolean is not ordinary zero metadata in received fallback");
        mention.atRoleId=@0;mention.atType=0;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"plain type with nonempty mention identity stays rejected");
        mention.atType=-1;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"negative native mention type stays rejected");
        mention.atType=2;record.elements=valid;
        mention.atType=1;mention.atUid=7654321;mention.atNtUid=@"original_mention_target";
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"all-members native type stays rejected even when malformed input includes a recipient");
        mention.atUid=0;mention.atNtUid=@"";
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"all-members native type without recipient stays rejected");
        mention.atType=2;mention.atUid=7654321;mention.atNtUid=@"original_mention_target";mention.atTinyId=23;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"guild tiny identifier is not an ordinary private or group mention");mention.atTinyId=0;
        mention.atType=INT32_MAX;mention.atUid=7654321;mention.atNtUid=@"original_mention_target";
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"unknown positive atType is not treated as an ordinary native mention");
        mention.atType=2;mention.atUid=-1;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"negative atUid is rejected before replay");
        mention.atUid=7654321;mention.atTinyId=-1;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"negative atTinyId is rejected before replay");
        mention.atTinyId=0;mention.atRoleId=@NO;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"boxed false is not accepted as numeric zero metadata");mention.atRoleId=nil;
        OCTextElement *blank=timantirecall_richText(@" \n ");
        record.elements=@[timantirecall_richElement(blank,@"textElement",1)];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"single whitespace-only rich fallback retains the plain-text rejection");
        blank.content=[@"x" stringByPaddingToLength:4097 withString:@"x" startingAtIndex:0];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"single plain text rich fallback keeps the original 4096-character cap");
        blank.content=@" \n ";record.elements=@[timantirecall_richElement(blank,@"textElement",1),
            timantirecall_richElement(timantirecall_richText(@"\t"),@"textElement",1)];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"all-whitespace multi-element body is rejected");
        timantirecall_check(service.timantirecall_sendCalls==before+2,@"invalid mention and blank snapshots never invoke native sender");
        OCReplyElement *reply=timantirecall_richReply();reply.replayMsgId=0;reply.replayMsgSeq=@7000021;
        record.elements=@[timantirecall_richElement(reply,@"replyElement",7),
            timantirecall_richElement(timantirecall_richText(@"收到的整条回复正文"),@"textElement",1)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,143)&&service.timantirecall_sendCalls==before+3,@"received zero-local-id quote with native sequence replays as a whole reply");
        OCReplyElement *sentReply=[service.timantirecall_lastElements.firstObject replyElement];
        timantirecall_check(sentReply!=reply&&sentReply.replayMsgId==0&&[sentReply.replayMsgSeq isEqual:@7000021]&&[sentReply.senderUidStr isEqual:reply.senderUidStr]&&[sentReply.sourceMsgTextElems count]==3&&service.timantirecall_lastElements.count==2,@"zero quote id is preserved with original sequence author preview and reply body instead of guessed enclosing id");
        for(id bad in @[NSNull.null,@0,@(-1),@YES,@1.5,@"7000021"]) {
            reply.replayMsgSeq=bad==NSNull.null?nil:bad;
            timantirecall_check(!timantirecall_richReplaySnapshot(record),@"zero-id quote rejects absent zero negative boolean fractional or string sequence");
        }
        reply.replayMsgSeq=@7000021;reply.sourceMsgExpired=YES;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"expired quote remains rejected even with a native sequence");reply.sourceMsgExpired=NO;
        timantirecall_check(timantirecall_testReplayCapture(row,outside,144),@"zero-id quote target-change control captures first tap");
        reply.replayMsgSeq=@7000022;timantirecall_testReplayCapture(row,outside,144.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside)&&service.timantirecall_sendCalls==before+3,@"changing zero-id quote sequence between taps cancels replay");
        reply.replayMsgSeq=@7000021;record.elements=@[record.elements.firstObject];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"zero-id quote descriptor without reply body still cannot send");
        [timantirecall_coverage addObject:@"received-zero-id-quote-replay"];
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@NO} error:NULL];
        timantirecall_clearReplayRow(row);[chat.view removeFromSuperview];
        [timantirecall_coverage addObject:@"received-text-mention-replay"];
    });
}
