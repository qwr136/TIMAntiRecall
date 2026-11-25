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
static BOOL timantirecall_receivedPhotoPathIsLocalCandidate(NSString *path) {
    if(![path isKindOfClass:NSString.class]||path.length==0)return YES;
    NSURLComponents *components=[NSURLComponents componentsWithString:path];
    if(components.scheme.length||![path isAbsolutePath])return NO;
    NSString *resolved=path.stringByResolvingSymlinksInPath.stringByStandardizingPath;
    NSString *home=NSHomeDirectory().stringByResolvingSymlinksInPath.stringByStandardizingPath;
    return [resolved hasPrefix:[home stringByAppendingString:@"/"]];
}
static NSDictionary *timantirecall_receivedPhotoFile(id payload,NSString *sourcePath,BOOL *allowOriginalDownload) {
    if(allowOriginalDownload)*allowOriginalDownload=YES;
    NSDictionary *file=nil;
    if([sourcePath isKindOfClass:NSString.class]&&sourcePath.length) {
        if(!timantirecall_receivedPhotoPathIsLocalCandidate(sourcePath)) {
            file=timantirecall_richFileIdentityWithOrigin(sourcePath,@"record-source");
            if(allowOriginalDownload)*allowOriginalDownload=NO;
            timantirecall_replayTrace(@"rich",@{@"reason":@"photo-remote-source-rejected",@"source":@"record-source"});return nil;
        }
        file=timantirecall_richFileIdentityWithOrigin(sourcePath,@"record-source");if(file)return file;
    }
    // TIM 4.1.0.81 OCPicElement category: @20@0:8B16, IMP 0x104be27c4.
    // NO selects assembleRichMediaFilePathWithPathInfo, not the create/download route.
    SEL selector=sel_registerName("fetchOriginalImgPathWithCreateFolder:");
    Method method=class_getInstanceMethod(object_getClass(payload),selector);const char *args[]={"@",":","B"};
    if(!timantirecall_methodTypes(method,"@",3,args)) {
        if(allowOriginalDownload)*allowOriginalDownload=NO;
        timantirecall_richRejectTrace(@"photo-cache-api-unavailable",@"sourcePath",nil,@"original-path-object-bool");return nil;
    }
    timantirecall_replayTrace(@"rich",@{@"reason":@"photo-cache-resolver-called",@"field":@"fetchOriginalImgPathWithCreateFolder",@"source":@"native-cache",@"shape":@"createFolder-no"});
    id path=((id(*)(id,SEL,BOOL))method_getImplementation(method))(payload,selector,NO);
    NSString *resultShape=![path isKindOfClass:NSString.class]? (path?@"other-object":@"nil"):
        ([path length]?@"string-nonempty":@"string-empty");
    timantirecall_replayTrace(@"rich",@{@"reason":@"photo-cache-resolver-result",@"field":@"original-path",@"source":@"native-cache",@"shape":resultShape,
        @"valueClass":path?NSStringFromClass([path class]):@"nil"});
    if(path&&(![path isKindOfClass:NSString.class]||([path length]&&!timantirecall_receivedPhotoPathIsLocalCandidate(path)))) {
        if(allowOriginalDownload)*allowOriginalDownload=NO;
        timantirecall_replayTrace(@"rich",@{@"reason":@"photo-remote-cache-rejected",@"source":@"native-cache"});return nil;
    }
    file=timantirecall_richFileIdentityWithOrigin(path,@"native-cache");
    if(file)timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-cache-ready",@"shape":@"photo",@"source":@"native-cache"});
    return file;
}
@interface NSObject (TIMAntiRecallNativePhotoDownload)
+ (id)recordConvertAIOMsgModel:(id)record;
- (instancetype)initWithAIOMsgModel:(id)model;
- (void)startDownloadImage:(int32_t)type;
- (id)originalImagePath;
@end
typedef void (^TIMAntiRecallPhotoDownloadCompletion)(NSDictionary *file,NSNumber *subtype);
static char timantirecall_photoDownloadJobKey;
@interface TIMAntiRecallPhotoDownloadJob : NSObject
@property(nonatomic,strong) id timantirecall_record;
@property(nonatomic,strong) id timantirecall_agent;
@property(nonatomic,strong) NSNumber *timantirecall_subtype;
@property(nonatomic,copy) NSString *timantirecall_owner;
@property(nonatomic,copy) TIMAntiRecallPhotoDownloadCompletion timantirecall_completion;
@property(nonatomic,copy) BOOL (^timantirecall_shouldContinue)(void);
@property(nonatomic) NSUInteger timantirecall_attempts;
@property(nonatomic) BOOL timantirecall_finished;
- (void)timantirecall_poll;
- (void)timantirecall_finish:(NSDictionary *)file;
@end
@implementation TIMAntiRecallPhotoDownloadJob
- (void)timantirecall_finish:(NSDictionary *)file {
    if(self.timantirecall_finished)return;self.timantirecall_finished=YES;
    id record=self.timantirecall_record;
    if(record&&objc_getAssociatedObject(record,&timantirecall_photoDownloadJobKey)==self)
        objc_setAssociatedObject(record,&timantirecall_photoDownloadJobKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    TIMAntiRecallPhotoDownloadCompletion completion=self.timantirecall_completion;
    NSNumber *subtype=self.timantirecall_subtype;
    self.timantirecall_completion=nil;self.timantirecall_shouldContinue=nil;self.timantirecall_record=nil;self.timantirecall_agent=nil;self.timantirecall_subtype=nil;self.timantirecall_owner=nil;
    if(completion)completion(file,subtype);
}
- (void)timantirecall_poll {
    if(self.timantirecall_finished||!NSThread.isMainThread)return;
    if(self.timantirecall_shouldContinue&&!self.timantirecall_shouldContinue()) {
        SEL selector=sel_registerName("cancelDownloadImage:");const char *args[]={"@",":","i"};Method cancel=class_getInstanceMethod(object_getClass(self.timantirecall_agent),selector);
        if(timantirecall_methodTypes(cancel,"v",3,args))((void(*)(id,SEL,int32_t))method_getImplementation(cancel))(self.timantirecall_agent,selector,2);
        timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-download-cancelled",@"source":@"native-agent-original"});
        [self timantirecall_finish:nil];return;
    }
    if(![timantirecall_settings() timantirecall_messageReplay]||![self.timantirecall_owner isEqual:timantirecall_currentAccount()]) {
        SEL selector=sel_registerName("cancelDownloadImage:");const char *args[]={"@",":","i"};Method cancel=class_getInstanceMethod(object_getClass(self.timantirecall_agent),selector);
        if(timantirecall_methodTypes(cancel,"v",3,args))((void(*)(id,SEL,int32_t))method_getImplementation(cancel))(self.timantirecall_agent,selector,2);
        timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-download-cancelled",@"source":@"native-agent-original"});
        [self timantirecall_finish:nil];return;
    }
    BOOL valid=NO;id path=timantirecall_richRead(self.timantirecall_agent,"originalImagePath","@",&valid);
    NSDictionary *file=valid?timantirecall_richFileIdentityWithOrigin(path,@"native-agent-original"):nil;
#ifdef TIMANTIRECALL_UI_TEST
    NSLog(@"TIMANTI_ORIGINAL_POLL attempt=%lu pathReadable=%d",(unsigned long)self.timantirecall_attempts,file!=nil);
#endif
    if(file) {
        timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-download-ready",@"source":@"native-agent-original"});
        [self timantirecall_finish:file];return;
    }
    if(++self.timantirecall_attempts>=120) {
        SEL selector=sel_registerName("cancelDownloadImage:");const char *args[]={"@",":","i"};Method cancel=class_getInstanceMethod(object_getClass(self.timantirecall_agent),selector);
        if(timantirecall_methodTypes(cancel,"v",3,args))((void(*)(id,SEL,int32_t))method_getImplementation(cancel))(self.timantirecall_agent,selector,2);
        timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-download-timeout",@"source":@"native-agent-original"});
        [self timantirecall_finish:nil];return;
    }
    __weak TIMAntiRecallPhotoDownloadJob *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf timantirecall_poll];});
}
@end
static BOOL timantirecall_receivedStartOriginalPhotoDownload(id record,NSNumber *subtype,TIMAntiRecallPhotoDownloadCompletion completion,BOOL (^shouldContinue)(void)) {
    if(!NSThread.isMainThread||!record||![subtype isKindOfClass:NSNumber.class]||!completion||(shouldContinue&&!shouldContinue()))return NO;
    TIMAntiRecallPhotoDownloadJob *existing=objc_getAssociatedObject(record,&timantirecall_photoDownloadJobKey);
    if(existing&&!existing.timantirecall_finished)return NO;
    Class converter=objc_getClass("NTRecordConverter"),aioClass=objc_getClass("QQAIOMsgModel"),agentClass=objc_getClass("QQRichMediaPhotoBrowserChatImageAgent");
    SEL convertSelector=sel_registerName("recordConvertAIOMsgModel:"),initSelector=sel_registerName("initWithAIOMsgModel:"),startSelector=sel_registerName("startDownloadImage:"),pathSelector=sel_registerName("originalImagePath");
    const char *classArgs[]={"@",":","@"};Method convert=converter?class_getClassMethod(converter,convertSelector):NULL;
    const char *initArgs[]={"@",":","@"};Method init=agentClass?class_getInstanceMethod(agentClass,initSelector):NULL;
    const char *startArgs[]={"@",":","i"};Method start=agentClass?class_getInstanceMethod(agentClass,startSelector):NULL;
    const char *pathArgs[]={"@",":"};Method pathMethod=agentClass?class_getInstanceMethod(agentClass,pathSelector):NULL;
    if(!aioClass||!agentClass||!timantirecall_methodTypes(convert,"@",3,classArgs)||
       !timantirecall_methodTypes(init,"@",3,initArgs)||!timantirecall_methodTypes(start,"v",3,startArgs)||
       !timantirecall_methodTypes(pathMethod,"@",2,pathArgs)) {
        timantirecall_richRejectTrace(@"photo-native-original-download-api-unavailable",@"originalImage",nil,@"verified-native-agent-ABI");return NO;
    }
    TIMAntiRecallPhotoDownloadJob *job=nil;
    @try {
        id aio=((id(*)(id,SEL,id))method_getImplementation(convert))(converter,convertSelector,record);
        if(!aio||![aio isKindOfClass:aioClass]) {
            timantirecall_richRejectTrace(@"photo-native-aio-model-rejected",@"record",aio,@"QQAIOMsgModel");return NO;
        }
        id agent=[[agentClass alloc] initWithAIOMsgModel:aio];if(!agent||![agent isKindOfClass:agentClass])return NO;
        BOOL valid=NO;id path=timantirecall_richRead(agent,"originalImagePath","@",&valid);
        NSDictionary *existingFile=valid?timantirecall_richFileIdentityWithOrigin(path,@"native-agent-original"):nil;
        if(existingFile) {completion(existingFile,subtype);return YES;}
        job=[TIMAntiRecallPhotoDownloadJob new];job.timantirecall_record=record;job.timantirecall_agent=agent;
        job.timantirecall_subtype=[subtype copy];job.timantirecall_owner=[timantirecall_currentAccount() copy];job.timantirecall_completion=[completion copy];job.timantirecall_shouldContinue=[shouldContinue copy];
        objc_setAssociatedObject(record,&timantirecall_photoDownloadJobKey,job,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void(*)(id,SEL,int32_t))method_getImplementation(start))(agent,startSelector,2);
        timantirecall_replayTrace(@"rich",@{@"reason":@"photo-original-download-started",@"source":@"native-agent-original",@"shape":@"original-resolution"});
        [job timantirecall_poll];return YES;
    } @catch(NSException *exception) {
        (void)exception;
        if(job)[job timantirecall_finish:nil];
        timantirecall_richRejectTrace(@"photo-native-original-download-exception",@"originalImage",nil,@"native-agent-request");return NO;
    }
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
