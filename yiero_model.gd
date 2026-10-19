extends Node3D
class_name PaperYiero

# Yiero, le démon colossal du prologue (« Prologue — Yiero »), refait en 0.17.
# Modèle sculpté dans Blender par script (models/yiero/src/build_yiero.py → models/yiero/yiero.glb) :
# un maillage skinné (peau d'encre, gencives, gueule, langue, dents, griffes, couronne de pointes
# d'encre), un squelette de 56 os piloté ici par code (IK des bras, doigts, mâchoire, lèvres, visage).
# Yeux, halos, fumée d'encre et filets de bave sont ajoutés en code.
# Le film règle les paramètres publics ci-dessous à chaque image puis appelle pose().
# Repère local : +Z = devant (vers ce que Yiero regarde), Y = haut, origine = surface de l'encre.
# Côté « _l » = x local négatif (à gauche de l'écran quand on le regarde de face) = hand_target[0]
# (piste « hand_px » du film, Yiero étant tourné de PI) ; côté « _r » = x positif = hand_target[1].
#
# --- API utilisée par film_intro_yiero.gd (inchangée) -------------------------------------------
#   build(), pose(), socket(nom)
#   rise 0..1 (0 = sous l'encre)          reveal 0..1 (0 = corps noir : yeux et sourire seuls)
#   eye_open 0..1, eye_glow (1 = normal)  grin 0..1 (le sourire se fend du centre vers les coins)
#   grin_wide 1..1.3 (coins tirés)        jaw 0..1.2 (gueule ouverte ; 1 = rugissement)
#   lean (avancée du buste, unités)       head_pitch (+ = regarde en bas), head_yaw, head_roll
#   tremble, hurt (éclair doré), fury (braises, yeux qui rougissent), squint (yeux plissés),
#   wind (1 = calme, 3 = tempête : la couronne et la fumée se couchent), tooth_chip 0..1 (éclat),
#   clock (temps du film, ralentis compris), look_target (monde), hand_target[2] (poignets, monde),
#   hand_curl[2] (0 = ouverte, 1 = poing / pince), hand_spread[2], arm_shown[2], breath.
#   Sockets : eye_l, eye_r, eyes, mouth, teeth, chin, head, face, brow, hand_l, hand_r, grip_l,
#   grip_r, pinch_l, pinch_r, chest, + throat, tongue, nose, shoulder_l/r, elbow_l/r, claw_l/r.
#
# --- Contrôles fins (0.17) — pour les lots du prologue ------------------------------------------
#   squint_eye[2]   plissement d'un seul œil (s'ajoute à squint ; l'œil s'écrase entre le sourcil
#                   qui descend et la pommette qui monte : pas de paupières)
#   pupil           taille des pupilles (1 = normal, 0.5 = tête d'épingle, 2 = dilatées)
#   brow            sourcils : -1 levés (surprise moqueuse) … +1 froncés
#   head_tilt       inclinaison « curieuse » de la tête (rad), répartie sur le cou et la tête
#   neck_reach      avance la tête vers l'avant (unités, ~0..6), sans bouger le corps
#   breath          amplitude du souffle (1 = normal, 0 = retenu) ; breath_rate = vitesse (1 = lent)
#   snarl           retrousse les babines : la lèvre du haut monte, gencives à nu (0..1)
#   pout            lèvres serrées / avancées (0..1), pour une moue moqueuse
#   drool           filets de bave d'encre entre les mâchoires quand la gueule s'ouvre (0..1)
#   drip, gloss     coulures d'encre et brillance de la peau (1 = normal)
#   smoke           densité de la fumée d'encre autour de la tête (1 = normal, 0 = aucune)
#   finger_curl[2][5]  flexion propre à chaque doigt (index, majeur, annulaire, auriculaire,
#                   pouce), ajoutée à hand_curl ; -0.3..1.2
#   claw_flex[2]    crochète les dernières phalanges (griffes qui grattent), 0..1
#   hand_twist[2]   rotation du poignet (rad, + = paume tournée vers le visage)
#   hand_pitch[2]   flexion du poignet (rad, + = doigts vers le bas)
#   shrug[2]        hausse l'épaule (0..1)
# Chaque contrôle fin peut aussi être piloté par une piste du film, sans toucher à _pose_yiero :
#   _key("yiero_<nom>", t, valeur)   noms : squint_l, squint_r, pupil, brow, tilt, neck, breath,
#   breath_rate, snarl, pout, drool, drip, gloss, smoke, claw_l, claw_r, twist_l, twist_r,
#   wrist_l, wrist_r, shrug_l, shrug_r, spread_l, spread_r, et doigt par doigt : index_l,
#   middle_l, ring_l, pinky_l, thumb_l (idem _r).
# PaperYiero lit ces pistes lui-même (film parent qui a _val et elapsed) ; sans clé, rien ne change.

const MODEL_PATH: String = "res://models/yiero/yiero.glb"

# Repères de repos (doivent suivre models/yiero/src/yiero_shape.py).
const HEAD_Y: float = 30.0
const HEAD_HALF: float = 16.0
const MOUTH_HALF: float = 17.0
const EYE_X: float = 7.4
const EYE_Y: float = 35.5
const EYE_Z: float = 6.9
const EYE_R: float = 2.05
const EYE_DEPTH: float = 0.62
const FACE_Z: float = 9.6
const UPPER_ARM: float = 33.0
const FOREARM: float = 32.0
const SHOULDER: Vector3 = Vector3(25.5, 18.5, -3.0)
const CORNER_Y: float = 30.5
const FINGERS: PackedStringArray = ["index", "middle", "ring", "pinky", "thumb"]
const CHANNELS: PackedStringArray = ["squint_l", "squint_r", "pupil", "brow", "tilt", "neck", "breath", "breath_rate", "snarl", "pout", "drool", "drip", "gloss", "smoke", "claw_l", "claw_r", "twist_l", "twist_r", "wrist_l", "wrist_r", "shrug_l", "shrug_r", "spread_l", "spread_r", "index_l", "middle_l", "ring_l", "pinky_l", "thumb_l", "index_r", "middle_r", "ring_r", "pinky_r", "thumb_r"]
# Filets de bave : (x, y, z) d'attache en haut (repère de repos, os head) et en bas (os jaw).
const DROOL: Array = [
	[Vector3(-11.6, 27.4, -0.4), Vector3(-11.2, 21.8, 0.2)], [Vector3(-6.4, 24.0, 4.6), Vector3(-6.2, 18.6, 5.0)],
	[Vector3(2.4, 22.2, 6.6), Vector3(2.6, 17.0, 6.8)], [Vector3(8.6, 24.6, 4.0), Vector3(8.2, 19.4, 4.4)],
	[Vector3(12.4, 27.8, -0.8), Vector3(12.0, 22.4, -0.2)],
]

