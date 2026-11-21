#pragma once
#import "TIMAntiRecallReplayPhotoFixture.h"
static void timantirecall_testPhotoReplay(UIView *root) {
    __block UIViewController *chat;__block UIScrollView *scroll;__block UITableViewCell *host;
    __block TIMAntiRecallTestBaseView *row;__block OCMsgRecord *record;__block OCPicElement *pic;
    __block NSString *path;__block NSData *original;CGPoint outside=CGPointMake(180,30);
    timantirecall_step(^{
        [QQAccountsManager GetInstance].currentUid=@"self_uid";
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:NULL];
        TIMAntiRecallReplayPhotoProbe.timantirecall_shared.timantirecall_calls=0;
        chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"peer_a" type:1];
        chat.view.frame=root.bounds;[root addSubview:chat.view];
        scroll=[[UIScrollView alloc] initWithFrame:chat.view.bounds];scroll.contentSize=CGSizeMake(root.bounds.size.width,root.bounds.size.height*2);[chat.view addSubview:scroll];
        host=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];host.frame=CGRectMake(0,80,root.bounds.size.width,64);[scroll addSubview:host];[host layoutIfNeeded];
        row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:host.contentView.bounds];[host.contentView addSubview:row];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(8,8),YES,1);[UIColor.blueColor setFill];UIRectFill(CGRectMake(0,0,8,8));
        original=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();
        path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"timantirecall-original-photo.png"];
        timantirecall_check([original writeToFile:path atomically:YES],@"local image fixture writes complete PNG");
        record=timantirecall_record(1,1261,@"peer_a",0);record.peerUin=12345;
        pic=[OCPicElement new];pic.sourcePath=path;pic.picWidth=8;pic.picHeight=8;pic.fileSize=original.length;pic.picSubType=0;
        record.elements=@[timantirecall_richElement(pic,@"picElement",2)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        NSDictionary *snapshot=timantirecall_richReplaySnapshot(record);
        timantirecall_check(snapshot&&timantirecall_richImmutable(snapshot)&&!timantirecall_richReplayElements(snapshot),@"photo is immutable plan for native upload, never a copied received pic element");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,80),@"downloaded local photo double tap invokes native image producer");
        TIMAntiRecallReplayPhotoProbe *probe=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;
        timantirecall_check(probe.timantirecall_calls==1&&[probe.timantirecall_bytes isEqual:original]&&![probe.timantirecall_path isEqual:path]&&probe.timantirecall_additional==nil&&probe.timantirecall_completion!=nil,@"native photo route reads isolated full bytes once, no appended text");
        timantirecall_check([probe.timantirecall_contact.peerUid isEqual:@"peer_a"]&&probe.timantirecall_contact.chatType==1,@"photo contact roundtrip resolves the current C2C UID");
        timantirecall_check([[NSData dataWithContentsOfFile:path] isEqual:original]&&[pic.sourcePath isEqual:path]&&record.elements.firstObject.elementId==456789,@"image replay never changes or deletes the received record or original file");
        timantirecall_check(![NSFileManager.defaultManager fileExistsAtPath:probe.timantirecall_path]&&!timantirecall_testReplayComplete(row,outside),@"temporary photo is removed after synchronous native read and gesture cannot resubmit");
        probe.timantirecall_completion(0,@"fixture success");probe.timantirecall_completion=nil;
        timantirecall_check(probe.timantirecall_calls==1,@"asynchronous photo completion does not resubmit or delete source");
    });
    timantirecall_step(^{
        TIMAntiRecallReplayPhotoProbe *probe=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;NSUInteger before=probe.timantirecall_calls;
        pic.isFlashPic=@YES;timantirecall_check(!timantirecall_testReplayCapture(row,outside,81),@"flash photo never replays");pic.isFlashPic=nil;
        pic.invalidState=@1;timantirecall_check(!timantirecall_testReplayCapture(row,outside,82),@"invalid photo never replays");pic.invalidState=nil;
        record.peerUin=333;timantirecall_check(!timantirecall_richDoubleTap(row,outside,83)&&probe.timantirecall_calls==before,@"photo contact conversion to another peer prevents submission");record.peerUin=12345;
        timantirecall_check(timantirecall_testReplayCapture(row,outside,84),@"photo first tap has complete file");
        [[@"changed image bytes" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
        timantirecall_check(!timantirecall_testReplayCapture(row,outside,84.1)&&!timantirecall_testReplayComplete(row,outside)&&probe.timantirecall_calls==before,@"replaced photo file between taps is rejected");
        [original writeToFile:path atomically:YES];pic.sourcePath=@"https://example.invalid/image.png";
        timantirecall_check(!timantirecall_testReplayCapture(row,outside,85),@"remote photo path does not cause an implicit download");pic.sourcePath=path;
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        timantirecall_check(!timantirecall_testReplayCapture(row,outside,86),@"missing local original never degrades to thumbnail or text");
        timantirecall_check(probe.timantirecall_calls==before,@"photo negative paths make no native calls");
        [original writeToFile:path atomically:YES];record.chatType=2;record.peerUin=7001;record.peerUid=@"7001";
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"7001" controller:chat type:2];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,87)&&probe.timantirecall_calls==before+1&&probe.timantirecall_contact.chatType==2&&[probe.timantirecall_contact.peerUid isEqual:@"7001"],@"group photo producer uses exact groupCode roundtrip");
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];probe.timantirecall_completion=nil;
        [timantirecall_coverage addObject:@"rich-message-replay-photo"];
        timantirecall_clearReplayRow(row);[chat.view removeFromSuperview];
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@NO} error:NULL];
    });
}
