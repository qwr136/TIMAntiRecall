#!/usr/bin/env python3
"""Strict standalone dylib inspection. Page hashes are NOT CMS trust or device acceptance.
Mach-O/signature parser adapted from CCPerspective; only the needed helpers are retained.
"""
import argparse
import hashlib
import json
import math
import struct
import sys
import uuid
from pathlib import Path

DYLIB_COMMANDS = {0xC, 0x80000018, 0x8000001F, 0x20, 0x80000023}


class ValidationError(ValueError):
    pass



def require(ok, message):
    if not ok:
        raise ValidationError(message)



def sha256(data):
    return hashlib.sha256(data).hexdigest()



def version_tuple(value):
    return (value >> 16, (value >> 8) & 255, value & 255)



def cstring(data, start, end):
    require(0 <= start < end <= len(data), "string offset out of range")
    stop = data.find(b"\0", start, end)
    require(stop > start, "missing/empty NUL-terminated string")
    return data[start:stop].decode("utf-8")



def signature(data, offset, size):
    require(size >= 20 and 0 < offset <= len(data) - size, "signature bounds invalid")
    sig = data[offset:offset + size]
    magic, length, count = struct.unpack_from(">III", sig)
    require(magic == 0xFADE0CC0 and 12 + 8 * count <= length <= len(sig)
            and 0 < count <= 64, "invalid signature SuperBlob")
    directories, ranges, slots = [], [], set()
    for index in range(count):
        slot, pos = struct.unpack_from(">II", sig, 12 + 8 * index)
        require(slot not in slots and 12 + 8 * count <= pos <= length - 8,
                "invalid signature index")
        slots.add(slot)
        kind, size = struct.unpack_from(">II", sig, pos)
        require(8 <= size <= length - pos, "signature child bounds invalid")
        require(not any(pos < end and start < pos + size for start, end in ranges),
                "overlapping signature children")
        ranges.append((pos, pos + size))
        if slot == 0 or 0x1000 <= slot <= 0x1005:
            require(kind == 0xFADE0C02 and size >= 44, "missing CodeDirectory")
            cd = sig[pos:pos + size]
            _, _, version, flags, hash_off, ident, special, pages, limit = struct.unpack_from(">9I", cd)
            hash_size, hash_type, _, page_power = struct.unpack_from("4B", cd, 36)
            require(0x20000 <= version <= 0x20600, "unsupported CodeDirectory version")
            minimum = 108 if version >= 0x20600 else 96 if version >= 0x20500 else 88 if version >= 0x20400 else 64 if version >= 0x20300 else 52 if version >= 0x20200 else 48 if version >= 0x20100 else 44
            require(size >= minimum, "truncated versioned CodeDirectory")
            if version >= 0x20100:
                require(struct.unpack_from(">I", cd, 44)[0] == 0, "scatter CodeDirectory unsupported")
            if version >= 0x20300:
                require(size >= 64, "truncated CodeDirectory v20300")
                large_limit = struct.unpack_from(">Q", cd, 56)[0]
                limit = large_limit or limit
            algorithms = {1: ("sha1", 20), 2: ("sha256", 32), 3: ("sha256", 20), 4: ("sha384", 48)}
            require(hash_type in algorithms and hash_size == algorithms[hash_type][1],
                    "unsupported CodeDirectory hash")
            require(0 <= page_power <= 20 and limit == offset, "CodeDirectory code limit/page invalid")
            page_size = (1 << page_power) if page_power else limit
            require(pages == math.ceil(limit / page_size) and pages > 0,
                    "CodeDirectory page count invalid")
            require(hash_off - special * hash_size >= minimum and hash_off + pages * hash_size <= size,
                    "CodeDirectory hash table out of bounds")
            require(ident >= minimum, "CodeDirectory identifier overlaps header")
            identifier = cstring(cd, ident, hash_off - special * hash_size)
            for page in range(pages):
                chunk = data[page * page_size:min((page + 1) * page_size, limit)]
                actual = hashlib.new(algorithms[hash_type][0], chunk).digest()[:hash_size]
                expected = cd[hash_off + page * hash_size:hash_off + (page + 1) * hash_size]
                require(actual == expected, "CodeDirectory code page hash mismatch")
            directories.append({"slot": slot, "identifier": identifier, "flags": flags,
                                "algorithm": algorithms[hash_type][0], "pages_verified": pages})
    require(not any(sig[length:]), "nonzero signature padding")
    require(0 in slots and directories, "signature lacks primary CodeDirectory")
    return {"offset": offset, "size": len(sig), "code_directories": directories,
            "cms_trust_verified": False, "special_slots_verified": False}