# Fenêtre du sourire (grin < 1 : fente qui s'ouvre du centre vers les coins), en repère de repos.
const GRIN_GLSL: String = """
uniform float grin = 1.0;
const float MZ0 = -6.0;
const float MTHC = 1.2;
const float MCY = 30.5;
const float MAU = 9.0;
const float MAL = 14.4;
float grin_open(vec3 r) {
	if (grin >= 0.999) return 1.0;
	float u = atan(r.x, r.z - MZ0) / MTHC;
	float uc = clamp(u, -1.0, 1.0);
	float up = MCY - MAU * (1.0 - uc * uc);
	float lo = MCY - MAL * (1.0 - uc * uc);
	float c = 0.5 * (up + lo) + 0.05;
	float hh = 0.5 * (up - lo) + 1.7;
	float g = clamp(grin, 0.0, 1.0);
	float extent = g * 1.14;
	float span = 1.0 - smoothstep(extent - 0.14, extent, abs(u));
	float lens = sqrt(max(0.0, 1.0 - pow(abs(u) / max(extent, 0.001), 2.0)));
	float height = hh * mix(0.12, 1.0, smoothstep(0.05, 0.9, g)) * lens;
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

# Ciel de la dimension (même dégradé et même éclipse que intro_dimension.gd) : ce que l'encre reflète.
const SKY_GLSL: String = """
uniform vec3 sun_dir = vec3(0.0, 0.42, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.46, 0.04, 0.03, 1.0);
uniform vec4 sky_zenith : source_color = vec4(0.02, 0.0, 0.008, 1.0);
uniform vec4 sky_glow : source_color = vec4(0.95, 0.18, 0.07, 1.0);
uniform float sky_dim = 1.0;
vec3 sky(vec3 d) {
	float h = d.y;
	vec3 col = mix(sky_horizon.rgb, sky_zenith.rgb, smoothstep(-0.05, 0.62, h));
	col = mix(col, sky_horizon.rgb * 0.12, smoothstep(-0.02, -0.3, h));
	float sun = max(dot(d, normalize(sun_dir)), 0.0);
	col += sky_glow.rgb * (pow(smoothstep(0.82, 0.997, sun), 3.0) * 1.3 + pow(sun, 8.0) * 0.2);
	return col * sky_dim;
}
"""

# Peau d'encre laquée (corps, gencives, gueule) ; variante FRINGE : pointes qui ondulent au vent.
const INK_SHADER: String = """
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
uniform float wind = 1.0;
uniform float crumple = 1.0;
uniform int debug_view = 0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.22, 0.1, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.82, 0.74, 0.86, 1.0);
varying vec3 rest;
varying vec4 mask;
varying vec3 wn;
varying vec3 wp;
varying float along;
varying float spec_k;
varying float diff_k;
%s
%s
%s
void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	along = UV2.y;
	mask = COLOR;
#ifdef FRINGE
	// les pointes ondulent (houle lente + frisson), la tempête les couche vers l'arrière
	float t = along * along;
	float ph = rest.x * 0.37 + rest.y * 0.23 + rest.z * 0.31;
	float w = clamp(wind, 0.0, 4.0);
	float sway = sin(clock * (1.3 + 0.5 * w) + ph) * 0.65 + sin(clock * (2.9 + 1.2 * w) + ph * 1.9) * 0.35;
	vec3 side = normalize(vec3(cos(ph * 2.3), 0.35 * sin(ph * 1.7), 0.0));
	VERTEX += side * sway * t * (0.9 + 0.7 * w);
	VERTEX += vec3(0.0, -0.25, -1.0) * t * max(w - 1.0, 0.0) * 2.4;
