class_name SurveyVisualTheme
extends RefCounted


const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")

const BODY_TEXT_DEFAULT: Color = Color(0.890196, 0.92549, 0.988235, 0.94)
const BODY_TEXT_STAR: Color = Color(1.0, 0.72549, 0.376471, 1.0)
const BODY_TEXT_PLANET: Color = Color(0.917647, 0.964706, 1.0, 1.0)
const BODY_TEXT_MOON: Color = Color(0.819608, 0.890196, 1.0, 1.0)
const BODY_TEXT_BLACK_HOLE: Color = Color(0.72549, 0.65098, 1.0, 1.0)

const ENV_HABITABLE: Color = Color(0.239216, 0.858824, 0.564706, 1.0)
const ENV_HARSH: Color = Color(0.976471, 0.733333, 0.309804, 1.0)
const ENV_HOSTILE: Color = Color(1.0, 0.356863, 0.286275, 1.0)

const CLIMATE_FROZEN: Color = Color(0.509804, 0.788235, 1.0, 1.0)
const CLIMATE_TEMPERATE: Color = Color(0.443137, 0.878431, 0.584314, 1.0)
const CLIMATE_SEASONAL: Color = Color(0.956863, 0.752941, 0.372549, 1.0)
const CLIMATE_HOT: Color = Color(1.0, 0.384314, 0.239216, 1.0)

const LIFE_STERILE: Color = Color(0.709804, 0.788235, 0.886275, 1.0)
const LIFE_PREBIOTIC: Color = Color(0.678431, 0.858824, 1.0, 1.0)
const LIFE_MICROBIAL: Color = Color(0.439216, 0.878431, 0.666667, 1.0)
const LIFE_COMPLEX: Color = Color(0.780392, 0.929412, 0.388235, 1.0)
const LIFE_ECOSYSTEM: Color = Color(1.0, 0.839216, 0.384314, 1.0)


static func color_for_body_kind(kind: int) -> Color:
	match kind:
		BodyType.Kind.STAR:
			return BODY_TEXT_STAR
		BodyType.Kind.PLANET:
			return BODY_TEXT_PLANET
		BodyType.Kind.MOON:
			return BODY_TEXT_MOON
		BodyType.Kind.BLACK_HOLE:
			return BODY_TEXT_BLACK_HOLE
	return BODY_TEXT_DEFAULT


static func color_for_environment_class(environment_class: int) -> Color:
	match environment_class:
		EnvironmentServiceScript.Class.HABITABLE:
			return ENV_HABITABLE
		EnvironmentServiceScript.Class.MARGINAL:
			return ENV_HARSH
		EnvironmentServiceScript.Class.HOSTILE:
			return ENV_HOSTILE
	return BODY_TEXT_DEFAULT


static func color_for_ecosystem_type(ecosystem_type: int) -> Color:
	match ecosystem_type:
		EnvironmentServiceScript.EcosystemType.FROZEN_WORLD:
			return CLIMATE_FROZEN
		EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD:
			return CLIMATE_TEMPERATE
		EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD:
			return CLIMATE_SEASONAL
		EnvironmentServiceScript.EcosystemType.HOT_WORLD:
			return CLIMATE_HOT
	return BODY_TEXT_DEFAULT


static func color_for_life_stage(stage: int) -> Color:
	match stage:
		BiosphereScaleServiceScript.Stage.STERILE:
			return LIFE_STERILE
		BiosphereScaleServiceScript.Stage.PREBIOTIC:
			return LIFE_PREBIOTIC
		BiosphereScaleServiceScript.Stage.MICROBIAL:
			return LIFE_MICROBIAL
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR:
			return LIFE_COMPLEX
		BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM:
			return LIFE_ECOSYSTEM
	return BODY_TEXT_DEFAULT
