#import "TIMAntiRecallStorage.h"
#include <TargetConditionals.h>
#include <sys/stat.h>
#include <errno.h>
NSError *timantirecall_storageError(NSString *message) {
    return [NSError errorWithDomain:@"com.minis.timantirecall.storage" code:1
                          userInfo:@{NSLocalizedDescriptionKey:message}];
}
static BOOL timantirecall_regularURL(NSURL *url,BOOL *exists,NSError **error) {
    *exists=NO;
    if(!url.isFileURL){if(error)*error=timantirecall_storageError(@"不是有效的本地状态路径");return NO;}
    struct stat info;
    if(lstat(url.fileSystemRepresentation,&info)!=0) {
        if(errno==ENOENT)return YES;
        if(error)*error=timantirecall_storageError(@"无法读取状态文件属性");return NO;
    }
    *exists=YES;
    if(!S_ISREG(info.st_mode)||info.st_size>8*1024*1024) {
        if(error)*error=timantirecall_storageError(@"状态文件类型或大小异常，未覆盖原文件");return NO;
    }
    return YES;
}
id timantirecall_readState(NSURL *url,NSError **error) {
    BOOL exists=NO;
    if(!timantirecall_regularURL(url,&exists,error)||!exists)return nil;
    NSData *data=[NSData dataWithContentsOfURL:url options:0 error:error];
    if(!data)return nil;
    id value=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error];
    if(![value isKindOfClass:NSDictionary.class]) {
        if(error && !*error)*error=timantirecall_storageError(@"状态文件格式异常，未覆盖原文件");return nil;
    }
    return value;
}
BOOL timantirecall_writeState(NSDictionary *value,NSURL *url,NSError **error) {
    BOOL exists=NO;
    if(!timantirecall_regularURL(url,&exists,error))return NO;
    NSURL *parent=url.URLByDeletingLastPathComponent;
    NSFileManager *fm=NSFileManager.defaultManager;
    if(![fm createDirectoryAtURL:parent withIntermediateDirectories:YES
                     attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;
    NSDictionary *attrs=[fm attributesOfItemAtPath:parent.path error:error];
    if(![attrs[NSFileType] isEqual:NSFileTypeDirectory]) {
        if(error)*error=timantirecall_storageError(@"状态目录不安全，未写入");return NO;
    }
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if(!data || data.length>8*1024*1024){if(error && !*error)*error=timantirecall_storageError(@"状态数据超出限制");return NO;}
    NSDataWritingOptions options=NSDataWritingAtomic;
#if TARGET_OS_IPHONE
    options|=NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication;
#endif
    if(![data writeToURL:url options:options error:error])return NO;
    // The container is private; also exclude metadata from cloud/device backup.
    [fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:url.path error:NULL];
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
    return YES;
}
BOOL timantirecall_removeState(NSURL *url,NSError **error) {
    BOOL exists=NO;
    if(!timantirecall_regularURL(url,&exists,error))return NO;
    return !exists || [NSFileManager.defaultManager removeItemAtURL:url error:error];
}