#endif
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float gum = mask.r;
	float mouth = mask.g;
	float ao = mask.b;
	float inner = clamp(gum + mouth, 0.0, 1.0);
	float open = grin_open(rest);
	vec3 n0 = normalize(wn);
	// papier froissé : plis très doux dans la normale (hors gueule)
	vec3 q = rest * 0.31;
	float e = 0.35;
	float h0 = yn(q);
	vec3 g = vec3(yn(q + vec3(e, 0.0, 0.0)) - h0, yn(q + vec3(0.0, e, 0.0)) - h0, yn(q + vec3(0.0, 0.0, e)) - h0) / e;
	vec3 gw = mat3(MODEL_MATRIX) * g;
	gw -= n0 * dot(gw, n0);
	vec3 nw = normalize(n0 - gw * 0.42 * crumple * (1.0 - inner));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 vw = normalize(CAMERA_POSITION_WORLD - wp);
	float ndv = clamp(dot(nw, vw), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.2);
	// coulures d'encre : filets brillants qui glissent vers le bas, plus vite quand ça bouge
	float lane = yn(vec3(rest.x * 0.55, 0.0, rest.z * 0.55) + 11.0);
	float streak = smoothstep(0.7, 0.78, lane) * smoothstep(0.92, 0.82, lane);
	float flow = fract(rest.y * 0.05 + clock * 0.09 * drip + lane * 7.0);
	float bead = smoothstep(0.0, 0.04, flow) * (1.0 - smoothstep(0.04, 0.22, flow));
	float wet = clamp(mask.a * 0.75 + streak * (0.35 + 0.65 * bead) * drip, 0.0, 1.0);
	// encre : noir profond, fibres du papier à peine visibles
	float fib = yn(rest * vec3(1.6, 0.35, 1.6)) * 0.6 + yn(rest * 4.1) * 0.4;
	vec3 ink = vec3(0.016, 0.012, 0.018) * (0.75 + 0.5 * fib) * ao;
	// gencives humides et gueule (plus sombre au fond)
	float depth = clamp((15.0 - length(rest.xz - vec2(0.0, -6.0))) / 9.0, 0.0, 1.0);
	vec3 gum_c = mix(vec3(0.62, 0.05, 0.07), vec3(0.3, 0.01, 0.03), clamp(1.0 - ao + depth * 0.5, 0.0, 1.0));
	vec3 mouth_c = mix(vec3(0.2, 0.012, 0.02), vec3(0.035, 0.0, 0.004), depth);
	vec3 alb = mix(ink, gum_c, gum);
	alb = mix(alb, mouth_c, mouth);
	float seen = mix(reveal, 1.0, inner) * mix(1.0, open, inner);
	ALBEDO = alb * seen;
	ROUGHNESS = mix(0.4, 0.12, wet);
	SPECULAR = 0.5;
	float face = smoothstep(19.0, 9.0, length((rest - vec3(0.0, 33.0, 8.0)) * vec3(0.85, 1.0, 0.7)));
	spec_k = mix((0.3 + 0.8 * wet) * gloss * reveal * (1.0 - 0.55 * face), 0.9 * open, inner);
	diff_k = mix(0.2 * reveal, 1.0, inner) * seen;
	// encre laquée : le ciel rouge glisse sur les volumes, liseré net côté éclipse
	vec3 r = reflect(-vw, nw);
	vec3 sky_r = sky(r);
	float k_refl = mix(0.05, 1.0, fres) * (0.3 + 0.7 * wet) * gloss * ao;
	vec3 em = sky_r * k_refl;
	float back = dot(nw, normalize(sun_dir));
	float edge = 1.0 - ndv;
	float rim_band = smoothstep(0.62, 0.7, edge) * smoothstep(-0.25, 0.3, back);
	em += rim_color.rgb * rim_band * (0.32 + 0.4 * (fib - 0.5)) * gloss;
	// reflet nacré (aplat) sur les bosses qui font face à la caméra : lit les volumes dans le noir
	float sheen = smoothstep(0.55, 0.6, yn(rest * 0.11 + vec3(0.0, 0.0, 3.0)) * ndv) * 0.0;
	em += sheen_color.rgb * sheen;
	em *= reveal * (1.0 - inner);
	// fureur : veines de braise qui affleurent
	float r1 = 1.0 - abs(2.0 * yn(rest * 0.13 + vec3(0.0, clock * 0.03, 0.0)) - 1.0);
	float r2 = 1.0 - abs(2.0 * yn(rest * 0.31 + vec3(7.0, 2.0, clock * 0.05)) - 1.0);
	float crack = smoothstep(0.945, 0.99, r1) * smoothstep(0.3, 0.6, r2) + smoothstep(0.965, 0.995, r2) * smoothstep(0.72, 0.95, r1) * 0.8;
	crack *= smoothstep(0.4, 0.66, yn(rest * 0.07 + vec3(5.0, 1.0, 3.0))) * (1.0 - 0.8 * face);
	em += vec3(1.0, 0.24, 0.06) * crack * fury * (0.7 + 0.3 * sin(clock * 4.0 + rest.y * 0.25)) * 1.5 * (1.0 - inner) * reveal * ao;
	em += hurt_color.rgb * hurt * (0.08 + fres * 1.3) * (1.0 - inner);
	// gueule : gencives qui luisent dans le noir, gorge brûlante quand elle s'ouvre
	float throat = (0.25 + jaw * 1.5 + fury * 0.5) * depth * depth;
	em += gum_c * gum * (0.22 + 0.26 * glow) * open;
	em += vec3(0.75, 0.06, 0.03) * mouth * throat * open * (0.85 + 0.15 * sin(clock * 3.1));
	EMISSION = em;
	if (debug_view == 1) { ALBEDO = vec3(0.0); EMISSION = mask.rgb; }
	if (debug_view == 2) { ALBEDO = vec3(0.0); EMISSION = vec3(wet); }
	if (debug_view == 3) { ALBEDO = vec3(0.0); EMISSION = fract(rest * 0.1); }
	if (debug_view == 4) { ALBEDO = vec3(0.0); EMISSION = vec3(open); }
	if (debug_view == 5) { ALBEDO = vec3(0.0); EMISSION = nw * 0.5 + 0.5; }
	if (debug_view == 6) { ALBEDO = vec3(0.0); EMISSION = sky_r * k_refl; }
	if (debug_view == 7) { ALBEDO = vec3(0.0); spec_k = 0.0; diff_k = 0.0; }
	if (debug_view == 8) { EMISSION = vec3(0.0); }
	if (debug_view == 9) { ALBEDO = vec3(0.0); spec_k = 0.0; diff_k = 0.0; EMISSION = vec3(ndv); }
	if (debug_view == 10) { ALBEDO = vec3(0.0); spec_k = 0.0; diff_k = 0.0; EMISSION = vec3(0.07 + 0.6 * max(dot(n0, normalize(vec3(0.35, 0.8, -0.5))), 0.0) + 0.15 * max(dot(n0, normalize(vec3(-0.6, 0.2, 0.7))), 0.0)) * mix(vec3(0.75, 0.72, 0.7), vec3(0.9, 0.3, 0.3), gum); }
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 hv = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, hv), 0.0);
	float lobe = pow(ndh, 110.0);
	float aa = clamp(fwidth(lobe) * 1.5, 0.01, 0.2);
	float hard = smoothstep(0.55 - aa, 0.55 + aa, lobe);
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.333))), 0.55);
	SPECULAR_LIGHT += lc * ATTENUATION * (hard * 0.9 + lobe * 0.3) * spec_k * step(0.0, ndl);
	float band = smoothstep(0.02, 0.1, ndl * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * mix(0.25, 1.0, band) * max(ndl, 0.0) * diff_k / PI;
}
"""

const TEETH_SHADER: String = """
shader_type spatial;
render_mode cull_back;
uniform float glow = 1.0;
uniform float reveal = 1.0;
uniform float hurt = 0.0;
uniform float fury = 0.0;
uniform float wet = 0.85;
uniform vec4 ivory : source_color = vec4(0.94, 0.89, 0.76, 1.0);
uniform vec4 stain : source_color = vec4(0.42, 0.27, 0.16, 1.0);
uniform vec4 shade : source_color = vec4(0.5, 0.3, 0.26, 1.0);
varying vec3 rest;
varying float along;
varying float vis;
%s
void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	along = UV2.y;
}
void fragment() {
	float open = grin_open(rest);
	vis = open;
	vec3 base = mix(stain.rgb, ivory.rgb, smoothstep(0.0, 0.42, along));
	base = mix(base, vec3(1.0, 0.98, 0.92), smoothstep(0.72, 1.0, along) * 0.55);
	ALBEDO = base * open;
	ROUGHNESS = 0.3;
	EMISSION = base * open * (0.07 + 0.13 * glow) + vec3(1.0, 0.8, 0.45) * hurt * 0.4 * open + vec3(0.6, 0.08, 0.04) * fury * 0.08 * open;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float aa = clamp(length(fwidth(NORMAL)) * 0.5, 0.02, 0.2);
	float lit = smoothstep(0.1 - aa, 0.1 + aa, ndl * ATTENUATION);
	vec3 ramp = mix(shade.rgb * 0.5, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp * max(ndl, 0.3) / PI;
	vec3 hv = normalize(LIGHT + VIEW);
	float sp = pow(max(dot(NORMAL, hv), 0.0), 70.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.3, 0.42, sp) * wet * vis * 0.8;
}
"""

const CLAW_SHADER: String = """
shader_type spatial;
render_mode cull_back;
uniform float reveal = 1.0;
uniform float hurt = 0.0;
uniform float glow = 1.0;
uniform vec3 sun_dir = vec3(0.0, 0.42, 1.0);
uniform vec4 root_c : source_color = vec4(0.03, 0.02, 0.022, 1.0);
uniform vec4 tip_c : source_color = vec4(0.72, 0.64, 0.52, 1.0);
varying float along;
varying vec3 wn;
varying vec3 wp;
void vertex() {
	along = UV2.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 base = mix(root_c.rgb, tip_c.rgb, smoothstep(0.35, 0.98, along));
	vec3 vw = normalize(CAMERA_POSITION_WORLD - wp);
	float ndv = clamp(dot(normalize(wn), vw), 0.0, 1.0);
	float rim = smoothstep(0.6, 0.68, 1.0 - ndv) * smoothstep(-0.3, 0.3, dot(normalize(wn), normalize(sun_dir)));
	ALBEDO = base * mix(0.3, 1.0, reveal);
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
	EMISSION = base * (0.03 + 0.05 * glow) * smoothstep(0.45, 1.0, along) + vec3(1.0, 0.24, 0.1) * rim * 0.45 * reveal + vec3(1.0, 0.8, 0.45) * hurt * 0.3;
}
"""

const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform float width_px = 1.8;
uniform float max_world = 0.45;
uniform vec4 color : source_color = vec4(0.012, 0.006, 0.01, 1.0);
void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec4 clip = PROJECTION_MATRIX * view_position;
	vec2 clip_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float nl = length(clip_normal);
	vec2 dir = nl > 0.0001 ? clip_normal / nl : vec2(0.0);
	float px = width_px * clamp(VIEWPORT_SIZE.y / 1080.0, 0.7, 2.0);
	// limite en unités du monde : en très gros plan le trait ne devient pas une barre
	float world_px = max_world / max(-view_position.z, 0.01) * PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * 0.5;
	px = min(px, world_px);
	clip.xy += dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}
void fragment() { ALBEDO = color.rgb; }
"""

const EYE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
uniform vec3 look = vec3(0.0, 0.0, 1.0);
uniform float pupil = 0.13;
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
	float front = clamp(d.z, 0.0, 1.0);
	// globe pâle, lumineux au centre ; le bord (dans l'orbite) s'assombrit en ocre
	vec3 scl = mix(vec3(0.66, 0.6, 0.5), vec3(0.9, 0.87, 0.78), smoothstep(0.0, 0.7, front));
	scl = mix(scl, vec3(1.0, 0.97, 0.9), smoothstep(0.75, 1.0, front) * 0.5);
	float vein = smoothstep(0.62, 0.7, yn(d * 7.0 + 4.0)) * smoothstep(0.75, 0.2, front);
	vein += smoothstep(0.66, 0.72, yn(d * 15.0 + 9.0)) * smoothstep(0.6, 0.1, front) * 0.6;
	scl = mix(scl, vec3(0.6, 0.06, 0.05), clamp(vein, 0.0, 1.0) * (0.25 + 0.7 * fury));
	scl = mix(scl, vec3(1.0, 0.6, 0.45), fury * 0.35);
	// iris gris à peine marqué, pupille minuscule en tête d'épingle
	float iris = 1.0 - smoothstep(pupil * 1.7, pupil * 2.8, ang);
	vec3 c = mix(scl, scl * vec3(0.66, 0.63, 0.6), iris * 0.5);
	float ring = 1.0 - smoothstep(pupil * 0.86, pupil * 1.02, ang);
	c = mix(c, vec3(0.015, 0.006, 0.006), ring);
	ALBEDO = c * glow * 1.08 + vec3(1.0, 0.8, 0.45) * hurt * 0.3;
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
	float a = pow(max(0.0, 1.0 - r), 2.4);
	ALBEDO = color.rgb * energy * a;
	ALPHA = a;
}
"""

# Fumée d'encre : nappes face caméra, bruit qui monte et s'effiloche, liseré rouge côté éclipse.
const SMOKE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float clock = 0.0;
uniform float wind = 1.0;
uniform float density = 1.0;
uniform float reveal = 1.0;
uniform float seed = 0.0;
uniform vec4 ink : source_color = vec4(0.012, 0.004, 0.008, 1.0);
uniform vec4 rim : source_color = vec4(0.62, 0.1, 0.05, 1.0);
%s
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float w = clamp(wind, 0.0, 4.0);
	vec3 p = vec3(uv.x * 1.6 + seed * 7.0 + w * clock * 0.06, uv.y * 1.4 - clock * (0.22 + 0.1 * w), clock * 0.05 + seed);
	float n = yn(p * 1.3) * 0.55 + yn(p * 2.9 + 4.0) * 0.3 + yn(p * 6.1 + 9.0) * 0.15;
	float fall = 1.0 - smoothstep(0.35, 1.0, length(uv * vec2(1.0, 0.85)));
	float a = smoothstep(0.42, 0.78, n * fall + fall * 0.22) * fall;
	a *= density * 0.85;
	float edge = smoothstep(0.1, 0.45, a) * (1.0 - smoothstep(0.45, 0.85, a));
	ALBEDO = mix(ink.rgb, rim.rgb, edge * 0.55 * reveal);
	ALPHA = clamp(a, 0.0, 0.92);
}
"""

