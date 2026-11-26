#pragma once
#import "TIMAntiRecallReplayPhotoFixture.h"
#import "TIMAntiRecallReplayVideoFixture.h"
static void timantirecall_testPhotoContactContract(void) {
    __block OCMsgRecord *record;__block OCPicElement *pic;__block OCContact *contact;__block NSDictionary *snapshot;
    __block BOOL oldDiagnostics,oldReplay;__block NSUInteger sent;
    timantirecall_step(^{
        oldDiagnostics=[timantirecall_settings() timantirecall_replayDiagnostics];oldReplay=[timantirecall_settings() timantirecall_messageReplay];
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@NO,@"messageReplay":@YES} error:NULL];
        TIMAntiRecallReplayPhotoProbe *conversion=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;conversion.timantirecall_conversionGuild=nil;
        TIMAntiRecallVideoForwardProbe *forward=TIMAntiRecallVideoForwardProbe.timantirecall_shared;forward.timantirecall_handlerMode=0;
        pic=[OCPicElement new];pic.picSubType=0;pic.fileSize=2048;pic.fileUuid=@"contact-photo-resource";pic.md5HexStr=@"contact-photo-md5";
        record=timantirecall_record(1,1511,@"photo_peer",12345);record.msgId=INT64_C(4294968123);record.elements=@[timantirecall_richElement(pic,@"picElement",2)];
        contact=record.contact;snapshot=timantirecall_richReplaySnapshot(record);
        NTAIOContact *legacy=[NTAIOContact new];legacy.chatType=1;legacy.uin=@"12345";OCContact *roundtrip=[legacy convertToOCContact];
        BOOL oldEqual=contact.guildId==roundtrip.guildId||[contact.guildId isEqual:roundtrip.guildId];
        timantirecall_check(contact.guildId!=nil&&contact.guildId.length==0&&roundtrip.guildId==nil&&!oldEqual,@"native contact reproduces bridged empty versus converter nil guild");
        sent=forward.timantirecall_calls;
        timantirecall_check(timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot)&&forward.timantirecall_calls==sent+1,@"photo native forward accepts exact ordinary C2C contact without local image bytes");
        BOOL sourceGuildAbsent=!forward.timantirecall_source.guildId||([forward.timantirecall_source.guildId isKindOfClass:NSString.class]&&forward.timantirecall_source.guildId.length==0);
        timantirecall_check([forward.timantirecall_ids isEqual:@[@(INT64_C(4294968123))]]&&forward.timantirecall_destinations.firstObject==forward.timantirecall_source&&[forward.timantirecall_source.peerUid isEqual:@"photo_peer"]&&sourceGuildAbsent,@"photo forward retains 64-bit source message ID and exact same-chat route");
        forward.timantirecall_completion=nil;
        for(NSNumber *kind in @[@1,@2]) {
            record.chatType=kind.intValue;record.peerUin=kind.intValue==1?12345:7001;record.peerUid=kind.intValue==1?@"photo_peer":@"7001";snapshot=timantirecall_richReplaySnapshot(record);
            for(id from in @[NSNull.null,@""])for(id to in @[NSNull.null,@""]) {
                contact=record.contact;contact.guildId=from==NSNull.null?nil:from;conversion.timantirecall_conversionGuild=to==NSNull.null?nil:to;
                NSUInteger before=forward.timantirecall_calls;
                timantirecall_check(timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot)&&forward.timantirecall_calls==before+1,@"C2C/group permit only the four nil-or-empty guild representations");forward.timantirecall_completion=nil;
            }
        }
        record.chatType=1;record.peerUin=12345;record.peerUid=@"photo_peer";snapshot=timantirecall_richReplaySnapshot(record);sent=forward.timantirecall_calls;conversion.timantirecall_conversionGuild=nil;
        for(id bad in @[@"TIMANTIRECALL_SECRET_GUILD",@" ",@0,@NO,NSNull.null,@[],@{}]) {
            contact=record.contact;contact.guildId=bad;timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"nonempty or wrong-type source guild is rejected");
            contact=record.contact;conversion.timantirecall_conversionGuild=bad;timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"nonempty or wrong-type converted guild is rejected");conversion.timantirecall_conversionGuild=nil;
        }
        contact=record.contact;contact.peerUid=@"TIMANTIRECALL_SECRET_MEDIA_PEER";timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"native forward cannot change the peer identity");
        contact=record.contact;contact.chatType=2;timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"native forward cannot change the chat type");
        record.peerUin=0;contact=record.contact;timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"missing original peer number rejects the native forward");
        record.peerUin=12345;record.chatType=3;contact=record.contact;snapshot=timantirecall_richReplaySnapshot(record);
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"channel and unknown chats do not use absent-guild normalization");
        record.chatType=1;contact=record.contact;
        timantirecall_check(forward.timantirecall_calls==sent,@"rejected photo contacts never reach the native forwarding handler");
    });
    timantirecall_step(^{
        TIMAntiRecallReplayPhotoProbe *conversion=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;
        TIMAntiRecallVideoForwardProbe *forward=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
        NSUInteger beforeCalls=forward.timantirecall_calls;[timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@YES} error:NULL];timantirecall_replayTraceStartSession();
        record.peerUin=0;timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo diagnostics identify missing peer number");
        record.peerUin=12345;contact=record.contact;contact.guildId=@"TIMANTIRECALL_SECRET_GUILD";timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo diagnostics identify rejected guild");
        contact=record.contact;contact.peerUid=@"TIMANTIRECALL_SECRET_MEDIA_PEER";timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo diagnostics identify recipient mismatch");
        contact=record.contact;timantirecall_check(!timantirecall_richReplaySend([NSObject new],contact,record,snapshot),@"photo diagnostics identify unavailable native handler API");
        NSString *log=[NSString stringWithContentsOfURL:timantirecall_replayTraceExport() encoding:NSUTF8StringEncoding error:NULL];
        for(NSString *reason in @[@"photo-contact-uin-unavailable",@"photo-contact-guild-rejected",@"photo-contact-roundtrip-rejected",@"photo-native-handler-api-rejected"])
            timantirecall_check([log containsString:reason],@"photo diagnostics report only a fixed rejection category");
        timantirecall_check(![log containsString:@"TIMANTIRECALL_SECRET"]&&![log containsString:@"photo_peer"],@"photo diagnostics never leak peer or resource identifiers");
        NSData *logged=[NSData dataWithContentsOfURL:timantirecall_replayTraceExport()];
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@NO} error:NULL];record.peerUin=0;
        timantirecall_check(!timantirecall_richReplaySend([QQMsgService getInstance],contact,record,snapshot),@"photo rejection is identical when diagnostics are OFF");
        timantirecall_check([logged isEqual:[NSData dataWithContentsOfURL:timantirecall_replayTraceExport()]],@"diagnostics OFF writes no additional media records");
        timantirecall_check(forward.timantirecall_calls==beforeCalls&&[QQRichMediaPhotoBrowserChatImageAgent timantirecall_downloadCalls]==0,@"rejected diagnostics probes perform no send or original-image download");
        conversion.timantirecall_conversionGuild=nil;forward.timantirecall_completion=nil;
        [timantirecall_settings() timantirecall_updateOptions:@{@"replayDiagnostics":@(oldDiagnostics),@"messageReplay":@(oldReplay)} error:NULL];
        [timantirecall_coverage addObjectsFromArray:@[@"photo-contact-absence-contract",@"photo-send-rejection-diagnostics"]];
    });
}
