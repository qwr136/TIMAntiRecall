#import "TIMAntiRecallReplay.h"

static void timantirecall_testMessageReplay(UIView *root) {
    timantirecall_step(^{
        timantirecall_check(![timantirecall_settings() timantirecall_messageReplay],@"message replay starts disabled");
        timantirecall_check(timantirecall_installMessageReplay()&&timantirecall_installMessageReplay(),@"native double tap hook installs idempotently");
        [NTAIOContentDoubleTapService setTimantirecall_originalCalls:0];
    });
    __block QQChatViewController *chat;
    __block TIMAntiRecallTestBaseView *cell;
    __block OCMsgRecord *record;
    __block OCMsgElement *element;
    __block OCTextElement *text;
    timantirecall_step(^{
        chat=[QQChatViewController new];chat.view.frame=root.bounds;[root addSubview:chat.view];
        cell=[[TIMAntiRecallTestBaseView alloc] initWithFrame:CGRectMake(8,80,root.bounds.size.width-16,80)];[chat.view addSubview:cell];
        text=[OCTextElement new];text.content=@"复读原文";text.atType=0;text.atUid=0;text.atTinyId=0;
        element=[OCMsgElement new];element.textElement=text;
        record=[OCMsgRecord new];record.elements=@[element];
        [NTAIOContentDoubleTapService doubleTapGestureActionWithGesture:NSObject.new record:record viewController:chat tappedCellView:cell];
        timantirecall_check(chat.timantirecall_sendCalls==0&&[NTAIOContentDoubleTapService timantirecall_originalCalls]==1,@"disabled replay preserves original TIM reader");
        NSError *error=nil;timantirecall_check([timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:&error],@"replay setting can be enabled");
        timantirecall_check([timantirecall_settings() timantirecall_messageReplay],@"replay setting becomes active");
    });
    timantirecall_step(^{
        [NTAIOContentDoubleTapService doubleTapGestureActionWithGesture:NSObject.new record:record viewController:chat tappedCellView:cell];
        timantirecall_check(chat.timantirecall_sendCalls==1&&[chat.timantirecall_lastText isEqual:@"复读原文"]&&
            [chat.timantirecall_lastShowText isEqual:@"复读原文"],@"pure text sends once through active TIM chat controller");
        text.atType=1;NSUInteger sent=chat.timantirecall_sendCalls;
        [NTAIOContentDoubleTapService doubleTapGestureActionWithGesture:NSObject.new record:record viewController:chat tappedCellView:cell];
        timantirecall_check(chat.timantirecall_sendCalls==sent&&[NTAIOContentDoubleTapService timantirecall_originalCalls]==2,@"mention message never sends and native handler is preserved");
        text.atType=0;element.faceElement=NSObject.new;sent=chat.timantirecall_sendCalls;
        [NTAIOContentDoubleTapService doubleTapGestureActionWithGesture:NSObject.new record:record viewController:chat tappedCellView:cell];
        timantirecall_check(chat.timantirecall_sendCalls==sent&&[NTAIOContentDoubleTapService timantirecall_originalCalls]==3,@"mixed rich message never sends");
        element.faceElement=nil;chat.view.hidden=YES;sent=chat.timantirecall_sendCalls;
        [NTAIOContentDoubleTapService doubleTapGestureActionWithGesture:NSObject.new record:record viewController:chat tappedCellView:cell];
        timantirecall_check(chat.timantirecall_sendCalls==sent&&[NTAIOContentDoubleTapService timantirecall_originalCalls]==4,@"inactive chat context falls back to native action");
        NSError *error=nil;[timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@NO} error:&error];
        [chat.view removeFromSuperview];chat=nil;cell=nil;record=nil;element=nil;text=nil;
        [timantirecall_coverage addObject:@"message-replay"];
    });
}