const DROOL_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform float reveal = 1.0;
uniform vec3 sun_dir = vec3(0.0, 0.42, 1.0);
void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	vec3 n = normalize(NORMAL);
	ALBEDO = vec3(0.025, 0.01, 0.014);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = vec3(0.55, 0.07, 0.05) * smoothstep(0.55, 0.85, across) * 0.6 + vec3(0.5, 0.05, 0.04) * 0.08;
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
var pout: float = 0.0
var drool: float = 1.0
var drip: float = 1.0
var gloss: float = 1.0
var smoke: float = 1.0
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
var _chip_rest: Vector3 = Vector3(-2.6, 20.6, 9.6)
var _head_follow: Node3D
var _jaw_follow: Node3D
var _chest_follow: Node3D
var _eyes: Array[MeshInstance3D] = []
var _eye_mats: Array[ShaderMaterial] = []
var _halos: Array[MeshInstance3D] = []
var _eye_lights: Array[OmniLight3D] = []
var _mouth_light: OmniLight3D
var _ink: ShaderMaterial
var _fringe: ShaderMaterial
var _teeth: ShaderMaterial
var _claw: ShaderMaterial
var _halo: ShaderMaterial
var _smoke_mat: Array[ShaderMaterial] = []
var _smoke_nodes: Array[MeshInstance3D] = []
var _drool_mesh: ImmediateMesh
var _drool_node: MeshInstance3D
var _drool_mat: ShaderMaterial
var _built: bool = false
var _film: Object = null
var _film_checked: bool = false
var _film_keys: int = -1
var _film_has_channels: bool = false