def parse_macho(data, cpu, subtype):
    require(len(data) >= 32 and data[:4] == b"\xcf\xfa\xed\xfe", "not a 64-bit LE Mach-O")
    _, inner_cpu, inner_sub, kind, count, cmd_bytes, flags, reserved = struct.unpack_from("<8I", data)
    require((inner_cpu, inner_sub) == (cpu, subtype), "FAT/inner CPU subtype mismatch")
    require(kind == 6 and not reserved and 0 < count <= cmd_bytes // 8
            and 32 + cmd_bytes <= len(data), "invalid Mach-O header/load command table")
    pos, end = 32, 32 + cmd_bytes
    dependencies, rpaths, identities, segments = [], [], [], []
    uuids, versions, symtabs, signatures, dysymtabs = [], [], [], [], []
    id_versions = []
    has_text = False
    for _ in range(count):
        require(pos + 8 <= end, "truncated load command")
        command, length = struct.unpack_from("<II", data, pos)
        require(length >= 8 and length % 8 == 0 and pos + length <= end,
                "invalid load command length")
        if command in DYLIB_COMMANDS | {0xD, 0x8000001C}:
            minimum = 12 if command == 0x8000001C else 24
            require(length >= minimum, "truncated dylib/rpath command")
            start = struct.unpack_from("<I", data, pos + 8)[0]
            require(minimum <= start < length, "invalid load command string offset")
            name = cstring(data, pos + start, pos + length)
            if command == 0xD:
                identities.append(name)
                id_versions.append(list(version_tuple(struct.unpack_from("<I", data, pos + 16)[0])))
            elif command == 0x8000001C:
                rpaths.append(name)
            else:
                dependencies.append({"name": name, "command": hex(command)})
        elif command == 0x19:
            require(length >= 72, "truncated LC_SEGMENT_64")
            name = data[pos + 8:pos + 24].split(b"\0", 1)[0].decode()
            fileoff, filesize = struct.unpack_from("<QQ", data, pos + 40)
            sections = struct.unpack_from("<I", data, pos + 64)[0]
            require(length == 72 + 80 * sections and fileoff + filesize <= len(data),
                    "segment/section bounds invalid")
            segments.append((name, fileoff, fileoff + filesize))
            for index in range(sections):
                sec = pos + 72 + index * 80
                secname = data[sec:sec + 16].split(b"\0", 1)[0]
                size = struct.unpack_from("<Q", data, sec + 40)[0]
                offset, align, reloff, nreloc, attributes = struct.unpack_from("<5I", data, sec + 48)
                require(align <= 31 and (not nreloc or reloff + nreloc * 8 <= len(data)),
                        "section alignment/relocation bounds invalid")
                if attributes & 255 not in (1, 0xC, 0x12) and size:
                    require(fileoff <= offset and offset + size <= fileoff + filesize,
                            "section outside file-backed segment")
                if name == "__TEXT" and secname == b"__text" and size:
                    require(offset >= end and offset + size <= len(data), "invalid __text section")
                    has_text = True
        elif command == 0x1B:
            require(length == 24, "invalid LC_UUID")
            uuids.append(str(uuid.UUID(bytes=data[pos + 8:pos + 24])))
        elif command == 0x32:
            require(length >= 24, "truncated LC_BUILD_VERSION")
            platform, minimum, sdk, tools = struct.unpack_from("<4I", data, pos + 8)
            require(length == 24 + 8 * tools and platform == 2, "not an iOS build version")
            versions.append((version_tuple(minimum), version_tuple(sdk)))
        elif command == 0x25:
            require(length == 16, "invalid LC_VERSION_MIN_IPHONEOS")
            minimum, sdk = struct.unpack_from("<II", data, pos + 8)
            versions.append((version_tuple(minimum), version_tuple(sdk)))
        elif command == 0x2:
            require(length == 24, "invalid LC_SYMTAB")
            symtabs.append(struct.unpack_from("<4I", data, pos + 8))
        elif command == 0xB:
            require(length == 80, "invalid LC_DYSYMTAB")
            dysymtabs.append(struct.unpack_from("<18I", data, pos + 8))
        elif command == 0x1D:
            require(length == 16, "invalid LC_CODE_SIGNATURE")
            signatures.append(struct.unpack_from("<II", data, pos + 8))
        pos += length
    require(pos == end and has_text and len(uuids) == 1 and len(set(uuids)) == 1,
            "missing __text/UUID or inconsistent sizeofcmds")
    require(len(identities) == (1 if kind == 6 else 0), "invalid LC_ID_DYLIB count")
    require(len(versions) == len(symtabs) == len(signatures) == len(dysymtabs) == 1,
            "missing/duplicate version, symtab, dysymtab or signature")
    require(versions[0][0] == (16, 5, 0) and versions[0][1] == (16, 4, 0),
            "Mach-O minos must be 16.5, locked SDK metadata must be 16.4")
    require(any(name == "__TEXT" and start == 0 and stop >= end for name, start, stop in segments),
            "load commands not covered by __TEXT")
    linkedit = [(start, stop) for name, start, stop in segments if name == "__LINKEDIT"]
    require(len(linkedit) == 1, "missing/duplicate __LINKEDIT")
    symoff, nsyms, stroff, strsize = symtabs[0]
    for start, size in ((symoff, nsyms * 16), (stroff, strsize), signatures[0]):
        require(linkedit[0][0] <= start and start + size <= linkedit[0][1],
                "symbols/signature outside __LINKEDIT")
    require(nsyms > 0 and strsize > 1, "empty LC_SYMTAB")
    undef_start, undef_count = dysymtabs[0][4:6]
    require(undef_count > 0 and undef_start + undef_count <= nsyms, "invalid undefined symbol range")
    imports = {}
    for index in range(nsyms):
        strx, ntype, _, desc, value = struct.unpack_from("<IBBHQ", data, symoff + index * 16)
        require(strx < strsize, "symbol string offset out of bounds")
        name = cstring(data, stroff + strx, stroff + strsize) if strx else ""
        is_import = not ntype & 0xE0 and ntype & 0x0E == 0 and ntype & 1 and value == 0
        if undef_start <= index < undef_start + undef_count:
            require(is_import and name, "LC_DYSYMTAB does not point at undefined externals")
        if is_import and name:
            require(undef_start <= index < undef_start + undef_count and name not in imports,
                    "undefined symbol outside range/duplicate")
            ordinal = desc >> 8
            require(ordinal <= len(dependencies) or ordinal in (0xFE, 0xFF), "invalid library ordinal")
            imports[name] = {"ordinal": ordinal, "weak": bool(desc & 0x40),
                             "library": dependencies[ordinal - 1]["name"]
                             if 0 < ordinal <= len(dependencies) else None}
    return {"filetype": kind, "cpu_subtype": hex(subtype), "flags": hex(flags),
            "uuid": uuids[0], "minos": list(versions[0][0]), "sdk": list(versions[0][1]),
            "id_dylib": identities, "id_versions": id_versions, "dependencies": dependencies, "rpaths": rpaths,
            "imports": imports, "signature": signature(data, *signatures[0])}



