extends Node3D
class_name PaperYiero

# Yiero, le démon colossal du prologue (« Prologue — Yiero »).
# Modèle sculpté dans Blender par script (models/yiero/src/build_yiero.py → models/yiero/yiero.glb) :
# un seul maillage skinné (peau d'encre, gencives, gueule, langue, dents, griffes), un squelette de
# 52 os piloté ici par code (IK des bras, doigts, mâchoire, visage), yeux et halos ajoutés en code.
# Le film règle les paramètres publics ci-dessous à chaque image puis appelle pose().
# Repère local : +Z = devant (vers ce que Yiero regarde), Y = haut, origine = surface de l'encre.
# Côté « _l » = x local négatif (à gauche de l'écran quand on le regarde de face) = hand_target[0]
# (piste « hand_px » du film, Yiero étant tourné de PI) ; côté « _r » = x positif = hand_target[1].
#
# --- API utilisée par film_intro_yiero.gd (inchangée) -------------------------------------------
#   build(), pose(), socket(nom)
#   rise 0..1 (0 = sous l'encre)          reveal 0..1 (0 = corps invisible : yeux et sourire seuls)
#   eye_open 0..1, eye_glow (1 = normal)  grin 0..1 (le sourire se fend du centre vers les coins)
#   grin_wide 1..1.3 (coins tirés)        jaw 0..1.2 (gueule ouverte ; 1 = rugissement)
#   lean (avancée du buste, unités)       head_pitch (+ = regarde en bas), head_yaw, head_roll
#   tremble, hurt (éclair doré), fury, squint, wind (tempête), tooth_chip 0..1 (éclat de dent),
#   clock (temps du film, ralentis compris), look_target (monde), hand_target[2] (poignets, monde),
#   hand_curl[2] (0 = ouverte, 1 = poing / pince), hand_spread[2], arm_shown[2], breath.
#   Sockets : eye_l, eye_r, eyes, mouth, teeth, chin, head, face, brow, hand_l, hand_r, grip_l,
#   grip_r, pinch_l, pinch_r, chest, + throat, tongue, nose, shoulder_l/r, elbow_l/r, claw_l/r.
#
# --- Contrôles fins (nouveaux, 0.17) — pour les lots du prologue --------------------------------
#   squint_eye[2]   plissement d'un seul œil (s'ajoute à squint ; l'œil s'écrase, sourcil et
#                   pommette se resserrent : pas de paupières)
#   pupil           taille des pupilles (1 = normal, 0.5 = tête d'épingle, 1.8 = dilatées)
#   brow            sourcils : -1 levés (surprise moqueuse) … +1 froncés
#   head_tilt       inclinaison « curieuse » de la tête (rad), répartie sur le cou et la tête
#   neck_reach      avance la tête vers l'avant (unités, ~0..6), sans bouger le corps
#   breath          amplitude du souffle (1 = normal, 0 = retenu) ; breath_rate = vitesse
#   snarl           retrousse les babines (montre les gencives), 0..1
#   drool           filets de bave entre les mâchoires quand la gueule s'ouvre, 0..1
#   finger_curl[2][5]  flexion propre à chaque doigt (index, majeur, annulaire, auriculaire,
#                   pouce), ajoutée à hand_curl ; -0.3..1.2
#   claw_flex[2]    crochète les dernières phalanges (griffes qui grattent), 0..1
#   hand_twist[2]   rotation du poignet (rad, + = paume tournée vers le visage)
#   hand_pitch[2]   flexion du poignet (rad, + = doigts vers le bas)
#   shrug[2]        hausse l'épaule (0..1)
#   drip, gloss     coulures d'encre et brillance (1 = normal)
# Chaque contrôle fin peut aussi être piloté par une piste du film, sans toucher à _pose_yiero :
#   _key("yiero_<nom>", t, valeur)   noms : squint_l, squint_r, pupil, brow, tilt, neck, breath,
#   breath_rate, snarl, drool, drip, gloss, curl_l / curl_r (doigt par doigt : index_l, middle_l,
#   ring_l, pinky_l, thumb_l, idem _r), claw_l, claw_r, twist_l, twist_r, wrist_l, wrist_r,
#   shrug_l, shrug_r, spread_l, spread_r.
# PaperYiero lit ces pistes lui-même (film parent qui a _val et elapsed) ; sans clé, rien ne change.

const MODEL_PATH: String = "res://models/yiero/yiero.glb"

const HEAD_Y: float = 30.0
const HEAD_HALF: float = 16.0
const MOUTH_HALF: float = 17.5
const EYE_X: float = 7.4
const EYE_Y: float = 35.5
const EYE_Z: float = 6.3
const EYE_R: float = 2.75
const FACE_Z: float = 8.4
const UPPER_ARM: float = 33.0
const FOREARM: float = 32.0
const SHOULDER: Vector3 = Vector3(25.5, 18.0, -3.0)
const CORNER_Y: float = 27.6
const FINGERS: PackedStringArray = ["index", "middle", "ring", "pinky", "thumb"]
const CHANNELS: PackedStringArray = ["squint_l", "squint_r", "pupil", "brow", "tilt", "neck", "breath", "breath_rate", "snarl", "drool", "drip", "gloss", "claw_l", "claw_r", "twist_l", "twist_r", "wrist_l", "wrist_r", "shrug_l", "shrug_r", "spread_l", "spread_r", "index_l", "middle_l", "ring_l", "pinky_l", "thumb_l", "index_r", "middle_r", "ring_r", "pinky_r", "thumb_r"]

# Fonction partagée par les shaders : fenêtre du sourire (grin < 1 → fente qui s'ouvre du centre).
const GRIN_GLSL: String = """
uniform float grin = 1.0;
const float MZ0 = -6.0;
const float MTHC = 1.2;
const float MCY = 27.6;
float grin_open(vec3 r) {
	if (grin >= 0.999) return 1.0;
	float u = atan(r.x, r.z - MZ0) / MTHC;
	float uc = clamp(u, -1.0, 1.0);
	float up = MCY - 6.6 * (1.0 - uc * uc);
	float lo = MCY - 11.8 * (1.0 - uc * uc);
	float c = 0.5 * (up + lo) + 0.05;
	float hh = 0.5 * (up - lo) + 1.45;
	float g = clamp(grin, 0.0, 1.0);
	float extent = g * 1.14;
	float span = 1.0 - smoothstep(extent - 0.14, extent, abs(u));
	float lens = sqrt(max(0.0, 1.0 - pow(abs(u) / max(extent, 0.001), 2.0)));
	float height = hh * mix(0.14, 1.0, smoothstep(0.05, 0.9, g)) * lens;
	float vert = 1.0 - smoothstep(height - 0.3, height + 0.05, abs(r.y - c));
	return span * vert;
}
"""