# Squelette : index, parents, ordre parent → enfant, poses de repos globales (repère du squelette).
var _bone: Dictionary = {}
var _parent: PackedInt32Array = PackedInt32Array()
var _order: PackedInt32Array = PackedInt32Array()
var _rest_g: Array[Transform3D] = []
var _rest_l: Array[Transform3D] = []
var _pose_g: Array[Transform3D] = []
var _arm: Array = [{}, {}]
var _ink_y: float = 0.0

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
	if skeletons.is_empty():
		push_error("PaperYiero : squelette introuvable dans " + MODEL_PATH)
		return
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
	_chest_follow = Node3D.new();_chest_follow.name = "ChestFollow";_skel.add_child(_chest_follow)
	if is_instance_valid(_chip):
		var aabb: AABB = _chip.mesh.get_aabb()
		_chip_rest = aabb.get_center()
		_chip.get_parent().remove_child(_chip)
		_head_follow.add_child(_chip)
		_chip.material_override = _teeth
	_build_eyes()
	_build_smoke()
	_build_drool()
	_mouth_light = OmniLight3D.new();_mouth_light.name = "MouthLight";_mouth_light.light_color = Color("ff2a14");_mouth_light.omni_range = 30.0;_mouth_light.light_energy = 0.0;_mouth_light.shadow_enabled = false
	_jaw_follow.add_child(_mouth_light);_mouth_light.position = Vector3(0, 19.0, 2.0)
	_sync_sky()
	pose()