def parse_fat(blob):
    formats = {b"\xca\xfe\xba\xbe": (">", False), b"\xbe\xba\xfe\xca": ("<", False),
               b"\xca\xfe\xba\xbf": (">", True), b"\xbf\xba\xfe\xca": ("<", True)}
    require(len(blob) >= 8 and blob[:4] in formats, "expected a real FAT arm64/arm64e binary")
    endian, wide = formats[blob[:4]]
    count = struct.unpack_from(endian + "I", blob, 4)[0]
    step = 32 if wide else 20
    table_end = 8 + count * step
    require(count == 2 and table_end <= len(blob), "FAT must contain exactly two architectures")
    slices, ranges = {}, []
    for index in range(count):
        row = struct.unpack_from(endian + ("IIQQII" if wide else "5I"), blob, 8 + index * step)
        cpu, subtype, offset, size, align = row[:5]
        require(not wide or row[5] == 0, "FAT64 reserved must be zero")
        require(cpu == 0x100000C and subtype & 0xFFFFFF in (0, 2), "FAT architecture is not arm64/e")
        name = "arm64e" if subtype & 0xFFFFFF == 2 else "arm64"
        require(name not in slices, "duplicate FAT architecture")
        require(align <= 31 and offset >= table_end and offset % (1 << align) == 0
                and size >= 32 and offset + size <= len(blob), "FAT slice bounds/alignment invalid")
        require(not any(offset < end and start < offset + size for start, end in ranges),
                "overlapping FAT slices")
        data = blob[offset:offset + size]
        slices[name] = dict(parse_macho(data, cpu, subtype), offset=offset, size=size, sha256=sha256(data))
        ranges.append((offset, offset + size))
    require(set(slices) == {"arm64", "arm64e"}, "missing arm64/arm64e")
    return slices


