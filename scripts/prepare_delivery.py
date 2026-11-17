#!/usr/bin/env python3
"""Keep dual-arch build evidence; deliver only genuine arm64 bytes to TrollFools."""
import argparse
import json
from pathlib import Path
from build_contract import require
from verify_dylib import validate_bytes, validate_file

def prepare(project, version):
    root=Path(project).resolve()
    path=root/'reports/universal/TIMAntiRecall.dylib'
    data=path.read_bytes()
    internal=validate_bytes(data,version,layout='universal')
    selected=internal['slices']['arm64']
    # Exact byte slice extraction only; no CPU-header rewriting or binary patch.
    output=root/'dist/TIMAntiRecall.dylib'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(data[selected['offset']:selected['offset']+selected['size']])
    artifact=validate_file(output,root,'trollfools',version)
    require(artifact['sha256']==selected['sha256'], 'delivery is not the exact compiled arm64 slice')
    record={'internal':internal,'artifact':artifact,'selected_architecture':'arm64',
        'method':'exact-byte-slice-extraction','source':'reports/universal/TIMAntiRecall.dylib'}
    report=root/'reports/delivery-selection.json'
    report.write_text(json.dumps(record,indent=2)+'\n')
    print('PASS real arm64 delivery matches compiled and signed universal slice; no subtype rewriting')
    return record

def verify_selection(project, version):
    root=Path(project).resolve()
    data=(root/'reports/universal/TIMAntiRecall.dylib').read_bytes()
    internal=validate_bytes(data,version,layout='universal')
    artifact=validate_file(root/'dist/TIMAntiRecall.dylib',root,'trollfools',version)
    selected=internal['slices']['arm64']
    final=artifact['slices']['arm64']
    require(artifact['sha256']==selected['sha256'] and
            final['uuid']==selected['uuid'] and final['initializers']==selected['initializers'],
            'delivery does not match exact compiled arm64 code/signature/constructor')
    actual={'internal':internal,'artifact':artifact,'selected_architecture':'arm64',
        'method':'exact-byte-slice-extraction','source':'reports/universal/TIMAntiRecall.dylib'}
    report=json.loads((root/'reports/delivery-selection.json').read_text())
    require(report==actual, 'selection report differs from actual internal or delivery bytes')
    return actual

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',default='.')
    parser.add_argument('--version',required=True)
    args=parser.parse_args()
    prepare(args.project,args.version)
