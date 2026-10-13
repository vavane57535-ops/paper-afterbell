"""Paper Afterbell 0.16 - alarme de l'ouverture de la sortie (synthèse, numpy seul).

exit_alarm_00.wav : ouverture (coup sourd + sonnerie électrique d'école + sirène montante, ~3,6 s)
exit_alarm_01.wav : dernier appel (sirène qui monte et sonnerie en crescendo, 1,85 s,
                    calé sur la coupure de exit_rush.ogg à 59,97 s)
Usage : python3 exit_alarm_build.py <dossier de sortie>
"""
import sys, os, wave, subprocess, re
import numpy as np

SR = 44100
rng = np.random.default_rng(1793)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def fft_convolve(a, b):
    n = len(a) + len(b) - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, size) * np.fft.rfft(b, size), size)[:n]


def one_pole_lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def bandpass_fft(x, low, high, slope=6.0):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    gain = 1.0 / np.sqrt(1.0 + (low / np.maximum(f, 1.0)) ** (2 * slope / 6.0)) / np.sqrt(1.0 + (f / high) ** (2 * slope / 6.0))
    return np.fft.irfft(spec * gain, len(x))


# ---------------------------------------------------------------- sonnerie électrique
BELL_PARTIALS = [  # fréquence (Hz), amplitude, durée de résonance T60 (s)
    (1046.0, 1.00, 1.5), (1693.0, 0.58, 1.0), (2489.0, 0.46, 0.75),
    (3412.0, 0.30, 0.55), (4475.0, 0.19, 0.38), (5720.0, 0.11, 0.26), (7040.0, 0.06, 0.18),
]


def bell_ir(seconds=1.6, detune=1.0):
    t = t_axis(seconds)
    ir = np.zeros_like(t)
    for freq, amp, t60 in BELL_PARTIALS:
        tau = t60 / 6.91
        phase = rng.uniform(0, 2 * np.pi)
        # deux modes très proches par partiel : le battement typique des cloches
        for split, share in ((1.0, 0.62), (1.0028, 0.38)):
            ir += amp * share * np.exp(-t / tau) * np.sin(2 * np.pi * freq * detune * split * t + phase)
    return ir


def electric_bell(seconds, rate=21.0, strength=None, start=0.0):
    """Marteau qui frappe le timbre ~21 fois par seconde."""
    n = int(seconds * SR)
    exc = np.zeros(n)
    t = start
    k = 0
    while t < seconds:
        idx = int(t * SR)
        level = 1.0 if strength is None else float(strength(t))
        level *= rng.uniform(0.82, 1.0)
        click = rng.normal(0, 1, 24) * np.exp(-np.arange(24) / 5.0)
        exc[idx:idx + 24] += click[: max(0, min(24, n - idx))] * level
        t += (1.0 / rate) * rng.uniform(0.965, 1.035)
        k += 1
    ring = fft_convolve(exc, bell_ir())[:n] * 0.06
    # le cliquetis mécanique du marteau
    buzz = bandpass_fft(exc, 1800.0, 9000.0) * 0.05
    return ring + buzz


