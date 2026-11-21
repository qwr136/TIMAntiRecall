#pragma once
#import "TIMAntiRecallReplayPhotoFixture.h"
static void timantirecall_testPhotoContactContract(void) {
    __block OCMsgRecord *record;__block OCPicElement *pic;__block OCContact *contact;
    __block NSString *path;__block NSData *original;__block NSDictionary *snapshot;
    __block BOOL oldDiagnostics,oldReplay;__block NSUInteger sent;
    timantirecall_step(^{
        oldDiagnostics=[timantirecall_settings() timantirecall_replayDiagnostics];
        oldReplay=[timantirecall_settings() timantirecall_messageReplay];
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@NO,@"messageReplay":@YES} error:NULL];
        TIMAntiRecallReplayPhotoProbe *probe=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;
        probe.timantirecall_conversionGuild=nil;
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(7,7)];
        original=UIImagePNGRepresentation([renderer imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[UIColor.greenColor setFill];UIRectFill(CGRectMake(0,0,7,7));}]);
        path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"TIMANTIRECALL_SECRET_MEDIA_PATH.png"];
        timantirecall_check([original writeToFile:path atomically:YES],@"native contact contract fixture creates complete original image");
        pic=[OCPicElement new];pic.sourcePath=path;pic.picSubType=0;
        record=timantirecall_record(1,1511,@"photo_peer",12345);record.elements=@[timantirecall_richElement(pic,@"picElement",2)];
        contact=record.contact;snapshot=timantirecall_richReplaySnapshot(record);
        NTAIOContact *legacy=[NTAIOContact new];legacy.chatType=1;legacy.uin=@"12345";
        OCContact *roundtrip=[legacy convertToOCContact];
        BOOL oldEqual=contact.guildId==roundtrip.guildId||[contact.guildId isEqual:roundtrip.guildId];
        timantirecall_check(contact.guildId!=nil&&contact.guildId.length==0&&roundtrip.guildId==nil&&!oldEqual,@"real native contact representations reproduce the old nil versus empty rejection");
        sent=probe.timantirecall_calls;
        timantirecall_check(timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot)&&probe.timantirecall_calls==sent+1,@"ordinary C2C photo sends with bridged empty original and native nil guild");
        timantirecall_check([probe.timantirecall_contact.peerUid isEqual:@"photo_peer"]&&[probe.timantirecall_bytes isEqual:original]&&!probe.timantirecall_contact.guildId,@"native no-guild representation stays unchanged and bytes reach isolated sender");
        probe.timantirecall_completion=nil;
        for(NSNumber *kind in @[@1,@2]) {
            record.chatType=kind.intValue;record.peerUin=kind.intValue==1?12345:7001;record.peerUid=kind.intValue==1?@"photo_peer":@"7001";
            for(id from in @[NSNull.null,@""])for(id to in @[NSNull.null,@""]) {
                contact=record.contact;contact.guildId=from==NSNull.null?nil:from;
                probe.timantirecall_conversionGuild=to==NSNull.null?nil:to;
                NSUInteger before=probe.timantirecall_calls;
                timantirecall_check(timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot)&&probe.timantirecall_calls==before+1,@"ordinary C2C and group allow only the four absent-guild representations");
                probe.timantirecall_completion=nil;
            }
        }
        record.chatType=1;record.peerUin=12345;record.peerUid=@"photo_peer";
        sent=probe.timantirecall_calls;probe.timantirecall_conversionGuild=nil;
        for(id bad in @[@"TIMANTIRECALL_SECRET_GUILD",@" ",@0,@NO,NSNull.null,@[],@{}]) {
            contact=record.contact;contact.guildId=bad;
            timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"nonempty and wrong-type original guild is never normalized to absent");
            contact=record.contact;probe.timantirecall_conversionGuild=bad;
            timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"nonempty and wrong-type converted guild is never normalized to absent");
            probe.timantirecall_conversionGuild=nil;
        }
        contact=record.contact;contact.peerUid=@"TIMANTIRECALL_SECRET_MEDIA_PEER";
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"absent guild never bypasses strict peer identity");
        contact=record.contact;contact.chatType=2;
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"absent guild never bypasses strict chat type");
        record.peerUin=0;contact=record.contact;
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"missing original peer number still blocks native photo contact");
        record.peerUin=12345;record.chatType=3;contact=record.contact;
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"no-guild normalization is not applied to channel or unknown chat types");
        record.chatType=1;contact=record.contact;
        timantirecall_check(probe.timantirecall_calls==sent&&[[NSData dataWithContentsOfFile:path] isEqual:original],@"all rejected contact cases leave sender and original image unchanged");
    });
    timantirecall_step(^{
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@YES} error:NULL];
        timantirecall_replayTraceStartSession();
        record.peerUin=0;
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo diagnostics distinguish absent peer number");
        record.peerUin=12345;contact=record.contact;contact.guildId=@"TIMANTIRECALL_SECRET_GUILD";
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo diagnostics distinguish rejected nonempty guild");
        contact=record.contact;contact.peerUid=@"TIMANTIRECALL_SECRET_MEDIA_PEER";
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo diagnostics distinguish recipient roundtrip mismatch");
        contact=record.contact;
        timantirecall_check(!timantirecall_richReplaySend([NSObject new],contact,record,snapshot),@"photo diagnostics distinguish sender ABI absence without calling it");
        [@"TIMANTIRECALL_SECRET_BODY-not-an-image" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSDictionary *badFile=timantirecall_richReplaySnapshot(record);
        timantirecall_check(badFile&&!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,badFile),@"photo header failure is diagnosed without removing content validation");
        NSString *log=[NSString stringWithContentsOfURL:timantirecall_replayTraceExport() encoding:NSUTF8StringEncoding error:NULL];
        for(NSString *reason in @[@"photo-contact-uin-unavailable",@"photo-contact-guild-rejected",@"photo-contact-roundtrip-rejected",@"photo-send-api-rejected",@"photo-source-read-rejected"])
            timantirecall_check([log containsString:reason],@"photo send log reports the first precise local rejection category");
        timantirecall_check(![log containsString:@"TIMANTIRECALL_SECRET"]&&![log containsString:@"photo_peer"]&&![log containsString:path],@"photo diagnostics never contain peer guild path bytes or arbitrary errors");
        NSData *before=[NSData dataWithContentsOfURL:timantirecall_replayTraceExport()];
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@NO} error:NULL];
        record.peerUin=0;
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,badFile),@"photo rejection has the same result with diagnostics OFF");
        NSData *after=[NSData dataWithContentsOfURL:timantirecall_replayTraceExport()];
        timantirecall_check([before isEqual:after],@"photo send diagnostic OFF adds no file events");
        TIMAntiRecallReplayPhotoProbe *probe=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;
        timantirecall_check(probe.timantirecall_calls==sent,@"photo diagnostic probes cannot submit native sends");
        probe.timantirecall_conversionGuild=nil;probe.timantirecall_completion=nil;
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@(oldDiagnostics),@"messageReplay":@(oldReplay)} error:NULL];
        [timantirecall_coverage addObjectsFromArray:@[@"photo-contact-absence-contract",@"photo-send-rejection-diagnostics"]];
    });
}
