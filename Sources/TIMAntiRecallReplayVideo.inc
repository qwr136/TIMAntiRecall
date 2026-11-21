// Single native video only. Reuse the original native message reference through
// TIM's forward pipeline; no AVAsset staging, path guessing, or borrowed-file cleanup.
static BOOL timantirecall_videoReject(NSString *reason,NSString *field) {
    if([timantirecall_settings() timantirecall_replayDiagnostics])
        timantirecall_replayTrace(@"send",@{@"reason":reason,@"field":field,@"shape":@"video"});
    return NO;
}
static NSDictionary *timantirecall_videoSnapshot(id record,id payload) {
    Class cls=objc_getClass("OCVideoElement");
    if(!cls||![payload isKindOfClass:cls]) {timantirecall_videoReject(@"video-class-rejected",@"videoElement");return nil;}
    BOOL valid=NO;id invalid=timantirecall_richRead(payload,"invalidState","@",&valid);
    if(!valid||(invalid&&![invalid isKindOfClass:NSNumber.class])||timantirecall_richNonzero(invalid)) {timantirecall_videoReject(@"video-invalid-state",@"invalidState");return nil;}
    NSMutableDictionary *values=[NSMutableDictionary dictionary];
    for(const char * const *field=(const char * const[]){"videoMd5","fileUuid",NULL};*field;field++) {
        id value=timantirecall_richRead(payload,*field,"@",&valid);
        if(!valid||(value&&(![value isKindOfClass:NSString.class]||[value length]>4096))) {
            timantirecall_videoReject(@"video-resource-shape",@(*field));return nil;
        }
        values[@(*field)]=value?[value copy]:NSNull.null;
    }
    NSString *md5=values[@"videoMd5"]==NSNull.null?nil:values[@"videoMd5"];
    NSString *uuid=values[@"fileUuid"]==NSNull.null?nil:values[@"fileUuid"];
    if(!md5.length&&!uuid.length) {timantirecall_videoReject(@"video-resource-unavailable",@"native-resource");return nil;}
    NSNumber *size=timantirecall_richRead(payload,"fileSize","Q",&valid);
    if(!valid||size.unsignedLongLongValue==0) {timantirecall_videoReject(@"video-resource-size-rejected",@"fileSize");return nil;}
    values[@"fileSize"]=size;
    NSNumber *duration=timantirecall_richRead(payload,"fileTime","i",&valid);
    if(!valid||duration.intValue<0) {timantirecall_videoReject(@"video-duration-rejected",@"fileTime");return nil;}
    values[@"fileTime"]=duration;
    for(const char * const *field=(const char * const[]){"msgId","msgSeq",NULL};*field;field++) {
        NSNumber *value=timantirecall_richRead(record,*field,"q",&valid);
        if(!valid||value.longLongValue==0||(strcmp(*field,"msgSeq")==0&&value.longLongValue<0)) {
            timantirecall_videoReject(@"video-message-identity-rejected",@(*field));return nil;
        }
        values[@(*field)]=value;
    }
    timantirecall_replayTrace(@"rich",@{@"reason":@"snapshot-ready",@"shape":@"video"});
    return @{@"mode":@"video",@"video":values.copy};
}
static BOOL timantirecall_videoSend(id service,id contact,id record,NSDictionary *snapshot) {
    NSDictionary *video=snapshot[@"video"];
    if(![video isKindOfClass:NSDictionary.class])return timantirecall_videoReject(@"video-snapshot-rejected",@"snapshot");
    id legacy=timantirecall_richPhotoContact(record,contact);
    if(!legacy)return timantirecall_videoReject(@"video-contact-rejected",@"contact");
    SEL getter=sel_registerName("getMsgSenderHandlerWithcontact:");
    Method method=class_getInstanceMethod(object_getClass(service),getter);const char *getterArgs[]={"@",":","@"};
    if(!timantirecall_methodTypes(method,"@",3,getterArgs))return timantirecall_videoReject(@"video-handler-api-rejected",@"getMsgSenderHandlerWithcontact");
    id handler=((id(*)(id,SEL,id))method_getImplementation(method))(service,getter,legacy);
    Class expected=objc_getClass("_TtC10MsgManager16MsgSenderHandler");
    if(!expected||![handler isKindOfClass:expected])return timantirecall_videoReject(@"video-handler-class-rejected",@"handler");
    SEL selector=sel_registerName("forwardMsgWithMsgIds:srcContact:dstContacts:msgAttributeInfos:cb:");
    method=class_getInstanceMethod(object_getClass(handler),selector);
    const char *args[]={"@",":","@","@","@","@","@?"};
    if(!timantirecall_methodTypes(method,"v",7,args))return timantirecall_videoReject(@"video-forward-api-rejected",@"forwardMsg");
    // Both source and sole destination are the same already-validated current conversation.
    // NSArray<NSNumber(q)> IDs, OCContact source, NSArray<OCContact> destinations, nil attrs.
    void(^completion)(int32_t,NSString *,NSDictionary *)=^(int32_t code,NSString *message,NSDictionary *result) {
        (void)message;(void)result;
        timantirecall_replayTrace(@"send",@{@"reason":code==0?@"video-native-completed":@"video-native-error",@"shape":@"video"});
    };
    @try {
        ((void(*)(id,SEL,id,id,id,id,id))method_getImplementation(method))(handler,selector,@[video[@"msgId"]],contact,@[contact],nil,completion);
    } @catch(NSException *exception) {
        (void)exception;return timantirecall_videoReject(@"video-native-exception",@"forwardMsg");
    }
    return YES; // Submitted once, never a server-delivery guarantee. No retry or source-file deletion.
}