# ---------------------------------------------------------------- sirène
def siren(freq_curve, seconds, roughness=0.05):
    t = t_axis(seconds)
    f = freq_curve(t)
    f = f * (1.0 + 0.004 * np.sin(2 * np.pi * 5.3 * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros_like(t)
    for n in range(1, 16):
        weight = 1.0 / n ** 1.25 * (1.0 if n % 2 else 0.55)
        alias = np.clip((9500.0 - n * f) / 1500.0, 0.0, 1.0)
        out += weight * alias * np.sin(n * phase + n * 0.7)
    # hachure du rotor
    chop = 1.0 - roughness + roughness * np.sin(phase * 0.125)
    air = bandpass_fft(rng.normal(0, 1, len(t)), 600.0, 5000.0) * 0.04
    return (out * chop) / 2.2 + air * np.clip(f / 1000.0, 0.2, 1.0)


# ---------------------------------------------------------------- coup sourd d'ouverture
def boom(seconds=2.6):
    t = t_axis(seconds)
    f = 30.0 + 34.0 * np.exp(-t / 0.35)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.75) * (1 - np.exp(-t / 0.004))
    body = np.sin(2 * np.pi * 96.0 * t) * np.exp(-t / 0.16) * 0.5
    thump = one_pole_lowpass(rng.normal(0, 1, len(t)) * np.exp(-t / 0.03), 420.0) * 2.4
    slam = bandpass_fft(rng.normal(0, 1, len(t)) * np.exp(-t / 0.012), 1500.0, 5200.0) * 0.6
    return np.tanh(1.3 * (sub * 0.95 + body + thump)) * 0.9 + slam


# ---------------------------------------------------------------- réverbération de couloir
def corridor_ir(seconds=2.2, rt60=1.7, seed=0):
    local = np.random.default_rng(seed)
    t = t_axis(seconds)
    noise = local.normal(0, 1, len(t))
    dark = one_pole_lowpass(noise, 5200.0) * 0.6 + one_pole_lowpass(noise, 1600.0) * 0.4
    ir = dark * np.exp(-t * 6.91 / rt60)
    ir[: int(0.018 * SR)] = 0.0
    for delay, gain in ((0.011, 0.5), (0.017, 0.38), (0.026, 0.3), (0.037, 0.22), (0.049, 0.16)):
        ir[int((delay + local.uniform(-0.002, 0.002)) * SR)] += gain * 6.0
    return ir / np.sqrt(np.sum(ir ** 2))


def reverb(dry, wet_gain, rt60=1.7):
    left = fft_convolve(dry, corridor_ir(rt60=rt60, seed=11))
    right = fft_convolve(dry, corridor_ir(rt60=rt60, seed=29))
    pad = len(left) - len(dry)
    d = np.concatenate([dry, np.zeros(pad)])
    return np.stack([d + left * wet_gain, d + right * wet_gain], axis=1)


def pan(mono, position):
    angle = (position + 1.0) * np.pi / 4.0
    return np.stack([mono * np.cos(angle), mono * np.sin(angle)], axis=1)


def fit(stereo, seconds):
    n = int(seconds * SR)
    if len(stereo) >= n: return stereo[:n]
    return np.concatenate([stereo, np.zeros((n - len(stereo), 2))])


def write_wav(path, stereo):
    data = np.clip(stereo, -1.0, 1.0)
    pcm = (data * 32767.0).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def loudness(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true:framelog=quiet", "-f", "null", "-"], capture_output=True, text=True).stderr
    summary = out[out.rfind("Summary:"):]
    return float(re.search(r"I:\s+(-?[\d.]+) LUFS", summary).group(1)), float(re.search(r"Peak:\s+(-?[\d.]+) dBFS", summary).group(1))


def master(path, stereo, target_lufs, ceiling_db=-1.0):
    write_wav(path, stereo * 0.25)
    level, _ = loudness(path)
    stereo = stereo * 0.25 * 10 ** ((target_lufs - level) / 20.0)
    ceiling = 10 ** (ceiling_db / 20.0)
    peak = np.max(np.abs(stereo))
    if peak > ceiling * 0.85:
        knee = ceiling * 0.85
        over = np.abs(stereo) > knee
        stereo[over] = np.sign(stereo[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(stereo[over]) - knee) / (ceiling - knee)))
    write_wav(path, stereo)
    return loudness(path)


def fades(stereo, fade_in=0.002, fade_out=0.08):
    n = len(stereo)
    env = np.ones(n)
    a = int(fade_in * SR); b = int(fade_out * SR)
    if a: env[:a] = np.linspace(0, 1, a)
    if b: env[n - b:] = np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return stereo * env[:, None]


def opening_alarm():
    length = 3.6
    t = t_axis(length)
    # sonnerie : attaque franche, tenue 2,6 s puis relâchement du marteau (la cloche sonne encore)
    bell = electric_bell(2.75, start=0.04)
    bell = np.concatenate([bell, np.zeros(len(t) - len(bell))])
    # sirène : monte de 330 à 960 Hz, tient, puis retombe
    def curve(x):
        rise = 330.0 + 630.0 * (1.0 - np.exp(-np.maximum(x - 0.15, 0.0) / 0.55))
        fall = np.clip((x - 2.55) / 1.0, 0.0, 1.0)
        return rise * (1.0 - 0.42 * fall ** 1.6)
    wail = siren(curve, length)
    wail_env = np.clip((t - 0.12) / 0.35, 0.0, 1.0) * np.clip((3.55 - t) / 0.9, 0.0, 1.0)
    wail2 = siren(lambda x: curve(x) * 1.189, length) * 0.55  # tierce mineure : la dissonance d'alarme
    sirens = (wail + wail2) * wail_env * 0.42
    hit = boom()
    hit = np.concatenate([hit, np.zeros(len(t) - len(hit))])[: len(t)]
    mix = reverb(bell * 3.0, 0.42)[: len(t)]
    mix = mix + reverb(sirens, 0.32)[: len(t)] * np.array([0.92, 1.0])
    mix = mix + pan(hit, 0.0) * 1.15
    return fades(fit(mix, length), 0.001, 0.25)


def final_call():
    length = 1.85
    t = t_axis(length)
    grow = lambda x: 0.35 + 0.65 * np.clip(x / 1.7, 0.0, 1.0) ** 1.5
    bell = electric_bell(length, rate=23.0, strength=grow, start=0.0)[: len(t)]
    curve = lambda x: 300.0 * (1150.0 / 300.0) ** np.clip(x / 1.78, 0.0, 1.0) ** 1.35
    sirens = (siren(curve, length) + siren(lambda x: curve(x) * 1.189, length) * 0.55) * np.clip(t / 0.12, 0.0, 1.0)
    swell = bandpass_fft(rng.normal(0, 1, len(t)), 300.0, 7000.0) * (np.clip(t / 1.8, 0.0, 1.0) ** 3) * 0.28
    mix = reverb(bell * 2.6 * grow(t), 0.35)[: len(t)] + reverb(sirens * 0.45 * (0.55 + 0.45 * t / length), 0.25)[: len(t)] + pan(swell, 0.0)
    return fades(fit(mix, length), 0.003, 0.012)


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    for name, sound, target in (("exit_alarm_00.wav", opening_alarm(), -15.0), ("exit_alarm_01.wav", final_call(), -15.0)):
        path = os.path.join(out_dir, name)
        level, peak = master(path, sound, target)
        print(name, "LUFS", level, "peak", peak, "seconds", round(len(sound) / SR, 3))
