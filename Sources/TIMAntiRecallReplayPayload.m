#import "TIMAntiRecallReplayPayload.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallReplayTrace.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

typedef struct { const char *name,*encoding,*objectClass; } TIMAntiRecallReplayField;
#include "TIMAntiRecallReplaySchema.inc"
static const TIMAntiRecallReplayField *timantirecall_richFields(NSString *name,NSUInteger *count) {
#define TIMANTIRECALL_SCHEMA(n) if([name isEqual:@#n]){*count=sizeof(timantirecall_##n##Fields)/sizeof(TIMAntiRecallReplayField);return timantirecall_##n##Fields;}
    TIMANTIRECALL_SCHEMA(OCTextElement) TIMANTIRECALL_SCHEMA(OCFaceElement)
    TIMANTIRECALL_SCHEMA(OCMarketFaceElement) TIMANTIRECALL_SCHEMA(OCReplyElement)
    TIMANTIRECALL_SCHEMA(OCReplyAbsElement) TIMANTIRECALL_SCHEMA(OCReplyAbsFaceElement)
    TIMANTIRECALL_SCHEMA(OCReplyAbsPicElement) TIMANTIRECALL_SCHEMA(OCPicElement)
#undef TIMANTIRECALL_SCHEMA
    *count=0;return NULL;
}
static IMP timantirecall_richGetter(id obj,const char *name,const char *encoding) {
    if(!obj)return NULL;const char *args[]={"@",":"};
    Method m=class_getInstanceMethod(object_getClass(obj),sel_registerName(name));
    return timantirecall_methodTypes(m,encoding,2,args)?method_getImplementation(m):NULL;
}
static id timantirecall_richRead(id obj,const char *name,const char *encoding,BOOL *valid) {
    IMP imp=timantirecall_richGetter(obj,name,encoding);*valid=imp!=NULL;if(!imp)return nil;
    SEL sel=sel_registerName(name);
    switch(encoding[0]) {
        case '@':return ((id(*)(id,SEL))imp)(obj,sel);
        case 'i':return @(((int32_t(*)(id,SEL))imp)(obj,sel));
        case 'I':return @(((uint32_t(*)(id,SEL))imp)(obj,sel));
        case 'q':return @(((int64_t(*)(id,SEL))imp)(obj,sel));
        case 'Q':return @(((uint64_t(*)(id,SEL))imp)(obj,sel));
        case 'B':return @(((BOOL(*)(id,SEL))imp)(obj,sel));
    }
    *valid=NO;return nil;
}
static BOOL timantirecall_richWrite(id obj,const char *name,const char *encoding,id value) {
    NSString *n=@(name);NSString *setter=[NSString stringWithFormat:@"set%@%@:",[[n substringToIndex:1] uppercaseString],[n substringFromIndex:1]];
    SEL sel=NSSelectorFromString(setter);const char *args[]={"@",":",encoding};
    Method m=class_getInstanceMethod(object_getClass(obj),sel);
    if(!timantirecall_methodTypes(m,"v",3,args))return NO;IMP imp=method_getImplementation(m);
    switch(encoding[0]) {
        case '@':((void(*)(id,SEL,id))imp)(obj,sel,value==NSNull.null?nil:value);return YES;
        case 'i':((void(*)(id,SEL,int32_t))imp)(obj,sel,[value intValue]);return YES;
        case 'I':((void(*)(id,SEL,uint32_t))imp)(obj,sel,[value unsignedIntValue]);return YES;
        case 'q':((void(*)(id,SEL,int64_t))imp)(obj,sel,[value longLongValue]);return YES;
        case 'Q':((void(*)(id,SEL,uint64_t))imp)(obj,sel,[value unsignedLongLongValue]);return YES;
        case 'B':((void(*)(id,SEL,BOOL))imp)(obj,sel,[value boolValue]);return YES;
    }
    return NO;
}
static id timantirecall_richDescribe(id object,NSString *className,NSUInteger depth,NSUInteger *budget);
static id timantirecall_richValue(id value,NSString *type,NSUInteger depth,NSUInteger *budget) {
    if(!value)return NSNull.null;
    if(depth>7||!*budget)return nil;--*budget;
    if([type isEqual:@"NSString"]) {
        if(![value isKindOfClass:NSString.class]||[value length]>16384)return nil;
        return [[NSString alloc] initWithString:value];
    }
    if([type isEqual:@"NSNumber"])
        return [value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue])?[value copy]:nil;
    if([type isEqual:@"NSData"])
        return [value isKindOfClass:NSData.class]&&[value length]<=65536?[[NSData alloc] initWithData:value]:nil;
    if([type isEqual:@"NSArray"]||[type isEqual:@"ReplyPreview"]) {
        if(![value isKindOfClass:NSArray.class]||[value count]>64)return nil;
        NSMutableArray *out=[NSMutableArray array];
        for(id item in value) {
            NSString *itemType=[type isEqual:@"ReplyPreview"]?@"OCReplyAbsElement":
                [item isKindOfClass:NSNumber.class]?@"NSNumber":[item isKindOfClass:NSString.class]?@"NSString":nil;
            if(!itemType)return nil;
            id copied=timantirecall_richValue(item,itemType,depth+1,budget);if(!copied)return nil;[out addObject:copied];
        }
        return out.copy;
    }
    NSUInteger count=0;
    if(timantirecall_richFields(type,&count))return timantirecall_richDescribe(value,type,depth+1,budget);
    // Unknown object graphs (including URLs/links/emoji ads) are never silently dropped.
    return nil;
}
static id timantirecall_richDescribe(id object,NSString *className,NSUInteger depth,NSUInteger *budget) {
    Class cls=NSClassFromString(className);NSUInteger count=0;
    const TIMAntiRecallReplayField *fields=timantirecall_richFields(className,&count);
    if(depth>7||!fields||!cls||![object isKindOfClass:cls]||!*budget)return nil;
    --*budget;NSMutableDictionary *values=[NSMutableDictionary dictionary];
    for(NSUInteger i=0;i<count;i++) {
        BOOL valid=NO;id value=timantirecall_richRead(object,fields[i].name,fields[i].encoding,&valid);
        if(!valid)return nil;
        id copied=value;
        if(fields[i].encoding[0]=='@') {
            NSString *type=@(fields[i].objectClass);
            if([className isEqual:@"OCReplyElement"]&&strcmp(fields[i].name,"sourceMsgTextElems")==0)type=@"ReplyPreview";
            copied=timantirecall_richValue(value,type,depth+1,budget);
        }
        if(!copied)return nil;values[@(fields[i].name)]=copied;
    }
    return @{@"class":className,@"values":values.copy};
}
static id timantirecall_richBuild(NSDictionary *description,NSUInteger depth) {
    if(depth>7||![description isKindOfClass:NSDictionary.class])return nil;
    NSString *name=description[@"class"];NSDictionary *values=description[@"values"];
    if(![name isKindOfClass:NSString.class]||![values isKindOfClass:NSDictionary.class])return nil;
    NSUInteger count=0;const TIMAntiRecallReplayField *fields=timantirecall_richFields(name,&count);
    Class cls=NSClassFromString(name);const char *args[]={"@",":"};
    if(!fields||!cls||!timantirecall_methodTypes(class_getInstanceMethod(cls,@selector(init)),"@",2,args))return nil;
    id result=[[cls alloc] init];if(!result)return nil;
    for(NSUInteger i=0;i<count;i++) {
        id value=values[@(fields[i].name)];if(!value)return nil;
        if(fields[i].encoding[0]=='@'&&value!=NSNull.null) {
            if([value isKindOfClass:NSDictionary.class]) {
                value=timantirecall_richBuild(value,depth+1);if(!value)return nil;
            }else if([value isKindOfClass:NSArray.class]) {
                NSMutableArray *items=[NSMutableArray array];
                for(id entry in value){id item=[entry isKindOfClass:NSDictionary.class]?timantirecall_richBuild(entry,depth+1):[entry copy];if(!item)return nil;[items addObject:item];}
                value=items.copy;
            }else value=[value copy];
        }
        if(!timantirecall_richWrite(result,fields[i].name,fields[i].encoding,value))return nil;
    }
    return result;
}

