class_name GraphicsQuality
extends RefCounted
## Tabella dei preset grafici (restyling 2026-10-11, spec §5.2) e loro applicazione a
## Environment e sole. I campi corrispondono alle proprieta di GameSettingsService; un
## preset le imposta tutte, toccarne una porta il preset a Personalizzato.

## Preset -> valori dei campi di GameSettingsService.
const PRESETS: Dictionary = {
	GameSettingsService.Preset.STEAM_DECK: {
		"msaa_3d": Viewport.MSAA_DISABLED, "screen_aa": 1, "shadow_quality": 1, "ssao_quality": 1,
		"gi_mode": 0, "glow_quality": 1, "volumetric_fog": false, "texture_quality": 1,
		"vegetation_density": 1, "render_scale": 0.85, "fsr_upscaling": true,
	},
	GameSettingsService.Preset.LOW: {
		"msaa_3d": Viewport.MSAA_DISABLED, "screen_aa": 1, "shadow_quality": 1, "ssao_quality": 0,
		"gi_mode": 0, "glow_quality": 0, "volumetric_fog": false, "texture_quality": 0,
		"vegetation_density": 0, "render_scale": 0.75, "fsr_upscaling": true,
	},
	GameSettingsService.Preset.MEDIUM: {
		"msaa_3d": Viewport.MSAA_2X, "screen_aa": 0, "shadow_quality": 2, "ssao_quality": 1,
		"gi_mode": 0, "glow_quality": 1, "volumetric_fog": false, "texture_quality": 1,
		"vegetation_density": 1, "render_scale": 1.0, "fsr_upscaling": false,
	},
	GameSettingsService.Preset.HIGH: {
		"msaa_3d": Viewport.MSAA_4X, "screen_aa": 0, "shadow_quality": 2, "ssao_quality": 2,
		"gi_mode": 1, "glow_quality": 2, "volumetric_fog": false, "texture_quality": 1,
		"vegetation_density": 2, "render_scale": 1.0, "fsr_upscaling": false,
	},
	GameSettingsService.Preset.MAX: {
		"msaa_3d": Viewport.MSAA_4X, "screen_aa": 1, "shadow_quality": 3, "ssao_quality": 2,
		"gi_mode": 2, "glow_quality": 2, "volumetric_fog": true, "texture_quality": 1,
		"vegetation_density": 2, "render_scale": 1.0, "fsr_upscaling": false,
	},
}
## Dimensione dell'atlante delle ombre direzionali per qualita (0 = ombre spente).
const SHADOW_SIZES: Array[int] = [1024, 1024, 2048, 4096]
const SHADOW_MODES: Array[int] = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_ORTHOGONAL,
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS]
## Moltiplicatore delle istanze di erba, fiori e detriti per densita.
const VEGETATION: Array[float] = [0.35, 0.65, 1.0]


## Applica le opzioni di qualita a un Environment e al sole dell'arena.
static func apply(s: GameSettingsService, environment: Environment, sun: DirectionalLight3D) -> void:
	if sun != null:
		sun.shadow_enabled = s.shadow_quality > 0
		sun.directional_shadow_mode = SHADOW_MODES[s.shadow_quality]
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[s.shadow_quality], true)
	if environment == null:
		return
	environment.ssao_enabled = s.ssao_quality > 0
	environment.ssao_intensity = 1.0 if s.ssao_quality == 1 else 1.6
	# La qualita dell'SSAO e globale del renderer: bassa = pochi campioni a meta risoluzione.
	if s.ssao_quality == 1:
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50.0, 300.0)
	elif s.ssao_quality == 2:
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	environment.ssil_enabled = s.gi_mode == 1
	environment.sdfgi_enabled = s.gi_mode == 2
	if s.gi_mode == 2:
		environment.sdfgi_cascades = 4
		environment.sdfgi_min_cell_size = 0.3
		environment.sdfgi_use_occlusion = true
	environment.glow_enabled = s.glow_quality > 0
	environment.glow_intensity = 0.3 if s.glow_quality == 1 else 0.55
	# Basso: un solo livello (meno passate di sfocatura); alto: tre livelli come l'arena.
	for level in 7:
		environment.set_glow_level(level, 0.0)
	if s.glow_quality == 1:
		environment.set_glow_level(2, 0.8)
	elif s.glow_quality == 2:
		environment.set_glow_level(1, 0.6)
		environment.set_glow_level(3, 0.8)
		environment.set_glow_level(5, 0.4)
	environment.volumetric_fog_enabled = s.volumetric_fog
	if s.volumetric_fog:
		environment.volumetric_fog_density = 0.012
		environment.volumetric_fog_albedo = Color(0.95, 0.85, 0.7)
		environment.volumetric_fog_anisotropy = 0.6
