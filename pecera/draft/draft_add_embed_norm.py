# Adds the target's token_embd_norm.weight to an Inkling-2-Mini DFlash2 draft GGUF.
# Upstream's converter (#33073) writes it from the target's model.llm.embed_norm.weight; the community GGUF was made
# for a patched build that applied the target's norm at runtime, so upstream llama.cpp runs it without the norm.
# usage: python draft_add_embed_norm.py <draft.gguf> <target.gguf> <out.gguf>
import sys
import numpy as np
from gguf import GGUFReader, GGUFWriter, GGUFValueType

draft_path, target_path, out_path = sys.argv[1:4]
d = GGUFReader(draft_path)
t = GGUFReader(target_path)
norm = next(x for x in t.tensors if x.name == 'token_embd_norm.weight')
norm_data = np.array(norm.data, dtype=np.float32).reshape(-1)
assert norm_data.shape == (2304,), norm_data.shape
assert not any(x.name == 'token_embd_norm.weight' for x in d.tensors), 'draft already has token_embd_norm'

arch = d.fields['general.architecture'].contents()
w = GGUFWriter(out_path, arch)
for name, field in d.fields.items():
    if name.startswith('GGUF.') or name == 'general.architecture':
        continue
    vtype = field.types[0]
    sub = field.types[-1] if vtype == GGUFValueType.ARRAY else None
    w.add_key_value(name, field.contents(), vtype, sub_type=sub)
for x in d.tensors:
    w.add_tensor_info(x.name, x.data.shape, x.data.dtype, x.data.nbytes, x.tensor_type)
w.add_tensor_info('token_embd_norm.weight', norm_data.shape, norm_data.dtype, norm_data.nbytes)
w.write_header_to_file()
w.write_kv_data_to_file()
w.write_ti_data_to_file()
for x in d.tensors:
    w.write_tensor_data(x.data)
w.write_tensor_data(norm_data)
w.close()

# check
o = GGUFReader(out_path)
assert len(o.tensors) == len(d.tensors) + 1
for a, b in zip(d.tensors, o.tensors):
    assert a.name == b.name and a.tensor_type == b.tensor_type and np.array_equal(np.asarray(a.data), np.asarray(b.data)), a.name
assert np.array_equal(np.asarray(o.tensors[-1].data).reshape(-1), norm_data)
assert len([f for f in o.fields if not f.startswith('GGUF.')]) == len([f for f in d.fields if not f.startswith('GGUF.')])
print('ok', out_path, len(o.tensors), 'tensors', 'norm mean', float(norm_data.mean()))
