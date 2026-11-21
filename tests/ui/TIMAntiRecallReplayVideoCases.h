#pragma once
#import "TIMAntiRecallReplayVideoFixture.h"
static void timantirecall_testVideoReplay(UIView *root) {
    __block UIViewController *chat;__block UITableViewCell *host;__block TIMAntiRecallTestBaseView *row;
    __block OCMsgRecord *record;__block OCVideoElement *video;__block UITextView *draft;
    __block BOOL oldReplay,oldDiagnostics;__block NSUInteger before;CGPoint outside=CGPointMake(180,30);
    timantirecall_step(^{
        oldReplay=[timantirecall_settings() timantirecall_messageReplay];oldDiagnostics=[timantirecall_settings() timantirecall_replayDiagnostics];
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES,@"replayDiagnostics":@NO} error:NULL];
        [QQAccountsManager GetInstance].currentUid=@"self_uid";
        TIMAntiRecallReplayPhotoProbe.timantirecall_shared.timantirecall_conversionGuild=nil;
        TIMAntiRecallVideoForwardProbe *probe=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
        timantirecall_check(probe&&[probe isKindOfClass:objc_getClass("_TtC10MsgManager16MsgSenderHandler")],@"video fixture registers the exact native handler name through a test-only class");
        probe.timantirecall_handlerMode=0;before=probe.timantirecall_calls;
        chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"photo_peer" type:1];chat.view.frame=root.bounds;[root addSubview:chat.view];
        host=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];host.frame=CGRectMake(0,80,root.bounds.size.width,64);[chat.view addSubview:host];[host layoutIfNeeded];
        row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:host.contentView.bounds];[host.contentView addSubview:row];
        draft=[[UITextView alloc] initWithFrame:CGRectMake(0,root.bounds.size.height-70,240,40)];draft.text=@"视频复读不改草稿";[chat.view addSubview:draft];
        record=timantirecall_record(1,1551,@"photo_peer",12345);record.msgId=INT64_C(4294967851);
        video=[OCVideoElement new];video.videoMd5=@"TIMANTIRECALL_SECRET_VIDEO_MD5";video.fileUuid=@"TIMANTIRECALL_SECRET_VIDEO_UUID";video.fileSize=2048;video.fileTime=4;
        record.elements=@[timantirecall_richElement(video,@"videoElement",5)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        TIMAntiRecallVideoForwardProbe *probe=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
        NSDictionary *plan=timantirecall_richReplaySnapshot(record);
        timantirecall_check([plan[@"mode"] isEqual:@"video"]&&timantirecall_richImmutable(plan)&&timantirecall_richReplayElements(plan)==nil,@"single video forms an immutable native-reference plan, never cloned video elements");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,150)&&probe.timantirecall_calls==before+1,@"video actual two-tap path submits native forward exactly once");
        timantirecall_check([probe.timantirecall_ids isEqual:@[@(INT64_C(4294967851))]]&&probe.timantirecall_destinations.count==1&&probe.timantirecall_destinations.firstObject==probe.timantirecall_source&&[probe.timantirecall_source.peerUid isEqual:@"photo_peer"]&&probe.timantirecall_source.chatType==1,@"video forwards one 64-bit original id to the same sole current conversation");
        timantirecall_check(probe.timantirecall_attributes==nil&&probe.timantirecall_completion!=nil&&probe.timantirecall_onMain,@"native video submission uses nil outgoing attributes and a nonnil three-argument completion on main");
        timantirecall_check(record.elements.firstObject.videoElement==video&&record.msgId==INT64_C(4294967851)&&[draft.text isEqual:@"视频复读不改草稿"]&&!timantirecall_testReplayComplete(row,outside),@"video reference and editor remain unchanged and the completed gesture cannot resubmit");
        probe.timantirecall_completion(1,@"TIMANTIRECALL_SECRET_NATIVE_ERROR",@{@"TIMANTIRECALL_SECRET_RESULT":@1});probe.timantirecall_completion=nil;
        timantirecall_check(probe.timantirecall_calls==before+1,@"native video error callback never retries or performs a second fallback send");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,151),@"video resource change control captures the original plan");
        video.fileUuid=@"changed-resource";timantirecall_testReplayCapture(row,outside,151.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside)&&probe.timantirecall_calls==before+1,@"video native resource changing between taps cancels submission");video.fileUuid=@"TIMANTIRECALL_SECRET_VIDEO_UUID";
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,152),@"video current chat control captures first tap");
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"another_peer" controller:chat type:1];timantirecall_testReplayCapture(row,outside,152.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside)&&probe.timantirecall_calls==before+1,@"video cannot be forwarded after switching the current conversation");
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"photo_peer" controller:chat type:1];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,153),@"video OFF control captures first tap");
        NSUInteger getters=probe.timantirecall_getterCalls;
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@NO} error:NULL];
        timantirecall_check(!timantirecall_testReplayCapture(row,outside,153.1)&&!timantirecall_testReplayComplete(row,outside)&&probe.timantirecall_getterCalls==getters&&probe.timantirecall_calls==before+1,@"video switch OFF cancels pending gesture without obtaining a native sender");
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:NULL];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        TIMAntiRecallVideoForwardProbe *probe=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
        NSDictionary *plan=timantirecall_richReplaySnapshot(record);NSUInteger sent=probe.timantirecall_calls;
        for(NSNumber *mode in @[@1,@2,@3]) {
            probe.timantirecall_handlerMode=mode.integerValue;
            timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],record.contact,record,plan)&&probe.timantirecall_calls==sent,@"video missing wrong-class or wrong-signature handler cannot be invoked");
        }
        probe.timantirecall_handlerMode=0;
        OCMsgElement *element=record.elements.firstObject;
        element.elementType=3;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"video payload with a face type fails closed");element.elementType=5;
        element.textElement=timantirecall_richText(@"mixed-video");
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"video with a second payload on the same element fails closed");element.textElement=nil;
        record.elements=@[element,timantirecall_richElement(timantirecall_richText(@"mixed-body"),@"textElement",1)];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"mixed video body does not forward the whole unrelated record");record.elements=@[element];
        video.invalidState=@1;timantirecall_check(!timantirecall_richReplaySnapshot(record),@"invalid video remains ineligible for native forwarding");video.invalidState=nil;
        video.videoMd5=@"";video.fileUuid=@"";
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"video without any native resource identifier is not guessed");
        video.videoMd5=@"TIMANTIRECALL_SECRET_VIDEO_MD5";video.fileUuid=@"TIMANTIRECALL_SECRET_VIDEO_UUID";
        video.fileSize=0;timantirecall_check(!timantirecall_richReplaySnapshot(record),@"zero-sized video reference is refused");video.fileSize=2048;
        video.fileTime=-1;timantirecall_check(!timantirecall_richReplaySnapshot(record),@"negative native video duration is refused");video.fileTime=4;
        int64_t identifier=record.msgId;record.msgId=0;
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"video without a local original message id is not fabricated");record.msgId=identifier;
        record.msgSeq=0;timantirecall_check(!timantirecall_richReplaySnapshot(record),@"video without a stable sequence is not submitted");record.msgSeq=1551;
        timantirecall_check(probe.timantirecall_calls==sent,@"all malformed video snapshots leave native forward count unchanged");
        record.chatType=2;record.peerUid=@"7001";record.peerUin=7001;
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"7001" controller:chat type:2];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,154)&&probe.timantirecall_calls==sent+1&&probe.timantirecall_source.chatType==2&&[probe.timantirecall_source.peerUid isEqual:@"7001"],@"group video uses the same verified group as source and sole destination");
        probe.timantirecall_completion=nil;
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@YES} error:NULL];timantirecall_replayTraceStartSession();
        timantirecall_check(timantirecall_richDoubleTap(row,outside,155),@"video diagnostic success probe submits once");
        probe.timantirecall_completion(0,@"TIMANTIRECALL_SECRET_NATIVE_MESSAGE",@{@"TIMANTIRECALL_SECRET_RESULT":@1});probe.timantirecall_completion=nil;
        NSString *log=[NSString stringWithContentsOfURL:timantirecall_replayTraceExport() encoding:NSUTF8StringEncoding error:NULL];
        timantirecall_check([log containsString:@"video-native-completed"]&&![log containsString:@"TIMANTIRECALL_SECRET"]&&![log containsString:@"4294967851"],@"native video callback reports a fixed result only and leaks no id resource or error description");
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@(oldReplay),@"replayDiagnostics":@(oldDiagnostics)} error:NULL];
        probe.timantirecall_handlerMode=0;timantirecall_clearReplayRow(row);[chat.view removeFromSuperview];
        [timantirecall_coverage addObjectsFromArray:@[@"video-native-forward-replay",@"video-native-forward-guards"]];
    });
}
