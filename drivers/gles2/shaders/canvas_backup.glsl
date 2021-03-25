/* clang-format off */
[vertex]

/* clang-format off */

VERTEX_SHADER_GLOBALS

/* clang-format on */

float2 select(float2 a, float2 b, bool2 c) {
	float2 ret;

	ret.x = c.x ? b.x : a.x;
	ret.y = c.y ? b.y : a.y;

	return ret;
}

#ifdef USE_LIGHTING
const bool at_light_pass = true;
#else
const bool at_light_pass = false;
#endif

#include "stdlib.glsl"

void main(
float2 vertex, // attrib:0

#ifdef USE_ATTRIB_LIGHT_ANGLE
// shared with tangent, not used in canvas shader
float light_angle, // attrib:2
#endif

float4 color_attrib, // attrib:3
float2 uv_attrib, // attrib:4

#ifdef USE_ATTRIB_MODULATE
float4 modulate_attrib, // attrib:5
#endif

#ifdef USE_ATTRIB_LARGE_VERTEX
// shared with skeleton attributes, not used in batched shader
float2 translate_attrib, // attrib:6
float4 basis_attrib, // attrib:7
#endif

#ifdef USE_SKELETON
float4 bone_indices, // attrib:6
float4 bone_weights, // attrib:7
#endif

#ifdef USE_INSTANCING

float4 instance_xform0, //attrib:8
float4 instance_xform1, //attrib:9
float4 instance_xform2, //attrib:10
float4 instance_color, //attrib:11

#ifdef USE_INSTANCE_CUSTOM
float4 instance_custom_data, //attrib:12
#endif

#endif

uniform float4x4 projection_matrix,
/* clang-format on */

uniform float4x4 modelview_matrix,
uniform float4x4 extra_matrix,

#ifdef USE_SKELETON
uniform sampler2D skeleton_texture, // texunit:-3
uniform float2 skeleton_texture_size,
uniform float4x4 skeleton_transform,
uniform float4x4 skeleton_transform_inverse,
#endif

#ifdef MODULATE_USED
uniform float4 final_modulate,
#endif

uniform float2 color_texpixel_size,

#ifdef USE_TEXTURE_RECT

uniform float4 dst_rect,
uniform float4 src_rect,

#endif

uniform float time,

#ifdef USE_LIGHTING

// light matrices
uniform float4x4 light_matrix,
uniform float4x4 light_matrix_inverse,
uniform float4x4 light_local_matrix,
uniform float4x4 shadow_matrix,
uniform float4 light_color,
uniform float4 light_shadow_color,
uniform float2 light_pos,
uniform float shadowpixel_size,
uniform float shadow_gradient,
uniform float light_height,
uniform float light_outside_alpha,
uniform float shadow_distance_mult,

float4 out light_uv_interp: TEXCOORD0,
float2 out transformed_light_uv: TEXCOORD1,
float4 out local_rot: TEXCOORD2,

#ifdef USE_SHADOWS
float2 out pos: TEXCOORD3,
#endif
#endif

#ifdef USE_ATTRIB_MODULATE
// modulate doesn't need interpolating but we need to send it to the fragment shader
float4 out modulate_interp: TEXCOORD7,
#endif
float4 out gl_Position: POSITION,
float2 out uv_interp: TEXCOORD4,
float4 out color_interp: TEXCOORD5,
float out gl_PointSize: TEXCOORD6
){
	float4 color = color_attrib;
	float2 uv;

#ifdef USE_INSTANCING
	float4x4 extra_matrix_instance = extra_matrix * transpose(float4x4(instance_xform0, instance_xform1, instance_xform2, float4(0.0, 0.0, 0.0, 1.0)));
	color = mul(instance_color, color);

#ifdef USE_INSTANCE_CUSTOM
	float4 instance_custom = instance_custom_data;
#else
	float4 instance_custom = float4(0.0);
#endif

#else
	float4x4 extra_matrix_instance = extra_matrix;
#endif

#ifdef USE_TEXTURE_RECT

	if (dst_rect.z < 0.0) { // Transpose is encoded as negative dst_rect.z
		uv = src_rect.xy + abs(src_rect.zw) * vertex.yx;
	} else {
		uv = src_rect.xy + abs(src_rect.zw) * vertex;
	}

	float4 outvec = float4(0.0, 0.0, 0.0, 1.0);

	// This is what is done in the GLES 3 bindings and should
	// take care of flipped rects.
	//
	// But it doesn't.
	// I don't know why, will need to investigate further.

	outvec.xy = dst_rect.xy + abs(dst_rect.zw) * select(vertex, float2(1.0, 1.0) - vertex, lessThan(src_rect.zw, float2(0.0, 0.0)));

	// outvec.xy = dst_rect.xy + abs(dst_rect.zw) * vertex;
#else
	float4 outvec = float4(vertex.xy, 0.0, 1.0);

	uv = uv_attrib;
#endif

	float point_size = 1.0;


	gl_PointSize = point_size;

#ifdef USE_ATTRIB_MODULATE
	// modulate doesn't need interpolating but we need to send it to the fragment shader
	modulate_interp = modulate_attrib;
#endif

#ifdef USE_ATTRIB_LARGE_VERTEX
	// transform is in attributes
	float2 temp;

	temp = outvec.xy;
	temp.x = (outvec.x * basis_attrib.x) + (outvec.y * basis_attrib.z);
	temp.y = (outvec.x * basis_attrib.y) + (outvec.y * basis_attrib.w);

	temp += translate_attrib;
	outvec.xy = temp;

#else

	// transform is in uniforms
#if !defined(SKIP_TRANSFORM_USED)
	outvec = mul(extra_matrix_instance, outvec);
	outvec = mul(modelview_matrix, outvec);
#endif

#endif // not large integer

	color_interp = color;

#ifdef USE_PIXEL_SNAP
	outvec.xy = floor(outvec + 0.5).xy;
	// precision issue on some hardware creates artifacts within texture
	// offset uv by a small amount to avoid
	uv += 1e-5;
#endif

#ifdef USE_SKELETON

	// look up transform from the "pose texture"
	if (bone_weights != float4(0.0)) {

		float4x4 bone_transform = float4x4(0.0);

		for (int i = 0; i < 4; i++) {
			int2 tex_ofs = int2(int(bone_indices[i]) * 2, 0);

			float4x4 b = float4x4(
					texel2DFetch(skeleton_texture, skeleton_texture_size, tex_ofs + int2(0, 0)),
					texel2DFetch(skeleton_texture, skeleton_texture_size, tex_ofs + int2(1, 0)),
					float4(0.0, 0.0, 1.0, 0.0),
					float4(0.0, 0.0, 0.0, 1.0));

			bone_transform += b * bone_weights[i];
		}

		float4x4 bone_matrix = skeleton_transform * transpose(bone_transform) * skeleton_transform_inverse;

		outvec = bone_matrix * outvec;
	}

#endif

	uv_interp = uv;
	gl_Position = float4(0.0, 0.0, 0.0, 1.0);

#ifdef USE_LIGHTING

	light_uv_interp.xy = (light_matrix * outvec).xy;
	light_uv_interp.zw = (light_local_matrix * outvec).xy;

	transformed_light_uv = (float3x3(light_matrix_inverse) * float3(light_uv_interp.zw, 0.0)).xy; //for normal mapping

#ifdef USE_SHADOWS
	pos = outvec.xy;
#endif

#ifdef USE_ATTRIB_LIGHT_ANGLE
	// we add a fixed offset because we are using the sign later,
	// and don't want floating point error around 0.0
	float la = abs(light_angle) - 1.0;

	// vector light angle
	float4 vla;
	vla.xy = float2(cos(la), sin(la));
	vla.zw = float2(-vla.y, vla.x);

	// vertical flip encoded in the sign
	vla.zw = mul(vla.zw, sign(light_angle));

	// apply the transform matrix.
	// The rotate will be encoded in the transform matrix for single rects,
	// and just the flips in the light angle.
	// For batching we will encode the rotation and the flips
	// in the light angle, and can use the same shader.
	local_rot.xy = normalize((modelview_matrix * (extra_matrix_instance * float4(vla.xy, 0.0, 0.0))).xy);
	local_rot.zw = normalize((modelview_matrix * (extra_matrix_instance * float4(vla.zw, 0.0, 0.0))).xy);
#else
	local_rot.xy = normalize((modelview_matrix * (extra_matrix_instance * float4(1.0, 0.0, 0.0, 0.0))).xy);
	local_rot.zw = normalize((modelview_matrix * (extra_matrix_instance * float4(0.0, 1.0, 0.0, 0.0))).xy);
#ifdef USE_TEXTURE_RECT
	local_rot.xy = mul(local_rot.xy, sign(src_rect.z));
	local_rot.zw = mul(local_rot.zw, sign(src_rect.w));
#endif
#endif // not using light angle

#endif
}

