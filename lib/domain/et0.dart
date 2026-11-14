import 'dart:math';

import '../data/nasa_power_repository.dart';

/// FAO-56 (Allen et al. 1998) reference evapotranspiration. Symbols follow the paper.
/// Units: temperature deg C, pressure/vapour pressure kPa, radiation MJ m-2 day-1, wind m/s, ET0 mm/day.

/// Saturation vapour pressure e0(T), FAO-56 eq. 11.
double saturationVapourPressure(double t) =>
    0.6108 * exp(17.27 * t / (t + 237.3));

/// Slope of the saturation vapour pressure curve, FAO-56 eq. 13.
double vapourPressureSlope(double t) =>
    4098 * saturationVapourPressure(t) / pow(t + 237.3, 2);

/// Atmospheric pressure from elevation z (m), FAO-56 eq. 7.
double pressureFromElevation(double z) =>
    101.3 * pow((293 - 0.0065 * z) / 293, 5.26);

/// Extra-terrestrial radiation Ra (MJ m-2 day-1), FAO-56 eq. 21-25.
double extraterrestrialRadiation(double latDeg, int doy) {
  final phi = latDeg * pi / 180;
  final dr = 1 + 0.033 * cos(2 * pi / 365 * doy);
  final delta = 0.409 * sin(2 * pi / 365 * doy - 1.39);
  final ws = acos((-tan(phi) * tan(delta)).clamp(-1.0, 1.0));
  return 24 *
      60 /
      pi *
      0.0820 *
      dr *
      (ws * sin(phi) * sin(delta) + cos(phi) * cos(delta) * sin(ws));
}

/// Daylight hours N, FAO-56 eq. 34 (used by Hargreaves only through Ra).
const _sigma = 4.903e-9; // Stefan-Boltzmann, MJ K-4 m-2 day-1

/// FAO-56 Penman-Monteith, daily time step, soil heat flux G = 0 (eq. 6 with eq. 19, 21, 37-40).
/// [rhMean] is the mean relative humidity (%), [rs] the incoming solar radiation (MJ m-2 day-1).
double et0PenmanMonteith({
  required double tmax,
  required double tmin,
  required double rhMean,
  required double u2,
  required double rs,
  required double latDeg,
  required double elev,
  required int doy,
}) {
  final tmean = (tmax + tmin) / 2;
  final pressure = pressureFromElevation(elev);
  final gamma = 0.000665 * pressure;
  final delta = vapourPressureSlope(tmean);
  final es =
      (saturationVapourPressure(tmax) + saturationVapourPressure(tmin)) / 2;
  final ea = (rhMean.clamp(0, 100)) / 100 * es;

  final ra = extraterrestrialRadiation(latDeg, doy);
  final rso = (0.75 + 2e-5 * elev) * ra;
  final rns = (1 - 0.23) * rs;
  final rel = rso <= 0 ? 0.5 : (rs / rso).clamp(0.3, 1.0);
  final rnl =
      _sigma *
      (pow(tmax + 273.16, 4) + pow(tmin + 273.16, 4)) /
      2 *
      (0.34 - 0.14 * sqrt(ea)) *
      (1.35 * rel - 0.35);
  final rn = rns - rnl;

  final num = 0.408 * delta * rn + gamma * 900 / (tmean + 273) * u2 * (es - ea);
  final den = delta + gamma * (1 + 0.34 * u2);
  return max(0.0, num / den);
}

/// Hargreaves-Samani (1985), used only on days where radiation is missing.
double et0Hargreaves({
  required double tmax,
  required double tmin,
  required double latDeg,
  required int doy,
}) {
  final tmean = (tmax + tmin) / 2;
  final ra = extraterrestrialRadiation(latDeg, doy);
  return max(
    0.0,
    0.0023 * (tmean + 17.8) * sqrt(max(0.0, tmax - tmin)) * 0.408 * ra,
  );
}

class Et0Series {
  Et0Series(this.values, this.hargreavesDays, this.filledDays);
  final List<double> values;

  /// Days that used the Hargreaves fallback (radiation missing).
  final int hargreavesDays;

  /// Days where a missing input was carried forward from the previous day.
  final int filledDays;
}

/// Daily ET0 for one season. [tempAdd] shifts Tmax and Tmin (the "Warmer" what-if): ET0 depends on temperature
/// through a documented relationship, so this is the only way temperature enters the model.
Et0Series et0Season(
  SeasonSeries s, {
  required double lat,
  required double elev,
  double tempAdd = 0,
}) {
  final out = <double>[];
  var hg = 0, filled = 0;
  double? lastTmax, lastTmin, lastRh, lastWs;
  for (var i = 0; i < s.days; i++) {
    final d = s.dateAt(i);
    final doy = d.difference(DateTime.utc(d.year, 1, 1)).inDays + 1;
    var anyFill = false;
    double pick(double? v, double? last, double fallback) {
      if (v != null) return v;
      anyFill = true;
      return last ?? fallback;
    }

    final tmax = pick(s.tmax[i], lastTmax, 25) + tempAdd;
    final tmin = pick(s.tmin[i], lastTmin, 10) + tempAdd;
    final rh = pick(s.rh[i], lastRh, 60);
    final ws = pick(s.ws[i], lastWs, 2);
    lastTmax = s.tmax[i] ?? lastTmax;
    lastTmin = s.tmin[i] ?? lastTmin;
    lastRh = s.rh[i] ?? lastRh;
    lastWs = s.ws[i] ?? lastWs;
    if (anyFill) filled++;
    final rad = s.rad[i];
    if (rad == null) {
      hg++;
      out.add(et0Hargreaves(tmax: tmax, tmin: tmin, latDeg: lat, doy: doy));
    } else {
      out.add(
        et0PenmanMonteith(
          tmax: tmax,
          tmin: tmin,
          rhMean: rh,
          u2: ws,
          rs: rad,
          latDeg: lat,
          elev: elev,
          doy: doy,
        ),
      );
    }
  }
  return Et0Series(out, hg, filled);
}
