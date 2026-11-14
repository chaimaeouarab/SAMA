/// mulberry32: tiny deterministic PRNG, identical on every device.
class Mulberry32 {
  Mulberry32(int seed) : _a = seed & 0xFFFFFFFF;
  int _a;

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// Next value in [0, 1).
  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    t &= 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  int nextInt(int max) => (next() * max).floor();
}