const NOISE_GLSL: String = """
float yh(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float yn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(yh(i), yh(i + vec3(1, 0, 0)), f.x), mix(yh(i + vec3(0, 1, 0)), yh(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(yh(i + vec3(0, 0, 1)), yh(i + vec3(1, 0, 1)), f.x), mix(yh(i + vec3(0, 1, 1)), yh(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
"""

const FLESH_SHADER: String = """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform float reveal = 1.0;
uniform float hurt = 0.0;
uniform vec4 hurt_color : source_color = vec4(1.0, 0.8, 0.42, 1.0);
uniform float fury = 0.0;
uniform float clock = 0.0;
uniform float glow = 1.0;
uniform float jaw = 0.0;
uniform float drip = 1.0;
uniform float gloss = 1.0;
uniform float crumple = 1.0;
uniform int debug_view = 0;
uniform vec3 sun_dir = vec3(0.0, 0.42, 1.0);
uniform vec4 rim_color : source_color = vec4(0.95, 0.16, 0.08, 1.0);
uniform vec4 sky_low : source_color = vec4(0.5, 0.05, 0.035, 1.0);
uniform vec4 sky_high : source_color = vec4(0.05, 0.0, 0.012, 1.0);
uniform vec4 corona : source_color = vec4(1.0, 0.36, 0.16, 1.0);
varying vec3 rest;
varying vec4 mask;
varying vec3 wn;
varying vec3 wp;
varying float wet_v;
varying float mouth_v;
%s
%s
void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	mask = COLOR;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec3 sky(vec3 d) {
	float h = d.y;
	vec3 c = mix(sky_low.rgb, sky_high.rgb, smoothstep(-0.1, 0.55, h));
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	c += corona.rgb * (pow(s, 24.0) * 1.6 + pow(s, 4.0) * 0.18);
	return c;
}
void fragment() {
	float gum = mask.r;
	float mouth = mask.g;
	float ao = mask.b;
	float inner = clamp(gum + mouth, 0.0, 1.0);
	float open = grin_open(rest);
	// papier froissé : relief des plis dans la normale (repère de repos → monde → vue)
	vec3 q = rest * 0.33;
	float e = 0.35;
	float n0 = yn(q);
	vec3 g = vec3(yn(q + vec3(e, 0, 0)) - n0, yn(q + vec3(0, e, 0)) - n0, yn(q + vec3(0, 0, e)) - n0) / e;
	float ridge = 1.0 - abs(2.0 * yn(q * 2.1 + 3.7) - 1.0);
	vec3 gw = (MODEL_MATRIX * vec4(g, 0.0)).xyz * 0.33;
	gw -= wn * dot(gw, wn);
	vec3 nw = normalize(wn - gw * 0.55 * crumple * (1.0 - inner) * (0.5 + ridge));
	vec3 n = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	NORMAL = n;
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	// coulures d'encre : traînées verticales qui glissent
	float col = yn(vec3(rest.x * 0.7, 0.0, rest.z * 0.7) + 11.0);
	float streak = smoothstep(0.72, 0.8, col) * smoothstep(0.92, 0.82, col);
	float flow = fract(rest.y * 0.045 + clock * 0.07 * drip + col * 9.0);
	float drop = smoothstep(0.0, 0.05, flow) * (1.0 - smoothstep(0.05, 0.3, flow));
	float wet = clamp(mask.a + streak * (0.45 + 0.55 * drop) * drip, 0.0, 1.0) * gloss;
	// peau : encre noire, fibres de papier
	float fib = yn(rest * 1.7) * 0.6 + yn(rest * 4.3) * 0.4;
	vec3 skin = vec3(0.022, 0.014, 0.018) * (0.75 + 0.5 * fib) * ao;
	// gencives et gueule
	float depth = clamp((16.0 - length(rest.xz - vec2(0.0, -6.0))) / 9.0, 0.0, 1.0);
	vec3 gum_c = mix(vec3(0.5, 0.03, 0.045), vec3(0.22, 0.0, 0.02), 1.0 - ao);
	vec3 mouth_c = mix(vec3(0.16, 0.01, 0.015), vec3(0.03, 0.0, 0.004), depth);
	vec3 alb = skin;
	alb = mix(alb, gum_c, gum);
	alb = mix(alb, mouth_c, mouth);
	float seen = mix(reveal, 1.0, inner) * mix(1.0, open, inner);
	ALBEDO = alb * seen;
	ROUGHNESS = mix(mix(0.62, 0.16, wet), 0.14, gum);
	SPECULAR = mix(0.35 + 0.45 * wet, 0.75, inner) * seen;
	// reflet du ciel (encre brillante) + liseré rouge côté éclipse
	vec3 r = reflect(-vw, nw);
	float back = smoothstep(-0.35, 0.65, dot(nw, normalize(sun_dir)));
	vec3 refl = sky(r) * (0.035 + 0.965 * fres) * (0.25 + 0.75 * wet) * ao;
	vec3 rim = rim_color.rgb * pow(1.0 - ndv, 4.0) * (0.12 + 0.55 * back) * (0.6 + 0.4 * fib);
	vec3 em = (refl + rim) * reveal * (1.0 - inner);
	// fureur : veines de braise qui affleurent
	float crack = smoothstep(0.86, 0.97, 1.0 - abs(2.0 * yn(rest * 0.21 + vec3(0.0, clock * 0.05, 0.0)) - 1.0));
	em += vec3(1.0, 0.18, 0.04) * crack * fury * (0.55 + 0.45 * sin(clock * 5.0 + rest.y * 0.3)) * 0.9 * (1.0 - inner) * reveal;
	em += hurt_color.rgb * hurt * (0.1 + fres * 1.2) * (1.0 - inner);
	// gueule : gencives humides qui luisent un peu dans le noir, gorge brûlante
	float throat = (0.3 + jaw * 1.35 + fury * 0.4) * depth * depth;
	em += gum_c * gum * (0.16 + 0.22 * glow) * open;
	em += vec3(0.62, 0.04, 0.02) * mouth * throat * open * (0.85 + 0.15 * sin(clock * 3.1));
	EMISSION = em;
	if (debug_view == 1) { ALBEDO = vec3(0.0); EMISSION = mask.rgb; }
	if (debug_view == 2) { ALBEDO = vec3(0.0); EMISSION = vec3(mask.a); }
	if (debug_view == 3) { ALBEDO = vec3(0.0); EMISSION = fract(rest * 0.1); }
	if (debug_view == 4) { ALBEDO = vec3(0.0); EMISSION = vec3(open); }
	if (debug_view == 5) { ALBEDO = vec3(0.0); SPECULAR = 0.0; ROUGHNESS = 1.0; }
	if (debug_view == 6) { EMISSION = vec3(0.0); }
	if (debug_view == 7) { EMISSION = vec3(0.0); SPECULAR = 0.0; }
	if (debug_view == 8) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = wn * 0.5 + 0.5; }
	if (debug_view == 9) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = vec3(ndv, fres, back); }
	if (debug_view == 10) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = refl; }
	if (debug_view == 11) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = rim; }
	if (debug_view == 12) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = nw * 0.5 + 0.5; }
	if (debug_view == 13) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = n * 0.5 + 0.5; }
	if (debug_view == 14) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = gw * 5.0 + 0.5; }
	if (debug_view == 15) { ALBEDO = vec3(0.0); SPECULAR = 0.0; EMISSION = VIEW * 0.5 + 0.5; }
}
"""

