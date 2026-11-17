"""Synthetic verifier fixtures only; never executable/injectable release inputs."""
import hashlib
import math
import struct
import uuid

DEPS=['/usr/lib/libobjc.A.dylib','/System/Library/Frameworks/Foundation.framework/Foundation',
      '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation','/usr/lib/libSystem.B.dylib']
def aligned(n,a=8):return (n+a-1)//a*a

def string_command(cmd,name,version=0):
    raw=name.encode()+b'\0'; size=aligned(24+len(raw))
    return struct.pack('<6I',cmd,size,24,0,version,0)+raw+b'\0'*(size-24-len(raw))

def section(name,addr,size,offset,flags):
    return struct.pack('<16s16sQQ8I',name.encode(),b'__TEXT',addr,size,offset,2,0,0,flags,0,0,0)

def thin(subtype=0,version='0.40',init=True,init_value=2048,identity=None):
    major,minor=map(int,version.split('.')); encoded=major<<16|minor<<8
    textoff=2048; code_limit=4144; identifier=b'fixture\0'
    page_count=math.ceil(code_limit/4096); hash_off=44+len(identifier)
    sigsize=20+hash_off+page_count*32
    textsecs=section('__text',textoff,4,textoff,0x80000400)
    if init:textsecs+=section('__init_offsets',2052,4,2052,0x16)
    text=struct.pack('<II16sQQQQ4I',0x19,72+len(textsecs),b'__TEXT',0,4096,0,4096,7,5,len(textsecs)//80,0)+textsecs
    linkedit=struct.pack('<II16sQQQQ4I',0x19,72,b'__LINKEDIT',4096,4096,4096,code_limit+sigsize-4096,7,1,0,0)
    dylib=string_command(13,'@rpath/TIMAntiRecall.dylib',encoded)
    uid=uuid.UUID(identity or ('12345678-0000-4000-8000-000000000002' if subtype else '12345678-0000-4000-8000-000000000001'))
    symtab=struct.pack('<6I',2,24,4096,1,4112,7)
    ds=[0]*18;ds[5]=1
    commands=[text,linkedit,dylib,struct.pack('<II16s',0x1b,24,uid.bytes),
        struct.pack('<6I',0x32,24,2,16<<16|5<<8,16<<16|4<<8,0),symtab,
        struct.pack('<20I',11,80,*ds),*[string_command(12,n) for n in DEPS],
        struct.pack('<4I',0x1d,16,code_limit,sigsize)]
    joined=b''.join(commands)
    data=bytearray(code_limit)
    data[:32]=struct.pack('<8I',0xfeedfacf,0x100000c,subtype,6,len(commands),len(joined),0x85,0)
    data[32:32+len(joined)]=joined
    data[textoff:textoff+4]=b'\xc0\x03\x5f\xd6'
    data[2052:2056]=struct.pack('<I',init_value)
    data[4096:4112]=struct.pack('<IBBHQ',1,1,0,4<<8,0)
    data[4112:4119]=b'\0_exit\0'
    hashes=b''.join(hashlib.sha256(data[i*4096:min((i+1)*4096,code_limit)]).digest() for i in range(page_count))
    cd=struct.pack('>9I4B',0xfade0c02,hash_off+len(hashes),0x20000,2,hash_off,44,0,page_count,code_limit,32,2,0,12)+b'\0'*4+identifier+hashes
    data+=struct.pack('>5I',0xfade0cc0,20+len(cd),1,0,20)+cd
    assert len(data)==code_limit+sigsize
    return bytes(data)

def fat(first=None,second=None):
    first=first or thin();second=second or thin(0x80000002)
    a=4096;b=aligned(a+len(first),4096)
    data=bytearray(b+len(second))
    data[:8]=struct.pack('>2I',0xcafebabe,2)
    data[8:28]=struct.pack('>5I',0x100000c,0,a,len(first),12)
    data[28:48]=struct.pack('>5I',0x100000c,0x80000002,b,len(second),12)
    data[a:a+len(first)]=first;data[b:]=second
    return bytes(data)