func _shader(code: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = code
	return shader

func _materials() -> void :
	var ink_code: String = INK_SHADER % [GRIN_GLSL, NOISE_GLSL, SKY_GLSL]
	_ink = ShaderMaterial.new();_ink.shader = _shader(ink_code)
	_fringe = ShaderMaterial.new();_fringe.shader = _shader(ink_code.replace("shader_type spatial;", "shader_type spatial;\n#define FRINGE"))
	var outline: Shader = _shader(OUTLINE_SHADER)
	_teeth = ShaderMaterial.new();_teeth.shader = _shader(TEETH_SHADER % GRIN_GLSL)
	var teeth_line: ShaderMaterial = ShaderMaterial.new();teeth_line.shader = outline
	teeth_line.set_shader_parameter("width_px", 1.6);teeth_line.set_shader_parameter("max_world", 0.09)
	_teeth.next_pass = teeth_line
	_claw = ShaderMaterial.new();_claw.shader = _shader(CLAW_SHADER)
	var claw_line: ShaderMaterial = ShaderMaterial.new();claw_line.shader = outline
	claw_line.set_shader_parameter("width_px", 1.8);claw_line.set_shader_parameter("max_world", 0.12)
	_claw.next_pass = claw_line
	_halo = ShaderMaterial.new();_halo.shader = _shader(HALO_SHADER)

func _assign_materials() -> void :
	if not is_instance_valid(_mesh): return
	var mesh: Mesh = _mesh.mesh
	for i: int in range(mesh.get_surface_count()):
		var source: Material = mesh.surface_get_material(i)
		var label: String = source.resource_name if source != null else ""
		if label.is_empty(): label = str(mesh.get("surface_%d/name" % i))
		var material: Material = _ink
		if label.contains("teeth"): material = _teeth
		elif label.contains("claw"): material = _claw
		elif label.contains("fringe"): material = _fringe
		_mesh.set_surface_override_material(i, material)

# Direction de l'éclipse dans le repère monde : celle du ciel de la dimension, si le film en a une.
func _sync_sky() -> void :
	var film: Object = _find_film()
	var sun: Vector3 = Vector3(0.0, 0.42, 1.0)
	if film != null:
		var dim: Variant = film.get("dimension")
		if dim is Node3D and is_instance_valid(dim):
			var material: Variant = (dim as Node3D).get("sky_material")
			if material is ShaderMaterial:
				var value: Variant = (material as ShaderMaterial).get_shader_parameter("sun_dir")
				if value is Vector3: sun = (dim as Node3D).global_transform.basis * (value as Vector3)
	sun = sun.normalized()
	for material: ShaderMaterial in [_ink, _fringe, _claw]:
		material.set_shader_parameter("sun_dir", sun)
	if is_instance_valid(_drool_mat): _drool_mat.set_shader_parameter("sun_dir", sun)

func _read_skeleton() -> void :
	var count: int = _skel.get_bone_count()
	_parent.resize(count)
	_rest_g.resize(count);_rest_l.resize(count);_pose_g.resize(count)
	for i: int in range(count):
		_bone[_skel.get_bone_name(i)] = i
		_parent[i] = _skel.get_bone_parent(i)
		_rest_l[i] = _skel.get_bone_rest(i)
	# ordre parent → enfant (ne suppose rien sur l'ordre des os du fichier)
	var done: Dictionary = {}
	while _order.size() < count:
		for i: int in range(count):
			if done.has(i): continue
			if _parent[i] < 0 or done.has(_parent[i]):
				_order.append(i);done[i] = true
	for i: int in _order:
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
		arm["palm"] = w + fwd * 5.0 - upv * 0.3
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
	sphere.radius = EYE_R;sphere.height = EYE_R * 2.0;sphere.radial_segments = 36;sphere.rings = 18
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(EYE_R * 7.5, EYE_R * 7.5)
	var eye_shader: Shader = _shader(EYE_SHADER % NOISE_GLSL)
	for side: int in [-1, 1]:
		var material: ShaderMaterial = ShaderMaterial.new();material.shader = eye_shader
		var eye: MeshInstance3D = MeshInstance3D.new();eye.name = "Eye";eye.mesh = sphere;eye.material_override = material
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_follow.add_child(eye);eye.position = Vector3(side * EYE_X, EYE_Y, EYE_Z)
		_eyes.append(eye);_eye_mats.append(material)
		var halo: MeshInstance3D = MeshInstance3D.new();halo.name = "Halo";halo.mesh = quad;halo.material_override = _halo
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_follow.add_child(halo);halo.position = Vector3(side * EYE_X, EYE_Y, EYE_Z + EYE_R + 1.2)
		_halos.append(halo)
		var light: OmniLight3D = OmniLight3D.new();light.light_color = Color("f3e6c8");light.omni_range = 9.0;light.light_energy = 0.0
		light.shadow_enabled = false
		_head_follow.add_child(light);light.position = Vector3(side * EYE_X, EYE_Y, EYE_Z + EYE_R + 2.2)
		_eye_lights.append(light)

# Fumée : nappes accrochées derrière le crâne et sur les épaules (repère de repos).
func _build_smoke() -> void :
	var shader: Shader = _shader(SMOKE_SHADER % NOISE_GLSL)
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(1.0, 1.0)
	var spots: Array = [
		[Vector3(0.0, 58.0, -14.0), 34.0, 0], [Vector3(-14.0, 52.0, -16.0), 28.0, 0], [Vector3(15.0, 53.0, -15.0), 30.0, 0],
		[Vector3(-22.0, 40.0, -18.0), 26.0, 0], [Vector3(23.0, 41.0, -17.0), 26.0, 0], [Vector3(0.0, 46.0, -24.0), 36.0, 0],
		[Vector3(-27.0, 30.0, -12.0), 22.0, 1], [Vector3(28.0, 31.0, -12.0), 22.0, 1], [Vector3(0.0, 36.0, -30.0), 40.0, 1],
	]
	for k: int in range(spots.size()):
		var row: Array = spots[k]
		var material: ShaderMaterial = ShaderMaterial.new();material.shader = shader
		material.set_shader_parameter("seed", float(k) * 1.37)
		material.render_priority = -1
		var node: MeshInstance3D = MeshInstance3D.new();node.name = "Smoke%d" % k;node.mesh = quad;node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 30.0
		(_head_follow if int(row[2]) == 0 else _chest_follow).add_child(node)
		node.position = row[0];node.scale = Vector3(float(row[1]), float(row[1]) * 1.25, 1.0)
		_smoke_mat.append(material);_smoke_nodes.append(node)

func _build_drool() -> void :
	_drool_mesh = ImmediateMesh.new()
	_drool_node = MeshInstance3D.new();_drool_node.name = "Drool";_drool_node.mesh = _drool_mesh
	_drool_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drool_mat = ShaderMaterial.new();_drool_mat.shader = _shader(DROOL_SHADER)
	_drool_node.material_override = _drool_mat
	_drool_node.extra_cull_margin = 40.0
	_skel.add_child(_drool_node)




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
	if not (keys is Dictionary): return
	var dict: Dictionary = keys
	if dict.size() != _film_keys:
		_film_keys = dict.size()
		_film_has_channels = false
		for key: Variant in dict.keys():
			if str(key).begins_with("yiero_"):
				_film_has_channels = true
				break
	if not _film_has_channels: return
	var t: float = float(_film.get("elapsed"))
	squint_eye[0] = _ch("squint_l", t, squint_eye[0]);squint_eye[1] = _ch("squint_r", t, squint_eye[1])
	pupil = _ch("pupil", t, pupil);brow = _ch("brow", t, brow);head_tilt = _ch("tilt", t, head_tilt)
	neck_reach = _ch("neck", t, neck_reach);breath = _ch("breath", t, breath);breath_rate = _ch("breath_rate", t, breath_rate)
	snarl = _ch("snarl", t, snarl);pout = _ch("pout", t, pout);drool = _ch("drool", t, drool)
	drip = _ch("drip", t, drip);gloss = _ch("gloss", t, gloss);smoke = _ch("smoke", t, smoke)
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
		"eye_l": return _eyes[0].global_transform * Vector3(0, 0, EYE_R)
		"eye_r": return _eyes[1].global_transform * Vector3(0, 0, EYE_R)
		"eyes": return (socket("eye_l") + socket("eye_r")) * 0.5
		"mouth": return (head * Vector3(0, 21.0, 7.0) + jaw_x * Vector3(0, 16.8, 7.0)) * 0.5
		"teeth": return head * _chip_rest
		"chin": return jaw_x * Vector3(0, 9.0, 8.8)
		"head": return head * Vector3(0, 30.0, 0.0)
		"face": return head * Vector3(0, 30.0, FACE_Z)
		"brow": return head * Vector3(0, 39.6, 10.8)
		"nose": return head * Vector3(0, 32.4, 11.2)
		"throat": return (head * Vector3(0, 21.0, -2.0) + jaw_x * Vector3(0, 17.0, -2.0)) * 0.5
		"tongue": return jaw_x * Vector3(0, 16.4, 3.0)
		"hand_l": return xf * (_delta(_arm[0].hand) * (_arm[0].palm as Vector3))
		"hand_r": return xf * (_delta(_arm[1].hand) * (_arm[1].palm as Vector3))
		"grip_l", "grip_r":
			var k: int = 0 if name_value == "grip_l" else 1
			var palm: Vector3 = _arm[k].palm
			return xf * (_delta(_arm[k].hand) * (palm + (_arm[k].hand_fwd as Vector3) * 2.6 - (_arm[k].hand_up as Vector3) * 2.8))
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
func _tip(side: int, finger: int) -> Vector3:
	var tip: int = int(_arm[side].tips[finger])
	if tip < 0: return _skel.global_transform * _pose_g[_arm[side].hand].origin
	return _skel.global_transform * _pose_g[tip].origin

func _pinch(side: int) -> Vector3:
	return _tip(side, 0).lerp(_tip(side, 4), 0.5)




func pose() -> void :
	if not _built or not is_instance_valid(_skel): return
	_channels()
	var shake: Vector3 = Vector3(sin(clock * 37.0) + sin(clock * 23.0 + 1.0), sin(clock * 41.0 + 2.0), sin(clock * 29.0 + 0.5)) * tremble * 0.35
	# souffle : inspiration lente, expiration un peu plus rapide (pas une sinusoïde mécanique)
	var phase: float = clock * 0.85 * breath_rate
	var inhale: float = (sin(phase) + 0.22 * sin(phase * 2.0 + 0.8)) * breath
	var heave: float = inhale * 0.55
	_body.position = Vector3(0, lerpf(-58.0, 0.0, rise) + heave, lean * 0.75) + shake
	_body.rotation = Vector3(0, 0, _wave(0.37, 0.23, 0.4) * 0.012)
	for i: int in _order: _pose_g[i] = _fk(i)
	# buste : avancée (lean), souffle
	var hunch: float = lean * 0.006
	_rotated(_bone.root, Basis.IDENTITY)
	_rotated(_bone.spine, Basis(Vector3.RIGHT, hunch * 0.5 + _wave(0.21, 0.13, 1.0) * 0.006))
	_rotated(_bone.chest, Basis(Vector3.RIGHT, hunch * 0.5 - inhale * 0.014) * Basis(Vector3.UP, _wave(0.17, 0.29, 2.0) * 0.01))
	# cou et tête : tangage / lacet / roulis répartis, inclinaison curieuse, petits mouvements vivants
	var idle_p: float = _wave(0.31, 0.53, 0.2) * 0.012
	var idle_y: float = _wave(0.23, 0.41, 1.3) * 0.015
	var idle_r: float = sin(clock * 0.53) * 0.02
	var tilt: float = head_tilt
	var neck_b: Basis = Basis(Vector3.UP, head_yaw * 0.4) * Basis(Vector3.RIGHT, head_pitch * 0.35 + inhale * 0.008) * Basis(Vector3.BACK, head_roll * 0.3 + tilt * 0.4)
	_rotated(_bone.neck, neck_b, Vector3(0, 0, neck_reach * 0.55))
	var head_b: Basis = Basis(Vector3.UP, head_yaw * 0.6 + idle_y) * Basis(Vector3.RIGHT, head_pitch * 0.65 + idle_p) * Basis(Vector3.BACK, head_roll * 0.7 + tilt * 0.6 + idle_r)
	_rotated(_bone.head, head_b, Vector3(0, 0, neck_reach * 0.45))
	# mâchoire : rotation autour de la charnière + décrochage (gueule de serpent)
	var j: float = clampf(jaw, 0.0, 1.25)
	_rotated(_bone.jaw, Basis(Vector3.RIGHT, j * 0.5), Vector3(0, -j * 3.6, j * 1.2))
	# lèvres : babines retroussées (snarl), moue (pout)
	_rotated(_bone.lip_up, Basis.IDENTITY, Vector3(0, snarl * 1.5 - pout * 0.4, pout * 0.8 - snarl * 0.2))
	_rotated(_bone.lip_lo, Basis.IDENTITY, Vector3(0, -snarl * 0.9 + pout * 0.5, pout * 0.9))
	# visage : commissures, sourcils, pommettes (pas de paupières : le plissement vient de là)
	var wide: float = clampf(grin_wide - 1.0, -0.3, 0.5)
	for side: int in [0, 1]:
		var sx: float = -1.0 if side == 0 else 1.0
		var tag: String = "_l" if side == 0 else "_r"
		var sq: float = clampf(squint + squint_eye[side], 0.0, 1.3)
		var corner: Vector3 = Vector3(sx * wide * 3.6 - sx * pout * 1.6, wide * 2.6 + snarl * 1.0 - pout * 0.6, -wide * 1.6 + pout * 0.8)
		_rotated(_bone["corner" + tag], Basis.IDENTITY, corner)
		var frown: float = clampf(brow + fury * 0.5, -1.0, 1.5)
		_rotated(_bone["brow" + tag], Basis.IDENTITY, Vector3(-sx * frown * 0.3, -sq * 2.0 - frown * 0.9, sq * 0.55 + frown * 0.3))
		_rotated(_bone["cheek" + tag], Basis.IDENTITY, Vector3(0, sq * 1.3 + wide * 1.5 + snarl * 0.6, sq * 0.4))
	_ink_y = (_skel.global_transform.affine_inverse() * global_position).y
	for side: int in [0, 1]: _pose_arm(side, inhale)
	for i: int in range(_pose_g.size()):
		var p: int = _parent[i]
		var local: Transform3D = _pose_g[i] if p < 0 else _pose_g[p].affine_inverse() * _pose_g[i]
		_skel.set_bone_pose_position(i, local.origin)
		_skel.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
	_head_follow.transform = _delta(_bone.head)
	_jaw_follow.transform = _delta(_bone.jaw)
	_chest_follow.transform = _delta(_bone.chest)
	_pose_eyes()
	_pose_chip()
	_pose_drool(j)
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
	var lift: float = shrug[side] * 0.28 + inhale * 0.012 + _wave(0.27, 0.19, float(side) * 2.0) * 0.008
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
	var ru: Basis = _frame(u1, n1) * _frame(arm.u0, arm.n0).inverse()
	_pose_g[up_i] = Transform3D(ru * _rest_g[up_i].basis, s)
	var rf: Basis = _frame(f1, n1) * _frame(arm.f0, arm.n0).inverse()
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
	var up_h: Vector3 = (Vector3.UP - fwd_h * fwd_h.y).normalized()
	var twist: float = hand_twist[side] + hold * 1.15 * -sx
	up_h = up_h.rotated(fwd_h, twist)
	var side_h: Vector3 = fwd_h.cross(up_h).normalized()
	var pitch: float = hand_pitch[side] + _wave(0.6, 0.37, float(side) * 3.0) * 0.03
	fwd_h = fwd_h.rotated(side_h, -pitch);up_h = up_h.rotated(side_h, -pitch)
	var hb: Basis = _frame(fwd_h, up_h) * _frame(fwd0, up0).inverse()
	_pose_g[ha_i] = Transform3D(hb * _rest_g[ha_i].basis, w)
	# doigts : flexion phalange par phalange, écartement, frémissements décalés d'un doigt à l'autre
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
		var tip: int = int(arm.tips[k])
		if tip >= 0:
			_pose_g[tip] = _fk(tip)
			_rest_on_ink(chain, tip, w)

# Main près de l'encre : un doigt dont la griffe passerait sous la surface se relève autour de sa
# première phalange (la main s'appuie sur l'encre comme une araignée au lieu de s'y enfoncer).
func _rest_on_ink(chain: Array[int], tip: int, wrist: Vector3) -> void :
	var floor_y: float = _ink_y + 0.35
	var weight: float = smoothstep(floor_y + 0.5, floor_y + 4.0, wrist.y)
	if weight <= 0.0: return
	var j0: Vector3 = _pose_g[chain[0]].origin
	var t: Vector3 = _pose_g[tip].origin
	var deficit: float = (floor_y - t.y) * weight
	if deficit <= 0.0: return
	var v: Vector3 = t - j0
	var axis: Vector3 = v.cross(Vector3.UP)
	if axis.length_squared() < 1e-6: return
	var ang: float = asin(clampf(deficit / maxf(v.length(), 0.1), 0.0, 0.95))
	var r: Basis = Basis(axis.normalized(), ang)
	var pivot: Transform3D = Transform3D(r, j0 - r * j0)
	for bone: int in [chain[0], chain[1], chain[2], tip]:
		_pose_g[bone] = pivot * _pose_g[bone]

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
		eye.scale = Vector3(s * (1.0 + sq * 0.06), s * (1.0 - sq * 0.42), s * EYE_DEPTH * (1.0 - sq * 0.2))
		eye.position = Vector3((-1.0 if k == 0 else 1.0) * EYE_X, EYE_Y - sq * 0.55, EYE_Z - sq * 0.3)
		eye.visible = open > 0.002
		_halos[k].visible = eye.visible
		var look: Vector3 = Vector3(0, 0, 1)
		if look_target.is_finite():
			var local: Vector3 = (eye.global_transform.affine_inverse() * look_target)
			local = Vector3(local.x, local.y, local.z * EYE_DEPTH * EYE_DEPTH)
			if local.length_squared() > 0.01:
				look = local.normalized()
				# les globes tournent peu : la pupille reste dans un cône de 38°
				var ang: float = acos(clampf(look.z, -1.0, 1.0))
				var lim: float = deg_to_rad(38.0)
				if ang > lim:
					var flat: Vector2 = Vector2(look.x, look.y).normalized()
					look = Vector3(flat.x * sin(lim), flat.y * sin(lim), cos(lim))
		# micro-saccades : petits sauts irréguliers du regard
		var beat: float = floor(clock * 1.7 + float(k) * 0.37)
		var jitter: Vector2 = Vector2(sin(beat * 12.9898), cos(beat * 78.233)) * 0.012
		look = (look + Vector3(jitter.x, jitter.y, 0.0)).normalized()
		var material: ShaderMaterial = _eye_mats[k]
		material.set_shader_parameter("look", look)
		material.set_shader_parameter("pupil", 0.13 * clampf(pupil, 0.3, 2.2) * (1.0 - fury * 0.25))
		material.set_shader_parameter("glow", eye_glow * (1.0 + fury * 0.3))
		material.set_shader_parameter("fury", fury)
		material.set_shader_parameter("hurt", hurt)
		_eye_lights[k].light_energy = eye_glow * open * 1.2
	_halo.set_shader_parameter("energy", 0.17 * eye_glow * (1.0 + fury * 0.6) * open)
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

# Filets de bave d'encre : chaînettes entre gencive du haut et du bas, qui s'étirent puis cassent.
func _pose_drool(j: float) -> void :
	_drool_mesh.clear_surfaces()
	var amount: float = clampf(drool, 0.0, 1.0) * smoothstep(0.12, 0.35, j) * clampf(grin, 0.0, 1.0)
	_drool_node.visible = amount > 0.01
	if not _drool_node.visible: return
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null: return
	var skel_inv: Transform3D = _skel.global_transform.affine_inverse()
	var eye_local: Vector3 = skel_inv * camera.global_position
	var head: Transform3D = _delta(_bone.head)
	var jaw_x: Transform3D = _delta(_bone.jaw)
	_drool_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in range(DROOL.size()):
		var row: Array = DROOL[k]
		var a: Vector3 = head * (row[0] as Vector3)
		var b: Vector3 = jaw_x * (row[1] as Vector3)
		var span: float = a.distance_to(b)
		# chaque filet casse à son propre allongement (les plus courts d'abord)
		var limit: float = 11.0 + float(k % 3) * 3.5
		if span > limit: continue
		var stretch: float = clampf(span / limit, 0.0, 1.0)
		var sag: float = (1.0 - stretch) * 2.4 + 0.6
		var near: float = clampf(eye_local.distance_to((a + b) * 0.5) / 30.0, 0.22, 1.0)
		var width: float = lerpf(0.5, 0.1, stretch) * amount * near
		var steps: int = 8
		var prev_l: Vector3 = Vector3.ZERO
		var prev_r: Vector3 = Vector3.ZERO
		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			var p: Vector3 = a.lerp(b, t) + Vector3(0, -sin(t * PI) * sag, 0) + Vector3(sin(clock * 2.1 + float(k)) * 0.25 * sin(t * PI), 0, 0)
			var tangent: Vector3 = (b - a).normalized()
			var to_eye: Vector3 = (eye_local - p).normalized()
			var side_v: Vector3 = tangent.cross(to_eye)
			side_v = side_v.normalized() if side_v.length_squared() > 1e-6 else Vector3.RIGHT
			var wt: float = width * (0.55 + 0.45 * sin(t * PI) * (1.0 - stretch) + 0.45 * (1.0 - sin(t * PI)))
			var l: Vector3 = p - side_v * wt
			var r: Vector3 = p + side_v * wt
			if i > 0:
				for v: Array in [[prev_l, 0.0], [prev_r, 1.0], [r, 1.0], [prev_l, 0.0], [r, 1.0], [l, 0.0]]:
					_drool_mesh.surface_set_normal(to_eye)
					_drool_mesh.surface_set_uv(Vector2(float(v[1]), t))
					_drool_mesh.surface_add_vertex(v[0] as Vector3)
			prev_l = l;prev_r = r
	_drool_mesh.surface_end()
	if _drool_mesh.get_surface_count() > 0: _drool_mesh.surface_set_material(0, _drool_mat)

func _update_materials() -> void :
	var j: float = clampf(jaw, 0.0, 1.25)
	for material: ShaderMaterial in [_ink, _fringe]:
		material.set_shader_parameter("reveal", reveal)
		material.set_shader_parameter("hurt", hurt)
		material.set_shader_parameter("fury", fury)
		material.set_shader_parameter("clock", clock)
		material.set_shader_parameter("grin", grin)
		material.set_shader_parameter("glow", eye_glow)
		material.set_shader_parameter("jaw", j)
		material.set_shader_parameter("drip", drip)
		material.set_shader_parameter("gloss", gloss)
		material.set_shader_parameter("wind", wind)
		material.set_shader_parameter("debug_view", debug_view)
	_teeth.set_shader_parameter("grin", grin)
	_teeth.set_shader_parameter("glow", eye_glow)
	_teeth.set_shader_parameter("reveal", reveal)
	_teeth.set_shader_parameter("hurt", hurt)
	_teeth.set_shader_parameter("fury", fury)
	_claw.set_shader_parameter("reveal", reveal)
	_claw.set_shader_parameter("hurt", hurt)
	_claw.set_shader_parameter("glow", eye_glow)
	_drool_mat.set_shader_parameter("reveal", reveal)
	for k: int in range(_smoke_mat.size()):
		var material: ShaderMaterial = _smoke_mat[k]
		material.set_shader_parameter("clock", clock)
		material.set_shader_parameter("wind", wind)
		material.set_shader_parameter("density", clampf(smoke, 0.0, 2.0) * lerpf(0.35, 1.0, reveal))
		material.set_shader_parameter("reveal", reveal)
		_smoke_nodes[k].visible = smoke > 0.01
	_mouth_light.light_energy = (j * 3.0 * reveal + fury * 1.5) * clampf(grin, 0.0, 1.0)