static NSDictionary *timantirecall_richFileIdentity(NSString *path) {
    if(![path isKindOfClass:NSString.class]||path.length==0||path.length>4096||![path isAbsolutePath])return nil;
    NSString *resolved=path.stringByResolvingSymlinksInPath.stringByStandardizingPath;
    NSString *home=NSHomeDirectory().stringByResolvingSymlinksInPath.stringByStandardizingPath;
    if(![resolved hasPrefix:[home stringByAppendingString:@"/"]])return nil;
    struct stat st={0};
    if(lstat(resolved.fileSystemRepresentation,&st)!=0||!S_ISREG(st.st_mode)||st.st_size<=0||st.st_size>24*1024*1024)return nil;
    if(access(resolved.fileSystemRepresentation,R_OK)!=0)return nil;
    return @{@"path":resolved,@"size":@(st.st_size),@"inode":@(st.st_ino),@"device":@(st.st_dev),
        @"mtime":@(st.st_mtimespec.tv_sec),@"nsec":@(st.st_mtimespec.tv_nsec)};
}
static BOOL timantirecall_richNonzero(id value) {
    if(!value||value==NSNull.null)return NO;
    return [value isKindOfClass:NSNumber.class]?[value doubleValue]!=0:
           [value respondsToSelector:@selector(length)]?[value length]!=0:YES;
}
NSDictionary *timantirecall_richReplaySnapshot(id record) {
    @try {
        Class rc=objc_getClass("OCMsgRecord"),ec=objc_getClass("OCMsgElement");
        if(!rc||!ec||![record isKindOfClass:rc])return nil;
        BOOL valid=NO;id elements=timantirecall_richRead(record,"elements","@",&valid);
        if(!valid||![elements isKindOfClass:NSArray.class]||[elements count]<1||[elements count]>32)return nil;
        static const char *slots[]={"textElement","faceElement","marketFaceElement","replyElement","picElement","pttElement","videoElement","grayTipElement","arkElement","fileElement","liveGiftElement","markdownElement","structLongMsgElement","multiForwardMsgElement","giphyElement","walletElement","inlineKeyboardElement","textGiftElement","calendarElement","yoloGameResultElement","avRecordElement","structMsgElement","faceBubbleElement","shareLocationElement","tofuRecordElement","taskTopMsgElement","recommendedMsgElement","actionBarElement","prologueMsgElement"};
        NSArray *classes=@[@"OCTextElement",@"OCFaceElement",@"OCMarketFaceElement",@"OCReplyElement",@"OCPicElement"];
        NSMutableArray *descriptions=[NSMutableArray array];NSUInteger budget=2048,rich=0,replies=0,textSize=0;
        for(id element in elements) {
            if(![element isKindOfClass:ec])return nil;
            id type=timantirecall_richRead(element,"elementType","i",&valid);if(!valid)return nil;
            id payload=nil;NSInteger slot=-1;
            for(NSUInteger i=0;i<sizeof(slots)/sizeof(slots[0]);i++) {
                id item=timantirecall_richRead(element,slots[i],"@",&valid);
                if(!valid)return nil;
                if(item){if(payload||i>=5)return nil;payload=item;slot=(NSInteger)i;}
            }
            if(!payload||slot<0)return nil;
            if(slot==4) {
                if([elements count]!=1||[type intValue]!=2)return nil;
                Class pc=objc_getClass("OCPicElement");if(!pc||![payload isKindOfClass:pc])return nil;
                id flash=timantirecall_richRead(payload,"isFlashPic","@",&valid);if(!valid||timantirecall_richNonzero(flash))return nil;
                id invalid=timantirecall_richRead(payload,"invalidState","@",&valid);if(!valid||timantirecall_richNonzero(invalid))return nil;
                NSNumber *subtype=timantirecall_richRead(payload,"picSubType","i",&valid);if(!valid||subtype.intValue<0)return nil;
                NSString *path=timantirecall_richRead(payload,"sourcePath","@",&valid);if(!valid)return nil;
                NSDictionary *file=timantirecall_richFileIdentity(path);if(!file)return nil;
                return @{@"mode":@"photo",@"file":file,@"subtype":subtype};
            }
            if((slot==0&&[type intValue]!=1)||(slot==1&&[type intValue]!=3&&[type intValue]!=5)||
               (slot==2&&[type intValue]!=11)||(slot==3&&[type intValue]!=7))return nil;
            NSDictionary *desc=timantirecall_richDescribe(payload,classes[(NSUInteger)slot],0,&budget);if(!desc)return nil;
            NSDictionary *v=desc[@"values"];
            if(slot==0) { if(![v[@"content"] isKindOfClass:NSString.class])return nil;textSize+=[v[@"content"] length];if(textSize>16384)return nil; }
            else rich++;
            if(slot==1) {
                for(NSString *key in @[@"pokeType",@"pokeFlag",@"vaspokeId",@"pokeStrength",@"randomType",@"resultId"])
                    if(timantirecall_richNonzero(v[key]))return nil;
            }
            if(slot==2) {
                if(![v[@"emojiId"] isKindOfClass:NSString.class]||![v[@"emojiId"] length])return nil;
            }
            if(slot==3) {
                if(++replies>1||[v[@"replayMsgId"] longLongValue]==0||[v[@"sourceMsgExpired"] boolValue])return nil;
            }
            [descriptions addObject:@{@"type":type,@"slot":@(slots[(NSUInteger)slot]),@"payload":desc}];
        }
        // Never bypass the existing single/plain-text mention and metadata policy.
        if(!rich||(replies&&[elements count]==1))return nil;
        return @{@"mode":@"elements",@"elements":descriptions.copy};
    } @catch(NSException *exception) {
        (void)exception;timantirecall_replayTrace(@"gate",@{@"reason":@"rich-snapshot-rejected"});return nil;
    }
}
NSArray *timantirecall_richReplayElements(NSDictionary *snapshot) {
    if(![snapshot[@"mode"] isEqual:@"elements"]||![snapshot[@"elements"] isKindOfClass:NSArray.class])return nil;
    @try {
        Class cls=objc_getClass("OCMsgElement");const char *args[]={"@",":"};
        if(!cls||!timantirecall_methodTypes(class_getInstanceMethod(cls,@selector(init)),"@",2,args))return nil;
        NSMutableArray *out=[NSMutableArray array];
        for(NSDictionary *entry in snapshot[@"elements"]) {
            id payload=timantirecall_richBuild(entry[@"payload"],0);if(!payload)return nil;
            NSString *slot=entry[@"slot"];
            if(![@[@"textElement",@"faceElement",@"marketFaceElement",@"replyElement"] containsObject:slot])return nil;
            id element=[[cls alloc] init];
            if(!timantirecall_richWrite(element,"elementType","i",entry[@"type"])||
               !timantirecall_richWrite(element,"elementId","q",@0)||
               !timantirecall_richWrite(element,slot.UTF8String,"@",payload))return nil;
            [out addObject:element];
        }
        return out.count?out.copy:nil;
    } @catch(NSException *exception) {(void)exception;return nil;}
}

