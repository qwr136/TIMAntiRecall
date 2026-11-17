#include "TIMAntiRecallBootstrap.h"
#include <errno.h>
#include <fcntl.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>

#define TIMANTIRECALL_BOOTSTRAP_LIMIT (128U * 1024U)
static atomic_uint timantirecall_bootstrapEvents = 0;

void timantirecall_bootstrapSafeValue(const char *input, char *output, size_t capacity) {
    if (!output || !capacity) return;
    size_t used = 0;
    if (!input) input = "missing";
    while (*input && used + 1 < capacity) {
        unsigned char c = (unsigned char)*input++;
        output[used++] = ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                         (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_' ||
                         c == ':' || c == '=' || c == ' ') ? (char)c : '_';
    }
    output[used] = 0;
}

static int timantirecall_bootstrapDirectory(int parent, const char *name) {
    if (mkdirat(parent, name, 0700) != 0 && errno != EEXIST) return -1;
    return openat(parent, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
}

static bool timantirecall_bootstrapAppend(int directory, const char *name, const char *line, size_t size) {
    int file = openat(directory, name, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0600);
    if (file < 0) return false;
    struct stat info;
    bool valid = fstat(file, &info) == 0 && S_ISREG(info.st_mode) && info.st_nlink == 1 &&
                 info.st_uid == geteuid() && info.st_size >= 0 && (uint64_t)info.st_size <= TIMANTIRECALL_BOOTSTRAP_LIMIT;
    if (valid) valid = lseek(file, 0, SEEK_END) >= 0;
    if (valid) {
        ssize_t result;
        do { result = write(file, line, size); } while (result < 0 && errno == EINTR);
        valid = result == (ssize_t)size;
    }
    close(file);
    return valid;
}

bool timantirecall_bootstrapWrite(const char *home, const char *temporary, const char *event) {
    char safe[384], line[512];
    timantirecall_bootstrapSafeValue(event, safe, sizeof(safe));
    int count = snprintf(line, sizeof(line), "time=%lld pid=%ld %s\n", (long long)time(NULL), (long)getpid(), safe);
    if (count <= 0 || (size_t)count >= sizeof(line)) return false;
    if (home && home[0] == '/') {
        int root = open(home, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (root >= 0) {
            int documents = timantirecall_bootstrapDirectory(root, "Documents");
            if (documents >= 0) {
                int own = timantirecall_bootstrapDirectory(documents, "TIMAntiRecall");
                if (own >= 0) {
                    bool result = timantirecall_bootstrapAppend(own, "TIMAntiRecall-bootstrap.log", line, (size_t)count);
                    close(own);
                    if (result) { close(documents); close(root); return true; }
                }
                close(documents);
            }
            close(root);
        }
    }
    // A different filename in the process temporary directory identifies fallback.
    // Never use a global /tmp fallback on the phone and never log a home path.
    if (temporary && temporary[0] == '/') {
        int directory = open(temporary, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (directory >= 0) {
            bool result = timantirecall_bootstrapAppend(directory, "TIMAntiRecall-bootstrap.log", line, (size_t)count);
            close(directory);
            return result;
        }
    }
    return false;
}

bool timantirecall_bootstrapEvent(const char *event) {
    if (atomic_fetch_add_explicit(&timantirecall_bootstrapEvents, 1, memory_order_relaxed) >= 96) return false;
    bool result = timantirecall_bootstrapWrite(getenv("HOME"), getenv("TMPDIR"), event);
    if (!result) {
        char safe[384];
        timantirecall_bootstrapSafeValue(event, safe, sizeof(safe));
        syslog(LOG_NOTICE, "TIMAntiRecall bootstrap-event=%s file-write=failed", safe);
    }
    return result;
}