/* clang-format off */
[fragment]

#ifdef USE_LIGHTING
const bool at_light_pass = true,
#else
const bool at_light_pass = false,
#endif
#include "stdlib.glsl"

void light_compute(
		inout float4 light,
		inout float2 light_vec,
		inout float light_height,
		inout float4 light_color,
		float2 light_uv,
		inout float4 shadow_color,
		inout float2 shadow_vec,
		float3 normal,
		float2 uv,
#if defined(SCREEN_UV_USED)
		float2 screen_uv,
#endif
		float4 color) {

#if defined(USE_LIGHT_SHADER_CODE)

	/* clang-format off */

LIGHT_SHADER_CODE

	/* clang-format on */

#endif
}

void main(
uniform sampler2D color_texture, // texunit:-1
/* clang-format on */
uniform float2 color_texpixel_size,
uniform sampler2D normal_texture, // texunit:-2

half2 in uv_interp: TEXCOORD0,
half4 in color_interp: TEXCOORD5,

#ifdef USE_ATTRIB_MODULATE
half4 in modulate_interp: TEXCOORD7,
#endif

uniform float time,

uniform float4 final_modulate,

#ifdef SCREEN_TEXTURE_USED

uniform sampler2D screen_texture, // texunit:-4

#endif

#ifdef SCREEN_UV_USED

uniform float2 screen_pixel_size,

#endif

#ifdef USE_LIGHTING

uniform float4x4 light_matrix,
uniform float4x4 light_local_matrix,
uniform float4x4 shadow_matrix,
uniform float4 light_color,
uniform float4 light_shadow_color,
uniform float2 light_pos,
uniform float shadowpixel_size,
uniform float shadow_gradient,
uniform float light_height,
uniform float light_outside_alpha,
uniform float shadow_distance_mult,

uniform lowp sampler2D light_texture, // texunit:-6
float4 in light_uv_interp: TEXCOORD0,
float2 in transformed_light_uv: TEXCOORD1,

float4 in local_rot: TEXCOORD2,

#ifdef USE_SHADOWS

uniform sampler2D shadow_texture, // texunit:-5
float2 in pos: TEXCOORD3,

#endif
#endif

uniform bool use_default_normal,
) {

	float4 color = color_interp;
	float2 uv = uv_interp;
#ifdef USE_FORCE_REPEAT
	//needs to use this to workaround GLES2/WebGL1 forcing tiling that textures that don't support it
	uv = mod(uv, float2(1.0, 1.0));
#endif

#if !defined(COLOR_USED)
	//default behavior, texture by color
	color = mul(color, texture2D(color_texture, uv));
#endif

#ifdef SCREEN_UV_USED
	float2 screen_uv = gl_FragCoord.xy * screen_pixel_size;
#endif

	float3 normal;

#if defined(NORMAL_USED)

	bool normal_used = true;
#else
	bool normal_used = false;
#endif

	if (use_default_normal) {
		normal.xy = texture2D(normal_texture, uv).xy * 2.0 - 1.0;
		normal.z = sqrt(max(0.0, 1.0 - dot(normal.xy, normal.xy)));
		normal_used = true;
	} else {
		normal = float3(0.0, 0.0, 1.0);
	}

	{
		float normal_depth = 1.0;

#if defined(NORMALMAP_USED)
		float3 normal_map = float3(0.0, 0.0, 1.0);
		normal_used = true;
#endif

		// If larger fvfs are used, final_modulate is passed as an attribute.
		// we need to read from this in custom fragment shaders or applying in the post step,
		// rather than using final_modulate directly.
#if defined(final_modulate_alias)
#undef final_modulate_alias
#endif
#ifdef USE_ATTRIB_MODULATE
#define final_modulate_alias modulate_interp
#else
#define final_modulate_alias final_modulate
#endif

		/* clang-format off */

FRAGMENT_SHADER_CODE

		/* clang-format on */

#if defined(NORMALMAP_USED)
		normal = mix(float3(0.0, 0.0, 1.0), normal_map * float3(2.0, -2.0, 1.0) - float3(1.0, -1.0, 0.0), normal_depth);
#endif
	}

#if !defined(MODULATE_USED)
	color = mul(color, final_modulate_alias);
#endif

#ifdef USE_LIGHTING

	float2 light_vec = transformed_light_uv;
	float2 shadow_vec = transformed_light_uv;

	if (normal_used) {
		normal.xy = float2x2(local_rot.xy, local_rot.zw) * normal.xy;
	}

	float att = 1.0;

	float2 light_uv = light_uv_interp.xy;
	float4 light = texture2D(light_texture, light_uv);

	if (any(lessThan(light_uv_interp.xy, float2(0.0, 0.0))) || any(greaterThanEqual(light_uv_interp.xy, float2(1.0, 1.0)))) {
		color.a = mul(light_outside_alpha, color.a); //invisible

	} else {
		float real_light_height = light_height;
		float4 real_light_color = light_color;
		float4 real_light_shadow_color = light_shadow_color;

#if defined(USE_LIGHT_SHADER_CODE)
		//light is written by the light shader
		light_compute(
				light,
				light_vec,
				real_light_height,
				real_light_color,
				light_uv,
				real_light_shadow_color,
				shadow_vec,
				normal,
				uv,
#if defined(SCREEN_UV_USED)
				screen_uv,
#endif
				color);
#endif

		light = mul(real_light_color, light);

		if (normal_used) {
			float3 light_normal = normalize(float3(light_vec, -real_light_height));
			light = mul(light, max(dot(-light_normal, normal), 0.0));
		}

		color = mul(color, light);

#ifdef USE_SHADOWS

#ifdef SHADOW_VEC_USED
		float3x3 inverse_light_matrix = float3x3(light_matrix);
		inverse_light_matrix[0] = normalize(inverse_light_matrix[0]);
		inverse_light_matrix[1] = normalize(inverse_light_matrix[1]);
		inverse_light_matrix[2] = normalize(inverse_light_matrix[2]);
		shadow_vec = (inverse_light_matrix * float3(shadow_vec, 0.0)).xy;
#else
		shadow_vec = light_uv_interp.zw;
#endif

		float angle_to_light = -atan(shadow_vec.x, shadow_vec.y);
		float PI = 3.14159265358979323846264;
		/*int i = int(mod(floor((angle_to_light+7.0*PI/6.0)/(4.0*PI/6.0))+1.0, 3.0)); // +1 pq os indices estao em ordem 2,0,1 nos arrays
		float ang*/

		float su, sz;

		float abs_angle = abs(angle_to_light);
		float2 point;
		float sh;
		if (abs_angle < 45.0 * PI / 180.0) {
			point = shadow_vec;
			sh = 0.0 + (1.0 / 8.0);
		} else if (abs_angle > 135.0 * PI / 180.0) {
			point = -shadow_vec;
			sh = 0.5 + (1.0 / 8.0);
		} else if (angle_to_light > 0.0) {

			point = float2(shadow_vec.y, -shadow_vec.x);
			sh = 0.25 + (1.0 / 8.0);
		} else {

			point = float2(-shadow_vec.y, shadow_vec.x);
			sh = 0.75 + (1.0 / 8.0);
		}

		float4 s = shadow_matrix * float4(point, 0.0, 1.0);
		s.xyz /= s.w;
		su = s.x * 0.5 + 0.5;
		sz = s.z * 0.5 + 0.5;
		//sz=lightlength(light_vec);

		float shadow_attenuation = 0.0;

#ifdef USE_RGBA_SHADOWS
#define SHADOW_DEPTH(m_tex, m_uv) dot(texture2D((m_tex), (m_uv)), float4(1.0 / (255.0 * 255.0 * 255.0), 1.0 / (255.0 * 255.0), 1.0 / 255.0, 1.0))

#else

#define SHADOW_DEPTH(m_tex, m_uv) (texture2D((m_tex), (m_uv)).r)

#endif

#ifdef SHADOW_USE_GRADIENT

		/* clang-format off */
		/* GLSL es 100 doesn't support line continuation characters(backslashes) */
#define SHADOW_TEST(m_ofs) { float sd = SHADOW_DEPTH(shadow_texture, float2(m_ofs, sh)); shadow_attenuation += 1.0 - smoothstep(sd, sd + shadow_gradient, sz); }

#else

#define SHADOW_TEST(m_ofs) { float sd = SHADOW_DEPTH(shadow_texture, float2(m_ofs, sh)); shadow_attenuation += step(sz, sd); }
		/* clang-format on */

#endif

#ifdef SHADOW_FILTER_NEAREST

		SHADOW_TEST(su);

#endif

#ifdef SHADOW_FILTER_PCF3

		SHADOW_TEST(su + shadowpixel_size);
		SHADOW_TEST(su);
		SHADOW_TEST(su - shadowpixel_size);
		shadow_attenuation /= 3.0;

#endif

#ifdef SHADOW_FILTER_PCF5

		SHADOW_TEST(su + shadowpixel_size * 2.0);
		SHADOW_TEST(su + shadowpixel_size);
		SHADOW_TEST(su);
		SHADOW_TEST(su - shadowpixel_size);
		SHADOW_TEST(su - shadowpixel_size * 2.0);
		shadow_attenuation /= 5.0;

#endif

#ifdef SHADOW_FILTER_PCF7

		SHADOW_TEST(su + shadowpixel_size * 3.0);
		SHADOW_TEST(su + shadowpixel_size * 2.0);
		SHADOW_TEST(su + shadowpixel_size);
		SHADOW_TEST(su);
		SHADOW_TEST(su - shadowpixel_size);
		SHADOW_TEST(su - shadowpixel_size * 2.0);
		SHADOW_TEST(su - shadowpixel_size * 3.0);
		shadow_attenuation /= 7.0;

#endif

#ifdef SHADOW_FILTER_PCF9

		SHADOW_TEST(su + shadowpixel_size * 4.0);
		SHADOW_TEST(su + shadowpixel_size * 3.0);
		SHADOW_TEST(su + shadowpixel_size * 2.0);
		SHADOW_TEST(su + shadowpixel_size);
		SHADOW_TEST(su);
		SHADOW_TEST(su - shadowpixel_size);
		SHADOW_TEST(su - shadowpixel_size * 2.0);
		SHADOW_TEST(su - shadowpixel_size * 3.0);
		SHADOW_TEST(su - shadowpixel_size * 4.0);
		shadow_attenuation /= 9.0;

#endif

#ifdef SHADOW_FILTER_PCF13

		SHADOW_TEST(su + shadowpixel_size * 6.0);
		SHADOW_TEST(su + shadowpixel_size * 5.0);
		SHADOW_TEST(su + shadowpixel_size * 4.0);
		SHADOW_TEST(su + shadowpixel_size * 3.0);
		SHADOW_TEST(su + shadowpixel_size * 2.0);
		SHADOW_TEST(su + shadowpixel_size);
		SHADOW_TEST(su);
		SHADOW_TEST(su - shadowpixel_size);
		SHADOW_TEST(su - shadowpixel_size * 2.0);
		SHADOW_TEST(su - shadowpixel_size * 3.0);
		SHADOW_TEST(su - shadowpixel_size * 4.0);
		SHADOW_TEST(su - shadowpixel_size * 5.0);
		SHADOW_TEST(su - shadowpixel_size * 6.0);
		shadow_attenuation /= 13.0;

#endif

		//color *= shadow_attenuation;
		color = mix(real_light_shadow_color, color, shadow_attenuation);
//use shadows
#endif
	}

//use lighting
#endif

	gl_FragColor = color;
}