static id timantirecall_richPhotoContact(id record,id contact) {
    BOOL valid=NO;NSNumber *kind=timantirecall_richRead(record,"chatType","i",&valid);
    if(!valid||(kind.intValue!=1&&kind.intValue!=2))return nil;
    NSNumber *uin=timantirecall_richRead(record,"peerUin","q",&valid);if(!valid||uin.longLongValue<=0)return nil;
    Class cls=objc_getClass("NTAIOContact");const char *args[]={"@",":"};
    if(!cls||!timantirecall_methodTypes(class_getInstanceMethod(cls,@selector(init)),"@",2,args))return nil;
    id native=[[cls alloc] init];NSString *number=uin.stringValue;
    if(!timantirecall_richWrite(native,"chatType","q",kind)||
       !timantirecall_richWrite(native,kind.intValue==1?"uin":"groupCode","@",number))return nil;
    id roundtrip=timantirecall_richRead(native,"convertToOCContact","@",&valid);
    Class oc=objc_getClass("OCContact");if(!valid||!oc||![roundtrip isKindOfClass:oc])return nil;
    for(const char * const *field=(const char * const[]){"chatType","peerUid","guildId",NULL};*field;field++) {
        const char *encoding=strcmp(*field,"chatType")==0?"i":"@";
        id original=timantirecall_richRead(contact,*field,encoding,&valid);if(!valid)return nil;
        id converted=timantirecall_richRead(roundtrip,*field,encoding,&valid);if(!valid)return nil;
        if(original!=converted&&![original isEqual:converted])return nil;
    }
    return native;
}
static NSData *timantirecall_richReadPhoto(NSDictionary *file) {
    NSString *path=file[@"path"];
    if(![file isEqual:timantirecall_richFileIdentity(path)])return nil;
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);
    if(fd<0)return nil;struct stat st={0};BOOL valid=fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&
        st.st_size==[file[@"size"] longLongValue]&&st.st_ino==[file[@"inode"] unsignedLongLongValue]&&
        (uint64_t)st.st_dev==[file[@"device"] unsignedLongLongValue]&&st.st_mtimespec.tv_sec==[file[@"mtime"] longLongValue]&&
        st.st_mtimespec.tv_nsec==[file[@"nsec"] longLongValue];
    if(!valid){close(fd);return nil;}
    NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)st.st_size];
    size_t used=0;
    while(used<data.length) {
        ssize_t n=read(fd,(uint8_t *)data.mutableBytes+used,data.length-used);
        if(n<=0){close(fd);return nil;}used+=(size_t)n;
    }
    close(fd);
    if(![file isEqual:timantirecall_richFileIdentity(path)]||data.length<12)return nil;
    const uint8_t *p=data.bytes;
    BOOL image=(p[0]==0xff&&p[1]==0xd8&&p[2]==0xff)||!memcmp(p,"\211PNG\r\n\032\n",8)||
        !memcmp(p,"GIF87a",6)||!memcmp(p,"GIF89a",6)||(!memcmp(p,"RIFF",4)&&!memcmp(p+8,"WEBP",4))||
        (!memcmp(p+4,"ftyp",4)&&(!memcmp(p+8,"heic",4)||!memcmp(p+8,"heix",4)||!memcmp(p+8,"mif1",4)));
    return image?data.copy:nil;
}
BOOL timantirecall_richReplaySend(id service,id contact,id record,NSDictionary *snapshot) {
    if(!NSThread.isMainThread||!service||!contact||!snapshot)return NO;
    if(![snapshot isEqual:timantirecall_richReplaySnapshot(record)])return NO;
    // Verified block descriptor v20@?0i8@"NSString"12. No message text, paths,
    // account IDs or error descriptions go to the diagnostic log.
    void (^completion)(int32_t,NSString *)=^(int32_t code,NSString *description) {
        (void)description;timantirecall_replayTrace(@"send",@{@"reason":code==0?@"rich-native-completed":@"rich-native-error"});
    };
    if([snapshot[@"mode"] isEqual:@"elements"]) {
        SEL sel=sel_registerName("sendMsgWithOCContact:msgElems:msgAttributeInfos:callBack:");
        const char *args[]={"@",":","@","@","@","@?"};
        Method method=class_getInstanceMethod(object_getClass(service),sel);
        if(!timantirecall_methodTypes(method,"v",6,args))return NO;
        NSArray *elements=timantirecall_richReplayElements(snapshot);if(!elements)return NO;
        // Own, detached objects; native service supplies a new message ID. Do not
        // import the received message's attributes or call failed-message resend.
        ((void(*)(id,SEL,id,id,id,id))method_getImplementation(method))(service,sel,contact,elements,nil,completion);
        return YES;
    }
    if(![snapshot[@"mode"] isEqual:@"photo"])return NO;
    SEL sel=sel_registerName("sendPicMsg:sourcePath:additionalMsg:picSubType:callBack:");
    const char *args[]={"@",":","@","@","@","i","@?"};
    Method method=class_getInstanceMethod(object_getClass(service),sel);
    if(!timantirecall_methodTypes(method,"v",7,args))return NO;
    id nativeContact=timantirecall_richPhotoContact(record,contact);if(!nativeContact)return NO;
    NSData *bytes=timantirecall_richReadPhoto(snapshot[@"file"]);if(!bytes)return NO;
    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:@"TIMAntiRecallReplay"];
    NSError *error=nil;
    if(![NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error])return NO;
    NSString *path=[folder stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".image"]];
    if(![bytes writeToFile:path options:NSDataWritingAtomic error:&error])return NO;
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];
    // Only a local isolated file enters the original producer. No URL fetching,
    // received file ID reuse or deletion of the original message resource.
    void (^photoCompletion)(int32_t,NSString *)=^(int32_t code,NSString *description) {
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];completion(code,description);
    };
    @try {
        ((void(*)(id,SEL,id,id,id,int32_t,id))method_getImplementation(method))(service,sel,nativeContact,path,nil,[snapshot[@"subtype"] intValue],photoCompletion);
    } @catch(NSException *exception) {
        (void)exception;[NSFileManager.defaultManager removeItemAtPath:path error:NULL];return NO;
    }
    // Native local branch loads UIImage and NSData synchronously before it
    // returns; the async upload owns those new objects, not this temporary path.
    [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    return YES;
}