const TEETH_SHADER: String = """
shader_type spatial;
render_mode cull_back;
uniform float glow = 1.0;
uniform float reveal = 1.0;
uniform float hurt = 0.0;
uniform float fury = 0.0;
uniform float wet = 0.8;
uniform vec4 ivory : source_color = vec4(0.93, 0.88, 0.74, 1.0);
uniform vec4 stain : source_color = vec4(0.52, 0.36, 0.2, 1.0);
uniform vec4 shade : source_color = vec4(0.42, 0.22, 0.16, 1.0);
varying vec3 rest;
varying float along;
%s
void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	along = UV2.y;
}
void fragment() {
	float open = grin_open(rest);
	vec3 base = mix(stain.rgb, ivory.rgb, smoothstep(0.0, 0.5, along));
	base = mix(base, vec3(1.0, 0.97, 0.9), smoothstep(0.75, 1.0, along) * 0.6);
	ALBEDO = base * open;
	ROUGHNESS = mix(0.5, 0.18, wet);
	SPECULAR = 0.6 * open;
	EMISSION = base * open * (0.12 + 0.2 * glow) + vec3(1.0, 0.8, 0.45) * hurt * 0.4 * open;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float aa = clamp(length(fwidth(NORMAL)) * 0.5, 0.02, 0.2);
	float lit = smoothstep(0.08 - aa, 0.08 + aa, ndl * ATTENUATION);
	vec3 ramp = mix(shade.rgb * 0.55, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp * max(ndl, 0.25) / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float sp = pow(max(dot(NORMAL, h), 0.0), 60.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.35, 0.45, sp) * wet * 0.5 / PI;
}
"""

const CLAW_SHADER: String = """
shader_type spatial;
render_mode cull_back;
uniform float reveal = 1.0;
uniform float hurt = 0.0;
uniform float glow = 1.0;
uniform vec4 root_c : source_color = vec4(0.05, 0.03, 0.025, 1.0);
uniform vec4 tip_c : source_color = vec4(0.78, 0.7, 0.56, 1.0);
varying float along;
void vertex() { along = UV2.y; }
void fragment() {
	vec3 base = mix(root_c.rgb, tip_c.rgb, smoothstep(0.25, 0.95, along));
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = base * mix(0.35, 1.0, reveal);
	ROUGHNESS = 0.22;
	SPECULAR = 0.65;
	EMISSION = base * (0.04 + 0.06 * glow) * smoothstep(0.4, 1.0, along) + vec3(0.9, 0.18, 0.08) * pow(1.0 - ndv, 4.0) * 0.25 * reveal + vec3(1.0, 0.8, 0.45) * hurt * 0.3;
}
"""

const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
uniform float width = 0.07;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = color.rgb; }
"""

const EYE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 look = vec3(0.0, 0.0, 1.0);
uniform float pupil = 0.15;
uniform float glow = 1.0;
uniform float fury = 0.0;
uniform float hurt = 0.0;
varying vec3 on;
%s
void vertex() { on = normalize(VERTEX); }
void fragment() {
	vec3 d = normalize(on);
	vec3 lk = normalize(look);
	float ang = acos(clamp(dot(d, lk), -1.0, 1.0));
	// globe pâle : lumineux au centre, plus sombre et chaud vers le bord de l'orbite
	float front = clamp(dot(d, normalize(lk + vec3(0.0, 0.0, 1.6))), -1.0, 1.0);
	vec3 scl = mix(vec3(0.3, 0.22, 0.2), vec3(0.88, 0.84, 0.74), smoothstep(-0.15, 0.55, front));
	scl = mix(scl, vec3(1.0, 0.98, 0.93), smoothstep(0.6, 0.98, front) * 0.7);
	float vein = smoothstep(0.6, 0.68, yn(d * 7.0 + 4.0)) * smoothstep(0.72, 0.25, front);
	vein += smoothstep(0.66, 0.72, yn(d * 15.0 + 9.0)) * smoothstep(0.6, 0.1, front) * 0.6;
	scl = mix(scl, vec3(0.62, 0.08, 0.07), clamp(vein, 0.0, 1.0) * (0.22 + 0.7 * fury));
	scl = mix(scl, vec3(1.0, 0.66, 0.52), fury * 0.3);
	// iris gris à peine marqué, pupille minuscule, point de lumière au centre
	float iris = 1.0 - smoothstep(pupil * 1.6, pupil * 2.6, ang);
	vec3 c = mix(scl, scl * vec3(0.62, 0.6, 0.58), iris * 0.55);
	float ring = 1.0 - smoothstep(pupil * 0.88, pupil * 1.04, ang);
	c = mix(c, vec3(0.02, 0.008, 0.008), ring);
	float pin = 1.0 - smoothstep(pupil * 0.16, pupil * 0.3, ang);
	c = mix(c, vec3(1.0, 0.9, 0.8), pin * 0.75);
	float glint = smoothstep(0.988, 0.996, dot(NORMAL, normalize(vec3(-0.4, 0.5, 0.77))));
	glint += smoothstep(0.996, 0.999, dot(NORMAL, normalize(vec3(0.3, -0.2, 0.93)))) * 0.5;
	ALBEDO = c * glow * 0.98 + vec3(1.0) * glint * 0.9 * glow + vec3(1.0, 0.8, 0.45) * hurt * 0.25;
}
"""

