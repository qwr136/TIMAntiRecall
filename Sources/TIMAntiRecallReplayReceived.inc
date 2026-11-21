// Text-only replay keeps native element metadata instead of flattening @ mentions.
// This is only the fallback path; the established single/plain-text sender stays unchanged.
static BOOL timantirecall_receivedOptionalZero(id value) {
    if(!value||value==NSNull.null)return YES;
    return [value isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()&&[value isEqualToNumber:@0];
}
static BOOL timantirecall_receivedQuoteTarget(NSDictionary *values) {
    if([values[@"replayMsgId"] longLongValue]!=0)return YES;
    id sequence=values[@"replayMsgSeq"];
    if(![sequence isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)sequence)==CFBooleanGetTypeID())return NO;
    const char *encoding=[sequence objCType];
    if(!encoding||encoding[1]!='\0'||!strchr("csilqCSILQ",encoding[0]))return NO;
    int64_t number=[sequence longLongValue];
    // TIM's locked native VM queries by current peer + sequence. Preserve zero ID and every source field.
    return number>0&&[sequence isEqualToNumber:@(number)];
}
static NSDictionary *timantirecall_receivedPhotoFile(id payload,NSString *sourcePath) {
    NSDictionary *file=nil;
    if([sourcePath isKindOfClass:NSString.class]&&sourcePath.length) {
        file=timantirecall_richFileIdentity(sourcePath);if(file)return file;
    }
    // TIM 4.1.0.81 OCPicElement category: @20@0:8B16, IMP 0x104be27c4.
    // NO selects assembleRichMediaFilePathWithPathInfo, not the create/download route.
    SEL selector=sel_registerName("fetchOriginalImgPathWithCreateFolder:");
    Method method=class_getInstanceMethod(object_getClass(payload),selector);const char *args[]={"@",":","B"};
    if(!timantirecall_methodTypes(method,"@",3,args)) {
        timantirecall_richRejectTrace(@"photo-cache-api-unavailable",@"sourcePath",nil,@"original-path-object-bool");return nil;
    }
    id path=((id(*)(id,SEL,BOOL))method_getImplementation(method))(payload,selector,NO);
    file=timantirecall_richFileIdentity(path);
    if(file)timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-cache-ready",@"shape":@"photo"});
    return file;
}
static BOOL timantirecall_receivedTextBody(NSDictionary *values) {
    // Guild/channel/role/link payloads are outside the ordinary private/group contract.
    for(NSString *field in @[@"subElementType",@"atChannelId",@"atRoleId",@"atRoleColor"]) {
        if(!timantirecall_receivedOptionalZero(values[field])) {
            timantirecall_richRejectTrace(@"text-unsupported-metadata",field,values[field],@"nil-or-numeric-zero");return NO;
        }
    }
    id role=values[@"atRoleName"],link=values[@"linkInfo"];
    if((role!=NSNull.null&&(![role isKindOfClass:NSString.class]||[role length]))||(link&&link!=NSNull.null)) {
        timantirecall_richRejectTrace(@"text-unsupported-metadata",@"link-or-role",nil,@"absent");return NO;
    }
    int32_t kind=[values[@"atType"] intValue];int64_t uid=[values[@"atUid"] longLongValue],tiny=[values[@"atTinyId"] longLongValue];
    id target=values[@"atNtUid"];
    BOOL hasNtTarget=[target isKindOfClass:NSString.class]&&[target length]>0;
    BOOL hasTarget=uid>0||hasNtTarget;
    // Locked native producer: 0=plain, 1=@all, 2=specified user. Never reinterpret @all as a user.
    if((kind!=0&&kind!=2)||uid<0||tiny!=0||
       (kind==0&&hasTarget)||(kind==2&&!hasTarget)) {
        timantirecall_richRejectTrace(@"text-mention-identity-rejected",@"atType",values[@"atType"],@"original-targeted-mention-or-plain");return NO;
    }
    NSString *content=values[@"content"];
    if(![content isKindOfClass:NSString.class]||content.length>4096) {
        timantirecall_richRejectTrace(@"text-content-shape",@"content",content,@"NSString-up-to-4096");return NO;
    }
    // Do not reinterpret the native atType or forge a recipient: every field is cloned as received.
    return YES;
}