def validate_bytes(blob, expected_version):
    from build_contract import version_tuple as expected_tuple
    expected = expected_tuple(expected_version)
    slices = parse_fat(blob)
    for arch, info in slices.items():
        names = [item['name'] for item in info['dependencies']]
        require(names and len(names) == len(set(names)), 'missing/duplicate dependencies')
        for name in names:
            require(name.startswith(('/System/Library/', '/usr/lib/')) and
                    '..' not in name.split('/') and '\\' not in name and
                    not any(token in name.lower() for token in ('substrate', 'roothide', 'libroot', 'ellekit')),
                    'non-Apple dependency: ' + name)
        require('/usr/lib/libSystem.B.dylib' in names and
                '/System/Library/Frameworks/Foundation.framework/Foundation' in names,
                'missing required Apple system dependency')
        require(not info['rpaths'], 'unexpected LC_RPATH')
        require(info['id_dylib'] == ['@rpath/TIMAntiRecall.dylib'], 'unexpected install name')
        require(info['id_versions'] == [expected], 'binary current_version differs from expected-version')
        require(all(item['library'] in names for item in info['imports'].values()),
                'flat/self/dynamic lookup import is not an Apple dependency')
    require(slices['arm64']['uuid'] != slices['arm64e']['uuid'], 'duplicated slice UUID')
    require(b'/var/jb/' not in blob and b'/Library/MobileSubstrate/' not in blob,
            'hardcoded jailbreak installation path')
    return {'sha256': sha256(blob), 'size': len(blob), 'slices': slices,
            'version': expected_version, 'signature_scope': 'all CodeDirectory code page hashes',
            'cms_trust_verified': False, 'device_loaded': False,
            'arm64e_instruction_semantics_verified': False}


def validate_file(path, project, scheme, expected_version):
    from build_contract import validate
    meta = validate(project)
    require(scheme == meta['scheme'], 'artifact scheme mismatch')
    path = Path(path)
    require(path.name == 'TIMAntiRecall.dylib' and path.is_file() and not path.is_symlink(),
            'artifact must be the regular TIMAntiRecall.dylib file')
    result = validate_bytes(path.read_bytes(), expected_version)
    return dict(result, filename=path.name, package=meta['package'], injection=scheme,
                bundle=meta['bundle'], executable=meta['executable'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dylib')
    parser.add_argument('--project', default='.')
    parser.add_argument('--scheme', required=True)
    parser.add_argument('--expected-version', required=True)
    parser.add_argument('--output')
    args = parser.parse_args()
    result = validate_file(args.dylib, args.project, args.scheme, args.expected_version)
    if args.output:
        from toolchain import write_json
        write_json(args.output, result)
    print('PASS actual dylib: arm64 + arm64e, Apple dependencies, CodeDirectory page hashes; device untested')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
        raise SystemExit('ERROR: ' + str(error))