const HALO_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform vec4 color : source_color = vec4(0.92, 0.85, 0.72, 1.0);
uniform float energy = 0.25;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = pow(max(0.0, 1.0 - r), 2.2);
	ALBEDO = color.rgb * energy * a;
	ALPHA = a;
}
"""

var jaw: float = 0.0
var grin: float = 1.0
var grin_wide: float = 1.0
var eye_open: float = 1.0
var eye_glow: float = 1.0
var squint: float = 0.0
var reveal: float = 1.0
var rise: float = 1.0
var lean: float = 0.0
var head_pitch: float = 0.0
var head_roll: float = 0.0
var head_yaw: float = 0.0
var tremble: float = 0.0
var breath: float = 1.0
var hurt: float = 0.0
var fury: float = 0.0
var wind: float = 1.0
var clock: float = 0.0
var look_target: Vector3 = Vector3.INF
var hand_target: Array[Vector3] = [Vector3.INF, Vector3.INF]
var hand_curl: Array[float] = [0.25, 0.25]
var hand_spread: Array[float] = [0.6, 0.6]
var arm_shown: Array[bool] = [true, true]
var tooth_chip: float = 0.0

# Contrôles fins (voir l'en-tête).
var squint_eye: Array[float] = [0.0, 0.0]
var pupil: float = 1.0
var brow: float = 0.0
var head_tilt: float = 0.0
var neck_reach: float = 0.0
var breath_rate: float = 1.0
var snarl: float = 0.0
var drool: float = 1.0
var drip: float = 1.0
var gloss: float = 1.0
var finger_curl: Array = [[0.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0, 0.0]]
var claw_flex: Array[float] = [0.0, 0.0]
var hand_twist: Array[float] = [0.0, 0.0]
var hand_pitch: Array[float] = [0.0, 0.0]
var shrug: Array[float] = [0.0, 0.0]
var film_channels: bool = true
var debug_view: int = 0

var _body: Node3D
var _model: Node3D
var _skel: Skeleton3D
var _mesh: MeshInstance3D
var _chip: MeshInstance3D
var _chip_rest: Vector3 = Vector3(-2.6, 19.6, 9.6)
var _head_follow: Node3D
var _jaw_follow: Node3D
var _eyes: Array[MeshInstance3D] = []
var _eye_mats: Array[ShaderMaterial] = []
var _halos: Array[MeshInstance3D] = []
var _eye_lights: Array[OmniLight3D] = []
var _mouth_light: OmniLight3D
var _flesh: ShaderMaterial
var _teeth: ShaderMaterial
var _claw: ShaderMaterial
var _halo: ShaderMaterial
var _built: bool = false
var _film: Object = null
var _film_checked: bool = false

# Squelette : index, parents, poses de repos globales (repère du squelette).
var _bone: Dictionary = {}
var _parent: PackedInt32Array = PackedInt32Array()
var _rest_g: Array[Transform3D] = []
var _rest_l: Array[Transform3D] = []
var _pose_g: Array[Transform3D] = []
var _arm: Array = [{}, {}]

func build() -> void :
	if _built: return
	_built = true
	_materials()
	_body = Node3D.new();_body.name = "Body";add_child(_body)
	var scene: PackedScene = load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("PaperYiero : modèle introuvable " + MODEL_PATH)
		return
	_model = scene.instantiate() as Node3D
	_model.name = "Model"
	_body.add_child(_model)
	var skeletons: Array[Node] = _model.find_children("*", "Skeleton3D", true, false)
	_skel = skeletons[0] as Skeleton3D
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 60.0
		if mi.name.begins_with("ToothChip"): _chip = mi
		elif mi.skin != null or mi.get_parent() == _skel: _mesh = mi
	_assign_materials()
	_read_skeleton()
	_head_follow = Node3D.new();_head_follow.name = "HeadFollow";_skel.add_child(_head_follow)
	_jaw_follow = Node3D.new();_jaw_follow.name = "JawFollow";_skel.add_child(_jaw_follow)
	if is_instance_valid(_chip):
		var aabb: AABB = _chip.mesh.get_aabb()
		_chip_rest = aabb.get_center()
		_chip.get_parent().remove_child(_chip)
		_head_follow.add_child(_chip)
		_chip.material_override = _teeth
	_build_eyes()
	_mouth_light = OmniLight3D.new();_mouth_light.light_color = Color("ff2a14");_mouth_light.omni_range = 30.0;_mouth_light.light_energy = 0.0;_mouth_light.shadow_enabled = false
	_jaw_follow.add_child(_mouth_light);_mouth_light.position = Vector3(0, 18.5, 2.0)
	pose()

func _shader(code: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = code
	return shader

func _materials() -> void :
	_flesh = ShaderMaterial.new();_flesh.shader = _shader(FLESH_SHADER % [GRIN_GLSL, NOISE_GLSL])
	var outline: Shader = _shader(OUTLINE_SHADER)
	_teeth = ShaderMaterial.new();_teeth.shader = _shader(TEETH_SHADER % GRIN_GLSL)
	var teeth_line: ShaderMaterial = ShaderMaterial.new();teeth_line.shader = outline;teeth_line.set_shader_parameter("width", 0.055)
	_teeth.next_pass = teeth_line
	_claw = ShaderMaterial.new();_claw.shader = _shader(CLAW_SHADER)
	var claw_line: ShaderMaterial = ShaderMaterial.new();claw_line.shader = outline;claw_line.set_shader_parameter("width", 0.07)
	_claw.next_pass = claw_line
	_halo = ShaderMaterial.new();_halo.shader = _shader(HALO_SHADER)

func _assign_materials() -> void :
	if not is_instance_valid(_mesh): return
	var mesh: Mesh = _mesh.mesh
	for i: int in range(mesh.get_surface_count()):
		var source: Material = mesh.surface_get_material(i)
		var label: String = source.resource_name if source != null else ""
		if label.is_empty(): label = str(mesh.get("surface_%d/name" % i))
		var material: Material = _flesh
		if label.contains("teeth"): material = _teeth
		elif label.contains("claw"): material = _claw
		_mesh.set_surface_override_material(i, material)

func _read_skeleton() -> void :
	var count: int = _skel.get_bone_count()
	_parent.resize(count)
	_rest_g.resize(count);_rest_l.resize(count);_pose_g.resize(count)
	for i: int in range(count):
		_bone[_skel.get_bone_name(i)] = i
		_parent[i] = _skel.get_bone_parent(i)
		_rest_l[i] = _skel.get_bone_rest(i)
		_rest_g[i] = _rest_l[i] if _parent[i] < 0 else _rest_g[_parent[i]] * _rest_l[i]
	for side: int in [0, 1]:
		var tag: String = "_l" if side == 0 else "_r"
		var arm: Dictionary = {}
		for key: String in ["clavicle", "upperarm", "forearm", "hand"]:
			arm[key] = int(_bone.get(key + tag, -1))
		var fingers: Array = []
		for f: String in FINGERS:
			var chain: Array[int] = []
			for j: int in range(3): chain.append(int(_bone.get("%s_%d%s" % [f, j + 1, tag], -1)))
			fingers.append(chain)
		arm["fingers"] = fingers
		var tips: Array[int] = []
		for f: String in FINGERS: tips.append(int(_bone.get("%s_tip%s" % [f, tag], -1)))
		arm["tips"] = tips
		var s: Vector3 = _rest_g[arm.upperarm].origin
		var e: Vector3 = _rest_g[arm.forearm].origin
		var w: Vector3 = _rest_g[arm.hand].origin
		arm["l1"] = s.distance_to(e)
		arm["l2"] = e.distance_to(w)
		var u0: Vector3 = (e - s).normalized()
		var f0: Vector3 = (w - e).normalized()
		arm["u0"] = u0;arm["f0"] = f0;arm["n0"] = u0.cross(f0).normalized()
		# repère de la main au repos : avant (vers les jointures), haut (dos de la main), extérieur
		var knuckles: Vector3 = Vector3.ZERO
		for chain: Array[int] in fingers.slice(0, 4): knuckles += _rest_g[chain[0]].origin
		knuckles /= 4.0
		var fwd: Vector3 = (knuckles - w).normalized()
		var outv: Vector3 = (_rest_g[fingers[3][0]].origin - _rest_g[fingers[0][0]].origin).normalized()
		var upv: Vector3 = fwd.cross(outv).normalized() * (1.0 if side == 1 else -1.0)
		if upv.y < 0.0: upv = -upv
		arm["hand_fwd"] = fwd;arm["hand_up"] = upv;arm["hand_out"] = outv
		arm["palm"] = w + fwd * 5.6 - upv * 0.3
		# axes de flexion de chaque doigt au repos (perpendiculaires au doigt et au dos de la main)
		var axes: Array[Vector3] = []
		for k: int in range(5):
			var chain: Array[int] = fingers[k]
			var dir: Vector3 = (_rest_g[chain[1]].origin - _rest_g[chain[0]].origin).normalized()
			var axis: Vector3 = dir.cross(upv).normalized()
			if k == 4: axis = dir.cross(upv * 0.75 - outv * 0.65).normalized()
			axes.append(axis)
		arm["axes"] = axes
		_arm[side] = arm

func _build_eyes() -> void :
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = EYE_R;sphere.height = EYE_R * 2.0;sphere.radial_segments = 40;sphere.rings = 20
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(EYE_R * 7.0, EYE_R * 7.0)
	var eye_shader: Shader = _shader(EYE_SHADER % NOISE_GLSL)
	for side: int in [-1, 1]:
		var material: ShaderMaterial = ShaderMaterial.new();material.shader = eye_shader
		var eye: MeshInstance3D = MeshInstance3D.new();eye.name = "Eye";eye.mesh = sphere;eye.material_override = material
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_follow.add_child(eye);eye.position = Vector3(side * EYE_X, EYE_Y, EYE_Z)
		_eyes.append(eye);_eye_mats.append(material)
		var halo: MeshInstance3D = MeshInstance3D.new();halo.name = "Halo";halo.mesh = quad;halo.material_override = _halo
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_follow.add_child(halo);halo.position = Vector3(side * EYE_X, EYE_Y, EYE_Z + EYE_R + 0.6)
		_halos.append(halo)
		var light: OmniLight3D = OmniLight3D.new();light.light_color = Color("f3e6c8");light.omni_range = 11.0;light.light_energy = 0.0
		_head_follow.add_child(light);light.position = Vector3(side * EYE_X, EYE_Y, EYE_Z + EYE_R + 2.5)
		_eye_lights.append(light)




# --- pistes optionnelles du film (contrôles fins) ------------------------------------------------
func _find_film() -> Object:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_val") and "elapsed" in node: return node
		node = node.get_parent()
	return null

func _channels() -> void :
	if not film_channels: return
	if not _film_checked:
		_film_checked = true
		_film = _find_film()
	if _film == null or not is_instance_valid(_film): return
	var keys: Variant = _film.get("_keys")
	if not (keys is Dictionary) or (keys as Dictionary).is_empty(): return
	var has_any: bool = false
	for key: Variant in (keys as Dictionary).keys():
		if str(key).begins_with("yiero_"):
			has_any = true
			break
	if not has_any: return
	var t: float = float(_film.get("elapsed"))
	squint_eye[0] = _ch("squint_l", t, squint_eye[0]);squint_eye[1] = _ch("squint_r", t, squint_eye[1])
	pupil = _ch("pupil", t, pupil);brow = _ch("brow", t, brow);head_tilt = _ch("tilt", t, head_tilt)
	neck_reach = _ch("neck", t, neck_reach);breath = _ch("breath", t, breath);breath_rate = _ch("breath_rate", t, breath_rate)
	snarl = _ch("snarl", t, snarl);drool = _ch("drool", t, drool);drip = _ch("drip", t, drip);gloss = _ch("gloss", t, gloss)
	for side: int in [0, 1]:
		var tag: String = "_l" if side == 0 else "_r"
		claw_flex[side] = _ch("claw" + tag, t, claw_flex[side])
		hand_twist[side] = _ch("twist" + tag, t, hand_twist[side])
		hand_pitch[side] = _ch("wrist" + tag, t, hand_pitch[side])
		shrug[side] = _ch("shrug" + tag, t, shrug[side])
		hand_spread[side] = _ch("spread" + tag, t, hand_spread[side])
		for f: int in range(5):
			finger_curl[side][f] = _ch(FINGERS[f] + tag, t, float(finger_curl[side][f]))

func _ch(name_value: String, t: float, fallback: float) -> float:
	return float(_film.call("_val", "yiero_" + name_value, t, fallback))




# --- squelette ------------------------------------------------------------------------------------
func _fk(i: int) -> Transform3D:
	var p: int = _parent[i]
	return _rest_l[i] if p < 0 else _pose_g[p] * _rest_l[i]

func _rotated(i: int, r: Basis, offset: Vector3 = Vector3.ZERO) -> void :
	var t: Transform3D = _fk(i)
	_pose_g[i] = Transform3D(r * t.basis, t.origin + offset)

func _delta(i: int) -> Transform3D:
	return _pose_g[i] * _rest_g[i].affine_inverse()

func _wave(a: float, b: float, c: float) -> float:
	return sin(clock * a + c) * 0.6 + sin(clock * b + c * 1.7) * 0.4

func socket(name_value: String) -> Vector3:
	if not _built or not is_instance_valid(_skel): return global_position
	var xf: Transform3D = _skel.global_transform
	var head: Transform3D = xf * _delta(_bone.head)
	var jaw_x: Transform3D = xf * _delta(_bone.jaw)
	match name_value:
		"eye_l": return _eyes[0].global_transform * Vector3(0, 0, EYE_R * 0.85)
		"eye_r": return _eyes[1].global_transform * Vector3(0, 0, EYE_R * 0.85)
		"eyes": return (socket("eye_l") + socket("eye_r")) * 0.5
		"mouth": return (head * Vector3(0, 21.0, 7.5) + jaw_x * Vector3(0, 16.0, 7.5)) * 0.5
		"teeth": return head * _chip_rest
		"chin": return jaw_x * Vector3(0, 12.0, 8.6)
		"head": return head * Vector3(0, 30.0, 0.0)
		"face": return head * Vector3(0, 30.0, FACE_Z)
		"brow": return head * Vector3(0, 38.5, 10.0)
		"nose": return head * Vector3(0, 30.8, 10.3)
		"throat": return (head * Vector3(0, 21.0, -2.0) + jaw_x * Vector3(0, 17.0, -2.0)) * 0.5
		"tongue": return jaw_x * Vector3(0, 16.2, 3.0)
		"hand_l": return xf * (_delta(_arm[0].hand) * (_arm[0].palm as Vector3))
		"hand_r": return xf * (_delta(_arm[1].hand) * (_arm[1].palm as Vector3))
		"grip_l", "grip_r":
			var k: int = 0 if name_value == "grip_l" else 1
			var palm: Vector3 = _arm[k].palm
			return xf * (_delta(_arm[k].hand) * (palm + (_arm[k].hand_fwd as Vector3) * 3.0 - (_arm[k].hand_up as Vector3) * 3.2))
		"pinch_l": return _pinch(0)
		"pinch_r": return _pinch(1)
		"claw_l": return _tip(0, 1)
		"claw_r": return _tip(1, 1)
		"shoulder_l": return xf * _pose_g[_arm[0].upperarm].origin
		"shoulder_r": return xf * _pose_g[_arm[1].upperarm].origin
		"elbow_l": return xf * _pose_g[_arm[0].forearm].origin
		"elbow_r": return xf * _pose_g[_arm[1].forearm].origin
		"chest": return xf * (_delta(_bone.chest) * Vector3(0, 12.0, 2.0))
	return global_position

# Bout de la griffe d'un doigt (repère monde) : os « <doigt>_tip » placé à la pointe de la griffe.
func _tip(side: int, finger: int, _extra: float = 0.0) -> Vector3:
	var tip: int = int(_arm[side].tips[finger])
	if tip < 0: return _skel.global_transform * _pose_g[_arm[side].hand].origin
	return _skel.global_transform * _pose_g[tip].origin

func _pinch(side: int) -> Vector3:
	return _tip(side, 0).lerp(_tip(side, 4), 0.5)




func pose() -> void :
	if not _built or not is_instance_valid(_skel): return
	_channels()
	var count: int = _pose_g.size()
	var shake: Vector3 = Vector3(sin(clock * 37.0) + sin(clock * 23.0 + 1.0), sin(clock * 41.0 + 2.0), sin(clock * 29.0 + 0.5)) * tremble * 0.35
	var phase: float = clock * 0.9 * breath_rate
	var inhale: float = sin(phase) * breath
	var heave: float = inhale * 0.6
	_body.position = Vector3(0, lerpf(-58.0, 0.0, rise) + heave, lean * 0.75) + shake
	_body.rotation = Vector3(0, 0, _wave(0.37, 0.23, 0.4) * 0.012)
	for i: int in range(count): _pose_g[i] = _fk(i)
	# buste : avancée (lean), souffle
	var hunch: float = lean * 0.006
	_rotated(_bone.root, Basis.IDENTITY)
	_rotated(_bone.spine, Basis(Vector3.RIGHT, hunch * 0.5 + _wave(0.21, 0.13, 1.0) * 0.006))
	_rotated(_bone.chest, Basis(Vector3.RIGHT, hunch * 0.5 - inhale * 0.012) * Basis(Vector3.UP, _wave(0.17, 0.29, 2.0) * 0.01))
	# cou et tête : tangage / lacet / roulis répartis, inclinaison curieuse, petits mouvements vivants
	var idle_p: float = _wave(0.31, 0.53, 0.2) * 0.012
	var idle_y: float = _wave(0.23, 0.41, 1.3) * 0.015
	var idle_r: float = sin(clock * 0.53) * 0.02
	var tilt: float = head_tilt
	var neck_b: Basis = Basis(Vector3.UP, head_yaw * 0.4) * Basis(Vector3.RIGHT, head_pitch * 0.35) * Basis(Vector3.BACK, head_roll * 0.3 + tilt * 0.4)
	_rotated(_bone.neck, neck_b, Vector3(0, 0, neck_reach * 0.55))
	var head_b: Basis = Basis(Vector3.UP, head_yaw * 0.6 + idle_y) * Basis(Vector3.RIGHT, head_pitch * 0.65 + idle_p) * Basis(Vector3.BACK, head_roll * 0.7 + tilt * 0.6 + idle_r)
	_rotated(_bone.head, head_b, Vector3(0, 0, neck_reach * 0.45))
	# mâchoire : rotation autour de la charnière + décrochage (mâchoire de serpent)
	var j: float = clampf(jaw, 0.0, 1.25)
	_rotated(_bone.jaw, Basis(Vector3.RIGHT, j * 0.4), Vector3(0, -j * 4.2, j * 1.3))
	# visage : commissures, sourcils, pommettes (pas de paupières : le plissement vient de là)
	var wide: float = clampf(grin_wide - 1.0, -0.3, 0.5)
	for side: int in [0, 1]:
		var sx: float = -1.0 if side == 0 else 1.0
		var tag: String = "_l" if side == 0 else "_r"
		var sq: float = clampf(squint + squint_eye[side], 0.0, 1.3)
		var corner: Vector3 = Vector3(sx * wide * 4.2, wide * 3.0 + snarl * 0.9, -wide * 1.8)
		_rotated(_bone["corner" + tag], Basis.IDENTITY, corner)
		var frown: float = clampf(brow + fury * 0.5, -1.0, 1.5)
		_rotated(_bone["brow" + tag], Basis.IDENTITY, Vector3(-sx * frown * 0.25, -sq * 1.3 - frown * 0.9, sq * 0.35 + frown * 0.3))
		_rotated(_bone["cheek" + tag], Basis.IDENTITY, Vector3(0, sq * 1.05 + wide * 1.6 + snarl * 0.5, sq * 0.3))
	for side: int in [0, 1]: _pose_arm(side, inhale)
	for i: int in range(count):
		var p: int = _parent[i]
		var local: Transform3D = _pose_g[i] if p < 0 else _pose_g[p].affine_inverse() * _pose_g[i]
		_skel.set_bone_pose_position(i, local.origin)
		_skel.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
	_head_follow.transform = _delta(_bone.head)
	_jaw_follow.transform = _delta(_bone.jaw)
	_pose_eyes()
	_pose_chip()
	_update_materials()

func _pose_arm(side: int, inhale: float) -> void :
	var arm: Dictionary = _arm[side]
	var sx: float = -1.0 if side == 0 else 1.0
	var skel_inv: Transform3D = _skel.global_transform.affine_inverse()
	var shown: bool = arm_shown[side] and hand_target[side].is_finite()
	var target: Vector3 = skel_inv * hand_target[side] if shown else Vector3(sx * 30.0, -40.0, 30.0)
	# clavicule : haussement (souffle, shrug) et aide à l'allonge vers la cible
	var clav: int = arm.clavicle
	var c_fk: Transform3D = _fk(clav)
	var s_rest: Vector3 = c_fk * (_rest_g[clav].affine_inverse() * _rest_g[arm.upperarm].origin)
	var reach: float = float(arm.l1) + float(arm.l2)
	var need: float = s_rest.distance_to(target) - reach * 0.97
	var to_t: Vector3 = (target - c_fk.origin).normalized()
	var clav_dir: Vector3 = (s_rest - c_fk.origin).normalized()
	var assist: float = clampf(need / 22.0, 0.0, 0.28)
	var c_basis: Basis = Basis.IDENTITY
	var axis: Vector3 = clav_dir.cross(to_t)
	if axis.length_squared() > 1e-6 and assist > 0.0: c_basis = Basis(axis.normalized(), assist)
	var lift: float = shrug[side] * 0.28 + inhale * 0.01 + _wave(0.27, 0.19, float(side) * 2.0) * 0.008
	c_basis = Basis(Vector3.BACK, -sx * lift) * c_basis
	_rotated(clav, c_basis)
	# bras : IK à deux os, coude vers l'extérieur, le haut et l'arrière (pattes d'araignée)
	var up_i: int = arm.upperarm
	var fo_i: int = arm.forearm
	var ha_i: int = arm.hand
	var s: Vector3 = _fk(up_i).origin
	var l1: float = arm.l1
	var l2: float = arm.l2
	var to: Vector3 = target - s
	var dist: float = clampf(to.length(), absf(l1 - l2) + 1.0, l1 + l2 - 0.05)
	var dir: Vector3 = to.normalized() if to.length_squared() > 0.01 else Vector3.DOWN
	var body_b: Basis = _pose_g[_bone.chest].basis * _rest_g[_bone.chest].basis.inverse()
	var pole: Vector3 = body_b * Vector3(sx * 1.0, 0.8, -0.45)
	pole = pole - dir * pole.dot(dir)
	pole = pole.normalized() if pole.length_squared() > 1e-5 else body_b * Vector3(sx, 0, 0)
	var a: float = (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var e: Vector3 = s + dir * a + pole * h
	var w: Vector3 = s + dir * dist
	var u1: Vector3 = (e - s).normalized()
	var f1: Vector3 = (w - e).normalized()
	var n1: Vector3 = u1.cross(f1)
	n1 = n1.normalized() if n1.length_squared() > 1e-6 else u1.cross(pole).normalized()
	var u0: Vector3 = arm.u0
	var f0: Vector3 = arm.f0
	var n0: Vector3 = arm.n0
	var ru: Basis = _frame(u1, n1) * _frame(u0, n0).inverse()
	_pose_g[up_i] = Transform3D(ru * _rest_g[up_i].basis, s)
	var rf: Basis = _frame(f1, n1) * _frame(f0, n0).inverse()
	_pose_g[fo_i] = Transform3D(rf * _rest_g[fo_i].basis, e)
	# main : prolonge l'avant-bras, se pose à plat près de l'encre, se tourne quand elle tient
	var fk_h: Transform3D = _fk(ha_i)
	var fwd0: Vector3 = arm.hand_fwd
	var up0: Vector3 = arm.hand_up
	var fwd_fk: Vector3 = (fk_h.basis * (_rest_g[ha_i].basis.inverse() * fwd0)).normalized()
	var flat: Vector3 = Vector3(fwd_fk.x, minf(fwd_fk.y, -0.12), fwd_fk.z)
	flat = Vector3(flat.x, flat.y * 0.35 - 0.12, flat.z).normalized()
	var low: float = 1.0 - smoothstep(4.0, 16.0, w.y)
	var curl: float = clampf(hand_curl[side], -0.2, 1.25)
	var hold: float = smoothstep(0.8, 1.0, curl) * smoothstep(8.0, 16.0, w.y)
	var fwd_h: Vector3 = fwd_fk.slerp(flat, low * 0.8).normalized()
	var up_h: Vector3 = Vector3.UP - fwd_h * fwd_h.y
	up_h = up_h.normalized()
	var twist: float = hand_twist[side] + hold * 1.15 * -sx
	up_h = up_h.rotated(fwd_h, twist)
	var side_h: Vector3 = fwd_h.cross(up_h).normalized()
	var pitch: float = hand_pitch[side] + _wave(0.6, 0.37, float(side) * 3.0) * 0.03
	fwd_h = fwd_h.rotated(side_h, -pitch);up_h = up_h.rotated(side_h, -pitch)
	var hb: Basis = _frame(fwd_h, up_h) * _frame(fwd0, up0).inverse()
	_pose_g[ha_i] = Transform3D(hb * _rest_g[ha_i].basis, w)
	# doigts : flexion phalange par phalange, écartement, petits frémissements
	var spread: float = (hand_spread[side] - 0.6) * (1.0 - smoothstep(0.4, 1.0, curl))
	var axes: Array = arm.axes
	for k: int in range(5):
		var chain: Array[int] = arm.fingers[k]
		var c: float = clampf(curl + float(finger_curl[side][k]), -0.3, 1.3)
		var twitch: float = _wave(2.3 + float(k) * 0.37, 3.1 - float(k) * 0.21, float(k) * 1.9 + float(side) * 4.0) * 0.045
		var flex: float = claw_flex[side]
		for jn: int in range(3):
			var bone: int = chain[jn]
			var fk: Transform3D = _fk(bone)
			var parent_delta: Basis = _pose_g[_parent[bone]].basis * _rest_g[_parent[bone]].basis.inverse()
			var bend_axis: Vector3 = (parent_delta * (axes[k] as Vector3)).normalized()
			var amount: float
			if k == 4:
				amount = [0.55, 0.7, 0.6][jn] * c + twitch * 0.5
			else:
				amount = [0.95, 1.3, 0.95][jn] * c + twitch + (flex * 0.75 if jn == 2 else 0.0) - (flex * 0.25 if jn == 0 else 0.0)
			var r: Basis = Basis(bend_axis, amount)
			if jn == 0 and k < 4:
				var up_axis: Vector3 = (parent_delta * up0).normalized()
				r = Basis(up_axis, (float(k) - 1.5) * 0.11 * spread * sx) * r
			_pose_g[bone] = Transform3D(r * fk.basis, fk.origin)

func _frame(x: Vector3, y: Vector3) -> Basis:
	var a: Vector3 = x.normalized()
	var b: Vector3 = (y - a * y.dot(a)).normalized()
	return Basis(a, b, a.cross(b))

func _pose_eyes() -> void :
	var open: float = clampf(eye_open, 0.0, 1.0)
	for k: int in range(2):
		var eye: MeshInstance3D = _eyes[k]
		var sq: float = clampf(squint + squint_eye[k], 0.0, 1.2)
		var s: float = maxf(0.001, open)
		eye.scale = Vector3(s * (1.0 + sq * 0.06), s * (1.0 - sq * 0.62), s * (1.0 - sq * 0.25))
		eye.position = Vector3((-1.0 if k == 0 else 1.0) * EYE_X, EYE_Y - sq * 0.25, EYE_Z - sq * 0.35)
		eye.visible = open > 0.002
		_halos[k].visible = eye.visible
		var look: Vector3 = Vector3(0, 0, 1)
		if look_target.is_finite():
			var local: Vector3 = (eye.global_transform.affine_inverse() * look_target)
			if local.length_squared() > 0.01:
				look = local.normalized()
				# les globes tournent peu : la pupille reste dans un cône de 40°
				var ang: float = acos(clampf(look.z, -1.0, 1.0))
				var lim: float = deg_to_rad(40.0)
				if ang > lim:
					var flat: Vector2 = Vector2(look.x, look.y).normalized()
					look = Vector3(flat.x * sin(lim), flat.y * sin(lim), cos(lim))
		# micro-saccades : petits sauts irréguliers du regard
		var beat: float = floor(clock * 1.7 + float(k) * 0.0)
		var jitter: Vector2 = Vector2(sin(beat * 12.9898) , cos(beat * 78.233)) * 0.012
		look = (look + Vector3(jitter.x, jitter.y, 0.0)).normalized()
		var material: ShaderMaterial = _eye_mats[k]
		material.set_shader_parameter("look", look)
		material.set_shader_parameter("pupil", 0.15 * clampf(pupil, 0.3, 2.2) * (1.0 - fury * 0.25))
		material.set_shader_parameter("glow", eye_glow * (1.0 + fury * 0.3))
		material.set_shader_parameter("fury", fury)
		material.set_shader_parameter("hurt", hurt)
		_eye_lights[k].light_energy = eye_glow * open * 1.6
	_halo.set_shader_parameter("energy", 0.2 * eye_glow * (1.0 + fury * 0.6) * open)
	_halo.set_shader_parameter("color", Color("e8d9b8").lerp(Color("ffb090"), fury * 0.6))

func _pose_chip() -> void :
	if not is_instance_valid(_chip): return
	var u: float = tooth_chip
	_chip.visible = u < 0.985
	if u <= 0.01:
		_chip.transform = Transform3D.IDENTITY
		return
	var k: float = clampf((u - 0.01) / 0.99, 0.0, 1.0)
	var spin: Basis = Basis.from_euler(Vector3(k * 9.0, k * 5.0, k * 7.0))
	var at: Vector3 = _chip_rest + Vector3(-k * 9.0, -k * k * 26.0, k * 10.0)
	_chip.transform = Transform3D(spin, at - spin * _chip_rest)

func _update_materials() -> void :
	var j: float = clampf(jaw, 0.0, 1.25)
	_flesh.set_shader_parameter("reveal", reveal)
	_flesh.set_shader_parameter("hurt", hurt)
	_flesh.set_shader_parameter("fury", fury)
	_flesh.set_shader_parameter("clock", clock)
	_flesh.set_shader_parameter("grin", grin)
	_flesh.set_shader_parameter("glow", eye_glow)
	_flesh.set_shader_parameter("jaw", j)
	_flesh.set_shader_parameter("drip", drip)
	_flesh.set_shader_parameter("gloss", gloss)
	_flesh.set_shader_parameter("debug_view", debug_view)
	_teeth.set_shader_parameter("grin", grin)
	_teeth.set_shader_parameter("glow", eye_glow)
	_teeth.set_shader_parameter("reveal", reveal)
	_teeth.set_shader_parameter("hurt", hurt)
	_teeth.set_shader_parameter("fury", fury)
	_claw.set_shader_parameter("reveal", reveal)
	_claw.set_shader_parameter("hurt", hurt)
	_claw.set_shader_parameter("glow", eye_glow)
	_mouth_light.light_energy = (j * 3.0 * reveal + fury * 1.5) * clampf(grin, 0.0, 1.0)
