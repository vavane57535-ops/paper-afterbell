extends RefCounted



const DEFAULT: Dictionary = {

	"cadence": 1.0, "stride": 1.0, "bob": 1.0, "sway": 1.0, "lean": 1.0, 
	"arm_swing": 1.0, "arm_out": 0.0, "elbow": 0.0, "knee_lift": 1.0, "stance": 1.0, 
	"slouch": 0.0, "head_fwd": 0.0, "fist": 0.75, "snappy": 0.0, "glide": 0.0, 
	"elbow_lag": 0.35, "hop": 0.0, "heel_kick": 1.0, "cross": 1.0, "twist": 1.0, "press": 1.0, 

	"contra": 1.0, "idle_arm_x": 0.04, "idle_arm_z": 0.0, "idle_elbow": 0.2, "idle_curl": 0.28, 
	"idle_bounce": 0.0, "idle_sway": 0.0, "look_rate": 1.0, "look_range": 1.0, 
	"breath": 1.0, "head_tilt": 0.0, "shift_rate": 1.0, 
}

const STYLES: Dictionary = {

	"Alice": {"cadence": 1.12, "stride": 0.62, "bob": 0.25, "sway": 0.3, "lean": 1.2, "arm_swing": 0.3, 
		"arm_out": 0.16, "elbow": -0.2, "knee_lift": 0.32, "slouch": 0.12, "head_fwd": 0.1, "fist": 0.3, 
		"glide": 1.0, "contra": 0.6, "idle_arm_x": 0.22, "idle_arm_z": 0.12, "idle_elbow": 0.42, "idle_curl": 0.3, 
		"idle_sway": 0.5, "look_rate": 0.55, "look_range": 1.2, "breath": 0.7, "head_tilt": 0.09, "shift_rate": 0.5}, 

	"Ashura": {"cadence": 1.0, "arm_swing": 0.8, "elbow": -0.08, "slouch": 0.07, "head_fwd": 0.05, "fist": 0.6, 
		"contra": 1.35, "idle_arm_x": 0.0, "idle_elbow": 0.14, "idle_curl": 0.35, "look_rate": 0.7, "head_tilt": 0.06}, 

	"Usayuko": {"cadence": 0.9, "stride": 1.05, "bob": 1.45, "sway": 1.7, "lean": 0.85, "arm_swing": 0.85, "arm_out": 0.14, 
		"elbow": 0.12, "knee_lift": 0.8, "stance": 1.3, "fist": 1.0, "contra": 0.3, "idle_arm_z": 0.16, 
		"idle_elbow": 0.34, "idle_curl": 0.7, "breath": 1.35, "look_rate": 0.8, "shift_rate": 0.6}, 

	"Simon": {"cadence": 1.1, "bob": 1.3, "lean": 1.15, "arm_swing": 1.1, "knee_lift": 1.12, "fist": 0.8, 
		"hop": 0.5, "idle_bounce": 1.0, "look_rate": 1.8, "look_range": 1.2, "contra": 0.8}, 

	"Lysia": {"cadence": 1.0, "bob": 0.7, "sway": 0.6, "arm_swing": 0.95, "elbow": 0.1, "knee_lift": 0.95, 
		"snappy": 1.0, "elbow_lag": 0.0, "contra": 0.25, "idle_arm_x": 0.0, "idle_elbow": 0.08, "idle_curl": 0.12, 
		"look_rate": 1.4, "breath": 0.45, "fist": 0.2}, 

	"Elly": {"cadence": 0.92, "stride": 0.95, "bob": 0.75, "sway": 0.8, "lean": 0.75, "arm_swing": 0.62, "elbow": -0.1, 
		"knee_lift": 0.85, "fist": 0.5, "contra": 0.7, "idle_curl": 0.3, "look_rate": 0.6, 
		"breath": 0.9, "head_tilt": 0.05, "shift_rate": 0.7}, 

	"Bleuette": {"cadence": 1.07, "bob": 1.55, "sway": 1.2, "arm_swing": 1.0, "arm_out": 0.22, "elbow": -0.05, 
		"knee_lift": 1.05, "fist": 0.55, "elbow_lag": 0.6, "hop": 1.0, "contra": 1.0, "idle_arm_z": 0.1, 
		"idle_sway": 1.0, "idle_bounce": 0.4, "look_rate": 1.3, "head_tilt": 0.1}, 
	"TrueForm": {"cadence": 1.25, "stride": 1.2, "bob": 1.4, "lean": 0.4, "arm_swing": 0.6, "arm_out": 0.25, "fist": 0.3, 
		"knee_lift": 0.9, "stance": 1.25, "contra": 0.2, "idle_curl": 0.3, "look_rate": 0.8}, 
}

# Course et marche des élèves (0.16) : ces valeurs remplacent celles de STYLES pour la locomotion.
# knee_lift / heel_kick : montée du genou / repli du talon ; twist : contre-rotation des épaules ;
# press : écrasement à l'appui ; cross : la main rentre vers l'axe du corps ; hop : rebond en plus.
const GAITS: Dictionary = {

	"Ashura": {"cadence": 0.97, "stride": 1.0, "bob": 0.9, "sway": 1.1, "lean": 0.9, "arm_swing": 0.9, "arm_out": 0.02,
		"elbow": -0.1, "knee_lift": 0.95, "heel_kick": 0.95, "fist": 0.45, "twist": 1.15, "cross": 0.7, "hop": 0.0, "press": 0.9},

	"Usayuko": {"cadence": 0.94, "stride": 1.05, "bob": 1.1, "sway": 1.25, "lean": 1.15, "arm_swing": 1.15, "arm_out": 0.08,
		"elbow": 0.0, "knee_lift": 1.05, "heel_kick": 0.95, "stance": 1.15, "fist": 1.0, "twist": 1.2, "cross": 0.5, "press": 1.5},

	"Simon": {"cadence": 1.08, "bob": 1.1, "lean": 1.2, "arm_swing": 1.05, "arm_out": 0.08, "knee_lift": 1.12, "heel_kick": 1.1,
		"fist": 0.85, "hop": 0.35, "twist": 1.0, "cross": 0.45, "press": 0.8},

	"Lysia": {"cadence": 1.1, "stride": 0.82, "bob": 0.6, "sway": 0.4, "lean": 0.9, "arm_swing": 0.85, "arm_out": 0.04, "elbow": 0.05,
		"knee_lift": 0.82, "heel_kick": 0.72, "snappy": 1.0, "elbow_lag": 0.0, "fist": 0.8, "twist": 0.35, "cross": 0.0, "press": 0.7},

	"Elly": {"cadence": 0.95, "stride": 1.08, "bob": 0.85, "sway": 0.8, "lean": 0.85, "arm_swing": 0.85, "arm_out": 0.02,
		"elbow": -0.12, "knee_lift": 1.0, "heel_kick": 1.0, "fist": 0.35, "twist": 0.9, "cross": 0.7, "press": 0.85},

	"Bleuette": {"cadence": 1.1, "stride": 0.95, "bob": 1.3, "sway": 1.2, "lean": 1.0, "arm_swing": 1.1, "arm_out": 0.14,
		"elbow": -0.05, "knee_lift": 1.12, "heel_kick": 1.05, "fist": 0.55, "hop": 0.7, "twist": 1.05, "cross": 0.8, "press": 1.0},
}

static func for_character(person: String) -> Dictionary:
	var style: Dictionary = DEFAULT.duplicate()
	style.merge(STYLES.get(person, {}), true)
	style.merge(GAITS.get(person, {}), true)
	return style
