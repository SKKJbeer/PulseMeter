"""Gewichte (BatchNorm eingerechnet) in eine flache Binärdatei, dazu Referenzwerte für Swift und JavaScript."""
import sys, json, struct, numpy as np, torch
from train import Net
import lcdsynth as L

def fold(conv_w, bn):
    g = bn.weight.detach() / torch.sqrt(bn.running_var + bn.eps)
    w = conv_w.detach() * g.reshape(-1, *([1] * (conv_w.dim() - 1)))
    b = bn.bias.detach() - bn.running_mean * g
    return w.numpy().astype(np.float32), b.numpy().astype(np.float32)

def tensors(net):
    c = net.cnn; out = []
    for i in (0, 4, 8, 12):           # Conv, BN, ReLU, Pool je Block
        w, b = fold(c[i].weight, c[i + 1]); out += [w, b]
    w, b = fold(net.collapse[0].weight, net.collapse[1]); out += [w, b]
    for i in (0, 3):
        w, b = fold(net.seq[i].weight, net.seq[i + 1]); out += [w, b]
    out += [net.seq[6].weight.detach().numpy().astype(np.float32), net.seq[6].bias.detach().numpy().astype(np.float32)]
    return out

def write_bin(ts, path):
    with open(path, 'wb') as f:
        f.write(b'ZNW1'); f.write(struct.pack('<i', len(ts)))
        for t in ts:
            f.write(struct.pack('<i', t.ndim)); f.write(struct.pack('<%di' % t.ndim, *t.shape)); f.write(t.astype('<f4').tobytes())

def forward_np(ts, x):
    """Rechnet das Netz mit den eingerechneten Gewichten nach — dieselbe Reihenfolge wie Swift und JavaScript."""
    import torch.nn.functional as F
    x = torch.tensor(x, dtype=torch.float32)[None, None] / 255
    m = x.mean(); s = x.std() + 0.02; x = (x - m) / s
    T = [torch.tensor(t) for t in ts]
    x = F.relu(F.conv2d(x, T[0], T[1], padding=1)); x = F.max_pool2d(x, (2, 2))
    x = F.relu(F.conv2d(x, T[2], T[3], padding=1)); x = F.max_pool2d(x, (2, 1))
    x = F.relu(F.conv2d(x, T[4], T[5], padding=1)); x = F.max_pool2d(x, (2, 1))
    x = F.relu(F.conv2d(x, T[6], T[7], padding=1)); x = F.max_pool2d(x, (2, 1))
    x = F.relu(F.conv2d(x, T[8], T[9])).squeeze(2)
    x = F.relu(F.conv1d(x, T[10], T[11], padding=2)); x = F.relu(F.conv1d(x, T[12], T[13], padding=2))
    return F.conv1d(x, T[14], T[15])[0].numpy()          # C x T

if __name__ == '__main__':
    net = Net(); net.load_state_dict(torch.load(sys.argv[1])); net.eval()
    ts = tensors(net); write_bin(ts, sys.argv[2])
    print(sum(t.size for t in ts), 'Zahlen,', [t.shape for t in ts][:4])
    # Kontrolle: eingerechnet gleich Original
    import realtest as RT
    x, soll = RT.mitte('04', 2.0)
    a = forward_np(ts, x); b = net(torch.tensor(x, dtype=torch.float32)[None, None] / 255)[0].detach().numpy()
    print('größte Abweichung zum Original', float(np.abs(a - b).max()))
