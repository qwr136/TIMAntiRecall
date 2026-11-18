#include "TIMAntiRecallWire.h"
#include <stdbool.h>

#define TIMANTIRECALL_MAX_PACKET (2U * 1024U * 1024U)
#define TIMANTIRECALL_MAX_FIELDS 4096U

typedef struct {
    const uint8_t *bytes;
    size_t length;
} TIMAntiRecallSpan;

typedef struct {
    unsigned number;
    unsigned wire;
    uint64_t integer;
    TIMAntiRecallSpan span;
} TIMAntiRecallField;

static bool timantirecall_varint(TIMAntiRecallSpan input, size_t *position, uint64_t *value) {
    uint64_t result = 0;
    for (unsigned index = 0; index < 10; index++) {
        if (*position >= input.length) return false;
        uint8_t byte = input.bytes[(*position)++];
        if (index == 9 && byte > 1) return false;
        result |= (uint64_t)(byte & 0x7f) << (index * 7);
        if (!(byte & 0x80)) { *value = result; return true; }
    }
    return false;
}

static bool timantirecall_next(TIMAntiRecallSpan input, size_t *position, TIMAntiRecallField *field) {
    uint64_t key = 0, length = 0;
    if (!timantirecall_varint(input, position, &key) || key < 8 || (key >> 3) > 0x1fffffffU) return false;
    *field = (TIMAntiRecallField){ .number = (unsigned)(key >> 3), .wire = (unsigned)(key & 7) };
    switch (field->wire) {
        case 0: return timantirecall_varint(input, position, &field->integer);
        case 1: length = 8; break;
        case 2: if (!timantirecall_varint(input, position, &length)) return false; break;
        case 5: length = 4; break;
        default: return false;
    }
    if (length > input.length - *position) return false;
    field->span = (TIMAntiRecallSpan){ input.bytes + *position, (size_t)length };
    *position += (size_t)length;
    return true;
}

// Scan the entire message even after finding the requested field, so truncated
// suffixes, duplicate selected fields and mismatched wire types cannot be blocked.
static bool timantirecall_field(TIMAntiRecallSpan input, unsigned number, unsigned wire,
                                TIMAntiRecallField *result) {
    size_t position = 0; unsigned count = 0; bool found = false;
    while (position < input.length) {
        TIMAntiRecallField field;
        if (++count > TIMANTIRECALL_MAX_FIELDS || !timantirecall_next(input, &position, &field)) return false;
        if (field.number == number) {
            if (found || field.wire != wire) return false;
            *result = field; found = true;
        }
    }
    return found;
}

static bool timantirecall_span(TIMAntiRecallSpan input, unsigned number, TIMAntiRecallSpan *output) {
    TIMAntiRecallField field;
    if (!timantirecall_field(input, number, 2, &field) || field.span.length == 0) return false;
    *output = field.span; return true;
}

static bool timantirecall_number(TIMAntiRecallSpan input, unsigned number, uint64_t *output) {
    TIMAntiRecallField field;
    if (!timantirecall_field(input, number, 0, &field)) return false;
    *output = field.integer; return true;
}

static bool timantirecall_privateRecall(TIMAntiRecallSpan content) {
    TIMAntiRecallSpan info, from, to; uint64_t sequence;
    return timantirecall_span(content, 1, &info) &&
           timantirecall_span(info, 1, &from) && from.length <= 128 &&
           timantirecall_span(info, 2, &to) && to.length <= 128 &&
           timantirecall_number(info, 20, &sequence) && sequence > 0;
}

static bool timantirecall_groupRecall(TIMAntiRecallSpan content) {
    if (content.length <= 7) return false;
    // The target worker skips 7 bytes before reading NotifyMsgBody. The 2-byte
    // big-endian length after group_uin(4)+flag(1) must describe the whole body.
    size_t declared = ((size_t)content.bytes[5] << 8) | content.bytes[6];
    if (declared != content.length - 7) return false;
    TIMAntiRecallSpan notify = { content.bytes + 7, content.length - 7 };
    TIMAntiRecallSpan recall; uint64_t type, group;
    if (!timantirecall_number(notify, 1, &type) || type != 7 ||
        !timantirecall_number(notify, 4, &group) || group == 0 ||
        !timantirecall_span(notify, 11, &recall)) return false;
    size_t position = 0; unsigned count = 0, messages = 0;
    while (position < recall.length) {
        TIMAntiRecallField field;
        if (++count > TIMANTIRECALL_MAX_FIELDS || !timantirecall_next(recall, &position, &field)) return false;
        if (field.number == 3) {
            uint64_t sequence;
            if (field.wire != 2 || !timantirecall_number(field.span, 1, &sequence) || !sequence) return false;
            messages++;
        }
    }
    return messages > 0;
}

