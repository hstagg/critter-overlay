extends RefCounted
## Day and night pacing (v2.0's src/time_of_day.py): six parts of the day,
## each with how lively the critters are, how often they arrive and how
## sleepy they get, blended over ten minutes at each boundary. Nothing
## visual changes.

# start hour, pace, arrival rate, sleepiness
const BUCKETS := [
	[5.0, 0.90, 0.80, 0.15],    # dawn       05:00 to 08:00
	[8.0, 1.10, 1.20, 0.05],    # morning    08:00 to 11:00
	[11.0, 1.00, 1.00, 0.10],   # midday     11:00 to 15:00
	[15.0, 1.00, 1.00, 0.10],   # afternoon  15:00 to 18:00
	[18.0, 0.80, 0.90, 0.45],   # evening    18:00 to 21:00
	[21.0, 0.50, 0.50, 0.85],   # night      21:00 to 05:00
]
const BLEND_H := 10.0 / 60.0


static func at(hour: float) -> Array:
	# [pace, arrival rate, sleepiness] at a local hour, 0 to 24.
	var n := BUCKETS.size()
	var idx := n - 1
	for i in n:
		var start: float = BUCKETS[i][0]
		var next: float = BUCKETS[(i + 1) % n][0] + (24.0 if i == n - 1 else 0.0)
		var h := hour + (24.0 if i == n - 1 and hour < BUCKETS[0][0] else 0.0)
		if h >= start and h < next:
			idx = i
			break
	var cur: Array = BUCKETS[idx]
	var nxt: Array = BUCKETS[(idx + 1) % n]
	var end: float = nxt[0] + (24.0 if idx == n - 1 else 0.0)
	var hh := hour + (24.0 if idx == n - 1 and hour < BUCKETS[0][0] else 0.0)
	# In the last ten minutes before the next part of the day, blend into it.
	var f := clampf((hh - (end - BLEND_H)) / BLEND_H, 0.0, 1.0)
	return [lerpf(cur[1], nxt[1], f), lerpf(cur[2], nxt[2], f), lerpf(cur[3], nxt[3], f)]


static func now() -> Array:
	var t := Time.get_time_dict_from_system()
	return at(t.hour + t.minute / 60.0 + t.second / 3600.0)
