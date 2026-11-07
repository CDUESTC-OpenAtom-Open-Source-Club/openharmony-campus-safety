"""Fetch the pinned Apache-2.0 Qwen3-0.6B/MNN export; resumable and hash checked.

Usage: python scripts/prepare-xiaoan-model.py [destination]
The upstream export includes tied quantized embeddings.
"""
import hashlib
import json
import pathlib
import sys
import shutil
import urllib.request

REVISION = '34dfccda1187ded6e07ea06426da576b0b793c6b'
BASE = f'https://huggingface.co/taobao-mnn/Qwen3-0.6B-MNN/resolve/{REVISION}/'
FILES = {
    'llm.mnn': ('d426c65a5159c938ccc237cdfbd982137f276804f27b414ca0ecf3fc0a660f8c', 461520),
    'llm.mnn.weight': ('953afb7e0165818add34a7a6caf0af5d0ed9428da102eb22c9b98ee9da292e9f', 450810338),
    'tokenizer.txt': ('77009625db0b18e74315dd89557c76feaab57e1d54e3240b442649a3c16ec4fb', 3193569),
}

def digest(path):
    with path.open('rb') as src:
        return hashlib.file_digest(src, 'sha256').hexdigest()

def main():
    args = [arg for arg in sys.argv[1:] if arg != '--bundle']
    target = pathlib.Path(args[0] if args else '.regression/models/qwen3-06')
    target.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, (expected, size) in FILES.items():
        path = target / name
        part = target / (name + '.part')
        if not path.exists():
            start = part.stat().st_size if part.exists() else 0
            request = urllib.request.Request(BASE + name, headers={'Range': f'bytes={start}-'} if start else {})
            with urllib.request.urlopen(request, timeout=90) as reply:
                resume = start > 0 and reply.status == 206
                with part.open('ab' if resume else 'wb') as output:
                    while chunk := reply.read(1024 * 1024):
                        output.write(chunk)
            if part.stat().st_size != size:
                raise ValueError(f'{name}: unexpected length')
            if expected and digest(part) != expected:
                raise ValueError(f'{name}: checksum mismatch')
            part.replace(path)
        actual = digest(path)
        if path.stat().st_size != size or (expected and actual != expected):
            raise ValueError(f'{name}: integrity check failed')
        manifest[name] = {'sha256': actual, 'size': size}
        print(name, actual, flush=True)
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    (target / 'llm_config.json').write_text(json.dumps({
        'hidden_size': 1024, 'layer_nums': 28, 'attention_mask': 'float',
        'key_value_shape': [2, 1, 0, 8, 128], 'is_visual': False,
        'prompt_template': '<|im_start|>user\n%s<|im_end|>\n<|im_start|>assistant\n',
        'tie_embeddings': [275780066, 431362530, 19447808, 8, 64]
    }), encoding='utf-8')
    (target / 'config.json').write_text(json.dumps({
        'llm_model': 'llm.mnn', 'llm_weight': 'llm.mnn.weight',
        'backend_type': 'cpu', 'thread_num': 4, 'precision': 'low', 'memory': 'low',
        'max_new_tokens': 192, 'max_all_tokens': 4096, 'reuse_kv': False, 'sampler_type': 'greedy'
    }), encoding='utf-8')
    if '--bundle' in sys.argv:
        destination = pathlib.Path(__file__).resolve().parent.parent / 'entry/src/main/resources/rawfile/xiaoan'
        destination.mkdir(parents=True, exist_ok=True)
        for name in [*FILES, 'config.json', 'llm_config.json', 'manifest.json']:
            shutil.copy2(target / name, destination / name)
        licenses = pathlib.Path(__file__).resolve().parent.parent / 'third_party/xiaoan'
        texts = ['校安通 · 小安第三方许可\n', (licenses / 'NOTICE.md').read_text(encoding='utf-8')]
        for license_file in sorted(licenses.glob('LICENSE-*.txt')):
            texts += ['\n\n' + license_file.name + '\n', license_file.read_text(encoding='utf-8')]
        (destination.parent / 'xiaoan_licenses.txt').write_text('\n'.join(texts), encoding='utf-8')
        print('Verified model files copied into the app resources.', flush=True)

if __name__ == '__main__':
    main()