TIMAntiRecallDecision timantirecall_classifyPush(const uint8_t *bytes, size_t length) {
    if (!bytes || !length || length > TIMANTIRECALL_MAX_PACKET) return TIMAntiRecallPass;
    TIMAntiRecallSpan input = { bytes, length }, message, head, body, content;
    uint64_t type, subtype;
    if (!timantirecall_span(input, 1, &message) ||
        !timantirecall_span(message, 2, &head) ||
        !timantirecall_number(head, 1, &type) ||
        !timantirecall_number(head, 2, &subtype) ||
        !timantirecall_span(message, 3, &body) ||
        !timantirecall_span(body, 2, &content)) return TIMAntiRecallPass;
    if (type == 0x210 && (subtype == 0x8a || subtype == 0x8b) &&
        timantirecall_privateRecall(content)) return TIMAntiRecallPrivate;
    if (type == 0x2dc && (subtype == 0x10 || subtype == 0x11) &&
        timantirecall_groupRecall(content)) return TIMAntiRecallGroup;
    return TIMAntiRecallPass;
}

static bool timantirecall_copyUID(TIMAntiRecallSpan input, unsigned number, char output[129]) {
    TIMAntiRecallSpan value;
    if (!timantirecall_span(input,number,&value) || value.length>128) return false;
    for (size_t i=0;i<value.length;i++) {
        uint8_t c=value.bytes[i];
        if (!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='_'||c=='-')) return false;
        output[i]=(char)c;
    }
    output[value.length]=0;
    return true;
}

static bool timantirecall_optionalNumber(TIMAntiRecallSpan input, unsigned number, uint64_t *value, unsigned *present) {
    size_t position=0; unsigned count=0; *present=0;
    while (position<input.length) {
        TIMAntiRecallField field;
        if (++count>TIMANTIRECALL_MAX_FIELDS || !timantirecall_next(input,&position,&field)) return false;
        if (field.number==number) {
            if (*present || field.wire!=0) return false;
            *present=1; *value=field.integer;
        }
    }
    return true;
}

size_t timantirecall_extractRecallEvents(const uint8_t *bytes, size_t length,
                                         TIMAntiRecallWireEvent *events, size_t capacity) {
    TIMAntiRecallDecision kind=timantirecall_classifyPush(bytes,length);
    if (kind==TIMAntiRecallPass || !events || !capacity) return 0;
    TIMAntiRecallSpan input={bytes,length},message,body,content;
    if (!timantirecall_span(input,1,&message)||!timantirecall_span(message,3,&body)||
        !timantirecall_span(body,2,&content)) return 0;
    if (kind==TIMAntiRecallPrivate) {
        TIMAntiRecallSpan info; TIMAntiRecallWireEvent event={0};event.kind=1;
        if (!timantirecall_span(content,1,&info)||!timantirecall_copyUID(info,1,event.from)||
            !timantirecall_copyUID(info,2,event.to)||!timantirecall_number(info,20,&event.sequence)) return 0;
        events[0]=event; return 1;
    }
    TIMAntiRecallSpan notify={content.bytes+7,content.length-7},recall;
    uint64_t group=0;
    if (!timantirecall_number(notify,4,&group)||!timantirecall_span(notify,11,&recall)) return 0;
    size_t position=0,used=0;
    while(position<recall.length) {
        TIMAntiRecallField field;
        if (!timantirecall_next(recall,&position,&field)) return 0;
        if (field.number!=3) continue;
        if (field.wire!=2 || used>=capacity) return 0;
        TIMAntiRecallWireEvent event={0};event.kind=2;event.group=group;
        if (!timantirecall_number(field.span,1,&event.sequence)||!event.sequence||
            !timantirecall_copyUID(field.span,6,event.author)||
            !timantirecall_optionalNumber(field.span,3,&event.random,&event.hasRandom)||
            !timantirecall_optionalNumber(field.span,2,&event.time,&event.hasTime)) return 0;
        events[used++]=event;
    }
    return used;
}
