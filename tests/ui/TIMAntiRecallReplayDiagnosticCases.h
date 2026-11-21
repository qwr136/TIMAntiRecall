#pragma once
#import "TIMAntiRecallReplayTrace.h"
#import <objc/runtime.h>
static int64_t timantirecall_diagWrongElementType(id object,SEL selector) {(void)object;(void)selector;return 3;}
static void timantirecall_testRichDiagnostics(UIView *root) {
    __block BOOL previousDiagnostics,previousReplay;
    __block UIViewController *chat;__block TIMAntiRecallTestBaseView *row;
    timantirecall_step(^{
        previousDiagnostics=[timantirecall_settings() timantirecall_replayDiagnostics];
        previousReplay=[timantirecall_settings() timantirecall_messageReplay];
        timantirecall_check([timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@YES,@"messageReplay":@YES} error:NULL],@"rich diagnostic fixture enables only existing switches");
        timantirecall_replayTraceStartSession();
        Class bad=objc_getClass("TIMAntiRecallWrongElementABI");
        if(!bad) {
            bad=objc_allocateClassPair(OCMsgElement.class,"TIMAntiRecallWrongElementABI",0);
            timantirecall_check(bad&&class_addMethod(bad,@selector(elementType),(IMP)timantirecall_diagWrongElementType,"q16@0:8"),@"diagnostic fixture creates an intentionally mismatched getter without touching native classes");
            if(bad)objc_registerClassPair(bad);
        }
        OCMsgRecord *record=timantirecall_record(1,1301,@"diag_peer",0);
        record.elements=@[[[bad alloc] init]];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"getter ABI mismatch stays rejected under diagnostics");
        OCTextElement *text=timantirecall_richText(@"TIMANTIRECALL_SECRET_BODY");text.atNtUid=@0;
        record.elements=@[timantirecall_richElement(timantirecall_richFace(),@"faceElement",3),timantirecall_richElement(text,@"textElement",1)];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"wrong runtime metadata class stays rejected under diagnostics");
        OCPicElement *pic=[OCPicElement new];pic.sourcePath=@"TIMANTIRECALL_SECRET_PATH/image.png";
        record.elements=@[timantirecall_richElement(pic,@"picElement",2)];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"unavailable photo remains rejected without exposing source path");
        record.elements=@[timantirecall_richElement(timantirecall_richFace(),@"faceElement",68417)];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"unknown raw element enum remains rejected and must log only other");
        chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"diag_peer" type:1];chat.view.frame=root.bounds;[root addSubview:chat.view];
        UITableViewCell *host=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        host.frame=CGRectMake(0,80,root.bounds.size.width,64);[chat.view addSubview:host];[host layoutIfNeeded];
        row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:host.contentView.bounds];[host.contentView addSubview:row];
        record=timantirecall_record(1,1302,@"diag_peer",0);record.msgId=0;record.peerUin=78901;
        record.elements=@[timantirecall_richElement(timantirecall_richFace(),@"faceElement",3)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        NSUInteger before=[QQMsgService getInstance].timantirecall_sendCalls;
        timantirecall_check(!timantirecall_testReplayCapture(row,CGPointMake(180,30),100),@"valid rich snapshot with invalid identity remains rejected before send");
        timantirecall_check([QQMsgService getInstance].timantirecall_sendCalls==before,@"diagnostic observation never submits a message");
    });
    timantirecall_step(^{
        NSURL *url=timantirecall_replayTraceExport();NSData *bytes=[NSData dataWithContentsOfURL:url];
        NSString *log=[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        BOOL abi=NO,shape=NO,photo=NO,identity=NO,ready=NO,other=NO,noRawEnum=YES;
        for(NSString *line in [log componentsSeparatedByString:@"\n"]) {
            if(!line.length)continue;
            NSDictionary *event=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
            if([event[@"reason"] isEqual:@"getter-abi-mismatch"]&&[event[@"field"] isEqual:@"elementType"])
                abi=[event[@"expectedABI"] isEqual:@"int32"]&&[event[@"actualABI"] isEqual:@"int64"];
            if([event[@"reason"] isEqual:@"field-value-rejected"]&&[event[@"field"] isEqual:@"atNtUid"])
                shape=[event[@"valueKind"] isEqual:@"number-zero"]&&[event[@"shape"] isEqual:@"NSString"];
            if([event[@"reason"] isEqual:@"photo-path-shape"])photo=YES;
            if([event[@"reason"] isEqual:@"message-identity-rejected"])identity=YES;
            if([event[@"reason"] isEqual:@"snapshot-ready"])ready=YES;
            if([event[@"reason"] isEqual:@"element-entered"]&&[event[@"shape"] isEqual:@"other"])other=YES;
            if(event[@"elementType"])noRawEnum=NO;
            for(id value in event.allValues)if([value isKindOfClass:NSNumber.class]&&[value isEqual:@68417])noRawEnum=NO;
        }
        timantirecall_check(other&&noRawEnum,@"unknown element type is reduced to other without persisting raw enum");
        timantirecall_check(abi&&shape&&photo&&identity&&ready,@"rich diagnostic exported events distinguish exact ABI, field shape, photo gate, successful snapshot and failed identity");
        timantirecall_check([log containsString:@"replay-rich-reject-v2"]&&![log containsString:@"TIMANTIRECALL_SECRET_BODY"]&&![log containsString:@"TIMANTIRECALL_SECRET_PATH"]&&![log containsString:@"diag_peer"],@"rich diagnostics have new schema and never serialize content, paths or peer IDs");
        timantirecall_clearReplayRow(row);[chat.view removeFromSuperview];
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@NO} error:NULL];
        OCMsgRecord *record=timantirecall_record(1,1303,@"diag_peer",0);record.elements=@[[OCMsgElement new]];
        timantirecall_check(!timantirecall_richReplaySnapshot(record),@"diagnostics disabled leaves the same eligibility result");
        NSData *after=[NSData dataWithContentsOfURL:timantirecall_replayTraceExport()];
        timantirecall_check([bytes isEqual:after],@"diagnostics disabled adds no rejection events or sensitive data");
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@(previousDiagnostics),@"messageReplay":@(previousReplay)} error:NULL];
        [timantirecall_coverage addObject:@"rich-rejection-diagnostics"];
    });
}
