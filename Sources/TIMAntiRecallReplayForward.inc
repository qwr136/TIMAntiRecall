static BOOL timantirecall_referenceForwardReject(NSString *shape,NSString *category) {
    if([timantirecall_settings() timantirecall_replayDiagnostics])
        timantirecall_replayTrace(@"send",@{@"reason":[NSString stringWithFormat:@"%@-%@",shape,category],@"shape":shape});
    return NO;
}
static BOOL timantirecall_nativeReferenceForward(id service,id contact,id record,NSNumber *messageID,NSString *shape) {
    if(!NSThread.isMainThread||!service||!contact||!record||![messageID isKindOfClass:NSNumber.class]||
       ![@[@"photo",@"video"] containsObject:shape]||[messageID longLongValue]==0||
       strcmp([messageID objCType],"q")!=0)return timantirecall_referenceForwardReject(shape?:@"media",@"native-forward-input-rejected");
    id nativeContact=timantirecall_richPhotoContact(record,contact);if(!nativeContact)return NO;
    SEL getter=sel_registerName("getMsgSenderHandlerWithcontact:");
    Method method=class_getInstanceMethod(object_getClass(service),getter);const char *getterArgs[]={"@",":","@"};
    if(!timantirecall_methodTypes(method,"@",3,getterArgs))return timantirecall_referenceForwardReject(shape,@"native-handler-api-rejected");
    id handler=((id(*)(id,SEL,id))method_getImplementation(method))(service,getter,nativeContact);
    Class expected=objc_getClass("_TtC10MsgManager16MsgSenderHandler");
    if(!expected||![handler isKindOfClass:expected])return timantirecall_referenceForwardReject(shape,@"native-handler-class-rejected");
    SEL selector=sel_registerName("forwardMsgWithMsgIds:srcContact:dstContacts:msgAttributeInfos:cb:");
    method=class_getInstanceMethod(object_getClass(handler),selector);
    const char *args[]={"@",":","@","@","@","@","@?"};
    if(!timantirecall_methodTypes(method,"v",7,args))return timantirecall_referenceForwardReject(shape,@"native-forward-api-rejected");
    void(^completion)(int32_t,NSString *,NSDictionary *)=^(int32_t code,NSString *message,NSDictionary *result) {
        (void)message;(void)result;
        NSString *reason=[NSString stringWithFormat:@"%@-native-%@",shape,code==0?@"completed":@"error"];
        timantirecall_replayTrace(@"send",@{@"reason":reason,@"shape":shape});
    };
    @try {
        ((void(*)(id,SEL,id,id,id,id,id))method_getImplementation(method))(handler,selector,@[messageID],contact,@[contact],nil,completion);
    } @catch(NSException *exception) {
        (void)exception;
        if([timantirecall_settings() timantirecall_replayDiagnostics])
            timantirecall_replayTrace(@"send",@{@"reason":[NSString stringWithFormat:@"%@-native-exception",shape],@"shape":shape});
        return NO;
    }
    return YES;
}
static NSDictionary *timantirecall_photoForwardSnapshot(id record,id payload,NSNumber *subtype) {
    BOOL valid=NO;NSNumber *messageID=timantirecall_richRead(record,"msgId","q",&valid);
    if(!valid||messageID.longLongValue==0)TIMANTIRECALL_RICH_REJECT("photo-message-id-rejected","msgId",messageID,"nonzero-int64");
    NSNumber *sequence=timantirecall_richRead(record,"msgSeq","q",&valid);
    if(!valid||sequence.longLongValue<=0)TIMANTIRECALL_RICH_REJECT("photo-message-sequence-rejected","msgSeq",sequence,"positive-int64");
    NSMutableDictionary *photo=[@{@"msgId":[messageID copy],@"msgSeq":[sequence copy],@"picSubType":[subtype copy]} mutableCopy];
    for(const char * const *field=(const char * const[]){"fileUuid","md5HexStr","originImageMd5",NULL};*field;field++) {
        id value=timantirecall_richRead(payload,*field,"@",&valid);
        if(!valid||(value&&(![value isKindOfClass:NSString.class]||[value length]>4096)))
            TIMANTIRECALL_RICH_REJECT("photo-resource-shape",*field,value,"nil-or-bounded-string");
        photo[@(*field)]=value?[value copy]:NSNull.null;
    }
    NSNumber *size=timantirecall_richRead(payload,"fileSize","Q",&valid);
    if(!valid)TIMANTIRECALL_RICH_REJECT("photo-size-abi-rejected","fileSize",nil,"uint64");
    photo[@"fileSize"]=[size copy];
    timantirecall_replayTrace(@"rich",@{@"reason":@"snapshot-ready",@"shape":@"photo-forward"});
    return @{@"mode":@"photo-forward",@"photo":photo.copy};
}
static BOOL timantirecall_photoForwardSend(id service,id contact,id record,NSDictionary *snapshot) {
    NSDictionary *photo=snapshot[@"photo"];
    if(![snapshot[@"mode"] isEqual:@"photo-forward"]||![photo isKindOfClass:NSDictionary.class])return NO;
    return timantirecall_nativeReferenceForward(service,contact,record,photo[@"msgId"],@"photo");
}
