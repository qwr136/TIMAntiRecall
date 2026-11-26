#pragma once
#import "TIMAntiRecallReplayPhotoFixture.h"
#import "TIMAntiRecallReplayVideoFixture.h"
static void timantirecall_testPhotoReplay(UIView *root) {
    __block UIViewController *chat;__block UITableViewCell *host;__block TIMAntiRecallTestBaseView *row;
    __block OCMsgRecord *record;__block TIMAntiRecallReceivedPic *pic;__block UITextView *draft;
    CGPoint outside=CGPointMake(180,30);__block BOOL oldReplay,oldDiagnostics;__block NSUInteger before;
    timantirecall_step(^{
        oldReplay=[timantirecall_settings() timantirecall_messageReplay];oldDiagnostics=[timantirecall_settings() timantirecall_replayDiagnostics];
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES,@"replayDiagnostics":@NO} error:NULL];
        [QQAccountsManager GetInstance].currentUid=@"self_uid";
        TIMAntiRecallReplayPhotoProbe.timantirecall_shared.timantirecall_conversionGuild=nil;
        TIMAntiRecallVideoForwardProbe *probe=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
        probe.timantirecall_handlerMode=0;before=probe.timantirecall_calls;
        chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"photo_peer" type:1];chat.view.frame=root.bounds;[root addSubview:chat.view];
        host=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];host.frame=CGRectMake(0,80,root.bounds.size.width,64);[chat.view addSubview:host];[host layoutIfNeeded];
        row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:host.contentView.bounds];[host.contentView addSubview:row];
        draft=[[UITextView alloc] initWithFrame:CGRectMake(0,root.bounds.size.height-70,240,40)];draft.text=@"图片复读不改草稿";[chat.view addSubview:draft];
        record=timantirecall_record(1,1261,@"photo_peer",0);record.peerUin=12345;record.msgId=INT64_C(4294968123);
        pic=[TIMAntiRecallReceivedPic new];pic.picWidth=800;pic.picHeight=600;pic.fileSize=2048;pic.picSubType=0;
        pic.fileUuid=@"photo-resource-uuid";pic.md5HexStr=@"photo-resource-md5";pic.sourcePath=nil;
        record.elements=@[timantirecall_richElement(pic,@"picElement",2)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        TIMAntiRecallVideoForwardProbe *probe=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
        NSDictionary *snapshot=timantirecall_richReplaySnapshot(record);
        timantirecall_check([snapshot[@"mode"] isEqual:@"photo-forward"]&&timantirecall_richImmutable(snapshot)&&!timantirecall_richReplayElements(snapshot),@"photo snapshot contains only native message reference metadata, no bytes or local path");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,80)&&probe.timantirecall_calls==before+1,@"photo double tap submits one same-chat native forward without image download");
        BOOL forwardedIdMatches=[probe.timantirecall_ids.count==1&&[probe.timantirecall_ids.firstObject isEqual:@(INT64_C(4294968123))]];
        BOOL forwardedRouteMatches=probe.timantirecall_destinations.count==1&&probe.timantirecall_destinations.firstObject==probe.timantirecall_source;
        BOOL forwardedPeerMatches=probe.timantirecall_source&&[probe.timantirecall_source.peerUid isEqual:@"photo_peer"];
        NSLog(@"PHOTO_FORWARD_CHECK id=%d route=%d peer=%d",forwardedIdMatches,forwardedRouteMatches,forwardedPeerMatches);
        timantirecall_check(forwardedIdMatches,@"photo forward preserves the original 64-bit message ID");
        timantirecall_check(forwardedRouteMatches,@"photo forward uses the same current contact as source and sole destination");
        timantirecall_check(forwardedPeerMatches,@"photo forward remains in the exact current conversation");
        timantirecall_check(probe.timantirecall_attributes==nil&&probe.timantirecall_completion!=nil&&probe.timantirecall_onMain&&pic.timantirecall_cacheCalls==0&&[QQRichMediaPhotoBrowserChatImageAgent timantirecall_downloadCalls]==0,@"photo path never resolves cache, starts download, or stages local image bytes");
        timantirecall_check(record.elements.firstObject.picElement==pic&&record.msgId==INT64_C(4294968123)&&[draft.text isEqual:@"图片复读不改草稿"]&&!timantirecall_testReplayComplete(row,outside),@"forward leaves original photo model and editor unchanged and cannot resubmit");
        probe.timantirecall_completion(1,@"TIMANTIRECALL_SECRET_ERROR",@{});probe.timantirecall_completion=nil;
        timantirecall_check(probe.timantirecall_calls==before+1,@"native photo-forward error callback never downloads or retries");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,81),@"photo resource mutation control captures first tap");
        pic.fileUuid=@"changed-resource";timantirecall_testReplayCapture(row,outside,81.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside)&&probe.timantirecall_calls==before+1,@"changed photo resource between taps cancels native forward");pic.fileUuid=@"photo-resource-uuid";
        pic.isFlashPic=@YES;timantirecall_check(!timantirecall_testReplayCapture(row,outside,82),@"flash photo remains excluded");pic.isFlashPic=nil;
        pic.invalidState=@1;timantirecall_check(!timantirecall_testReplayCapture(row,outside,83),@"invalid photo remains excluded");pic.invalidState=nil;
        int64_t messageID=record.msgId;record.msgId=0;timantirecall_check(!timantirecall_testReplayCapture(row,outside,84),@"photo without a stable original message ID is refused");record.msgId=messageID;
        int64_t sequence=record.msgSeq;record.msgSeq=0;timantirecall_check(!timantirecall_testReplayCapture(row,outside,85),@"photo without a positive original message sequence is refused");record.msgSeq=sequence;
        timantirecall_check(probe.timantirecall_calls==before+1&&[QQRichMediaPhotoBrowserChatImageAgent timantirecall_downloadCalls]==0,@"rejected photo states make no forward or download call");
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@(oldReplay),@"replayDiagnostics":@(oldDiagnostics)} error:NULL];
        probe.timantirecall_handlerMode=0;timantirecall_clearReplayRow(row);[chat.view removeFromSuperview];
        [timantirecall_coverage addObjectsFromArray:@[@"rich-message-replay-photo",@"photo-native-reference-no-download"]];
    });
}
