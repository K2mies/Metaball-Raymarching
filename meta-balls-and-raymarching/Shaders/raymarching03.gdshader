shader_type spatial;
render_mode unshaded;

/*																				*
*						RAYMARCHER WITH SHAPE BLENDING							*
*																				*/

// -------------------------------------------------------------------- uniforms
//uniform samplerCube		environment_cubemap;
uniform	sampler2D	reflection_texture;

uniform float		normal_strength = .1f;
uniform float		lambert_strength = .5f;
uniform float		reflect_strength = .5f;

uniform vec3		translate[4];
uniform vec3		colors[4];

uniform float		light_brightness;
uniform vec3		light_position;
uniform vec4		light_color;
uniform vec3		ambient_color;

uniform vec3		cube_rotation_axis =		vec3( 0.f, 1.f, 0.f );
uniform float		cube_rotation_amount =		0.f;

uniform vec3		torus_rotation_axis =		vec3( 0.f, 1.f, 0.f );
uniform float		torus_rotation_amount =		0.f;

uniform vec3		cylinder_rotation_axis =	vec3( 0.f, 1.f, 0.f );
uniform float		cylinder_rotation_amount =	0.f;

uniform float		cube_size =					1.f;
uniform float		sphere_size =				1.f;
uniform vec2		torus_radii = 				vec2( 1.5f, .5f );
uniform vec2		cylinder_dimensions =		vec2( 1.f, 2.f );

uniform float	weight;

// ------------------------------------------------------------------- variables
const int	MAX_STEPS = 		300;
const float MAX_DISTANCE =		1000.f;
const float MIN_DISTANCE =		0.001f;

// ----------------------------------------------------------------------- enums
const int sphere_a =		0;
//const int sphere_b =		1;
//const int sphere_c =		2;
//const int sphere_d =		3;

//const int cube_a =		0;
const int cube_b =			1;
//const int cube_c =		2;
//const int cube_d =		3;

//const int torus_a =		0;
//const int torus_b =		1;
const int torus_c = 		2;
//const int torus_d = 		3;

//const int cylinder_a =	0;
//const int cylinder_b =	1;
//const int cylinder_c =	2;
const int cylinder_d =		3;

const int color_a =			0;
const int color_b =			1;
const int color_c =			2;
const int color_d =			3;

// -------------------------------------------------------------------- structs
struct	Result
{
	float 	dist;
	vec3	color;
};

struct	Light
{
	vec3		position;
	float		brightness;
	vec3		ambient;
	vec4		color;	
};

// ------------------------------------------------------ signed distance fields
float signedDistanceSphere( vec3 p, vec3 centrum, float radius )
{
	return length( centrum - p ) - radius;
}

float signedDistanceCube( vec3 p, vec3 centre, vec3 size )
{
	vec3 offset = abs( p - centre ) - size;
	// distance from point outside box to edge (0 if inside box)
	float unsignedDistance =	length( max( offset, 0.f ) );
	// distance from point inside box to edge (0 if outside box)
	float distanceInsideBox =	min( max( offset.x, max( offset.y, offset.z ) ), 0.0 );
	return unsignedDistance +	distanceInsideBox;
}

float signedDistanceTorus( vec3 p, vec2 t )
{
	vec2 q = vec2( length( p.xz ) -t.x, p.y );
	return length( q ) -t.y;
}

float signedDistanceCylinder( vec3 p, float r, float h )
{
	vec2 d = abs( vec2( length( p.xz ), p.y ) ) - vec2( r, h );
	return min( max( d.x, d.y ), 0.f ) + length( max( d, 0.f ) );
}

// ------------------------------------------------------- transformation matrix
vec3 rotate( vec3 v, vec3 axis, float angle )
{
	float s =	sin( angle );
	float c =	cos( angle );
	float oc =	1.f - c;
	
	mat3 rot = mat3(
		vec3( oc * axis.x * axis.x + c,				oc * axis.x * axis.y - axis.z * s,		oc * axis.z * axis.x + axis.y * s ),
		vec3( oc * axis.x * axis.y + axis.z * s, 	oc * axis.y * axis.y + c,           	oc * axis.y * axis.z - axis.x * s ),
		vec3( oc * axis.z * axis.x - axis.y * s, 	oc * axis.y * axis.z + axis.x * s,  	oc * axis.z * axis.z + c )
	);
	return rot * v;
}

// ------------------------------------------------------------------ smooth min
Result smooth_min( Result a, Result b, float smooth_weight )
{
	// Standard smooth minimum distance calculation
	float blend_factor = clamp( 0.5 + 0.5 * ( b.dist - a.dist )
									/ smooth_weight, 0.0, 1.0 );
									
	float dist = mix( b.dist, a.dist, blend_factor ) 
									- smooth_weight 
									* blend_factor
									* ( 1.0 - blend_factor );
	
	// Mix colors in the blend zone
	vec3	 final_color = mix( b.color, a.color, blend_factor );
	return Result( dist, final_color );
}

// ----------------------------------------------------------------- get distance
vec4 get_distance_with_color( vec3 p )
{
	// ---------------------- SHAPE 1: Sphere (Color A) ----------------------
	float obj01 = 	signedDistanceSphere( p, translate[sphere_a], sphere_size );
	Result res01 =	Result( obj01, colors[color_a] );
	
	// ---------------------- SHAPE 2: Cube (Color B) ------------------------
	// 1. Localize p to the cube's center and add translation
	vec3 cube_p = p - translate[cube_b];
	// We rotate around axies based on TIME
	cube_p = 		rotate( cube_p, normalize( cube_rotation_axis ),
												cube_rotation_amount * TIME );
	vec3 size =		vec3( cube_size );
	float obj02 =	signedDistanceCube( cube_p, vec3( 0.f ), size );
	Result res02 =	Result( obj02, colors[color_b] );

	// ---------------------- SHAPE 3: Torus (Color C) -----------------------
	// Translate the torus to its position
	vec3 torus_p = p - translate[torus_c];
	torus_p = 		rotate( torus_p, normalize( torus_rotation_axis ),
												torus_rotation_amount * TIME);
	float obj03 =	signedDistanceTorus( torus_p, torus_radii );
	Result res03 =	Result( obj03, colors[color_c] );
	
	// ---------------------- SHAPE 4: Cylinder (Color D) --------------------
	vec3 cylinder_p = p - translate[cylinder_d];
	cylinder_p =		rotate( cylinder_p, normalize( cylinder_rotation_axis ),
												cylinder_rotation_amount * TIME);
	
	float obj04 =	signedDistanceCylinder( cylinder_p,
											cylinder_dimensions.x,
											cylinder_dimensions.y );
	Result res04 =	Result( obj04, colors[color_d] );
	
	// -------------------- COMBINATION (Hierarchical) ----------------------
	// 1. Combine Sphere (res1) and Cube (res2) using the 'weight' uniform
	Result combined_SC =	smooth_min( res01, res02, weight );

	// 2. Combine Blended SC (combined_SC) and Torus (res3)
	Result combined_SCT =	smooth_min( combined_SC, res03, weight );

	// 2. Combine Blended SCT (combined_SCT) and Cylinder (res3)
	Result combined_SCTC =	smooth_min( combined_SCT, res04, weight );
	
	return vec4( combined_SCTC.color, combined_SCTC.dist );
}

float get_distance( vec3 p )
{
	return get_distance_with_color( p ).w;
}

// ------------------------------------------------------------------ get normal
vec3 get_normal( vec3 p )
{
	vec2 e = vec2( 0.001f, 0 );
	
	vec3 n = get_distance( p ) - vec3(
			 get_distance( p - e.xyy ),
			 get_distance( p - e.yxy ),
			 get_distance( p - e.yyx )
	);
	return normalize( n );
}

// ----------------------------------------------------------------- get lambert
vec3	 get_lambert( vec3 hit_point, vec3 normal )
{
	//create and asign the light object
	//(this is so you can create multiple lights later if needed)
	Light light00;
	light00.position = 		light_position;
	light00.color = 		light_color;
	light00.brightness = 	light_brightness;
	light00.ambient = 		ambient_color;
	
	// Vector from the hit point to the light source, normalized.
	vec3 direction =	normalize( light00.position - hit_point );
	
	// The Lambertian contribution is the dot product of the Normal (N) and Light Direction (L).
    // clamp() or max(0.0, ...) ensures we only light surfaces facing the light (no negative light).
	float diffuse =		max( 0.f, dot( normal, direction ) );
	
	// put it all together
	vec3 output = light00.ambient * light00.color.rgb * diffuse * light00.brightness;
	
	return output;
}

// -------------------------------------------------------------- get reflection

vec3 equ_sample(vec3 r)
{
	float longitude = atan(r.x, r.z);
	float latitude = acos(clamp(r.y, -1.f, 1.f));
	
	//Normalization to uv coordinates
	longitude = (longitude + 3.14159265359) / (2.0 * 3.14159265359);
	latitude = latitude / 3.14159265359;
	
	vec2 uv = vec2(longitude, latitude);
	
	//Sample the panoramic texture
	return texture(reflection_texture, uv).xyz;
}

vec3 get_reflection( vec3 hit_point, vec3 normal, vec3 view_direction)
{
	// The view direction is the incoming ray direction (ray_dir)
	vec3 V = view_direction;
	
	// 1. Calculate the Reflection Vector (R)
	vec3 R = reflect(V, normal);
	
	// 2. Sample the Cubemap
	//vec3 reflected_color = texture( environment_cubemap, R).rgb;
	vec3 reflected_color = equ_sample(R);
	
	return reflected_color;
}

// --------------------------------------------------------- colored raymarching
vec4 raymarch_color( vec3 ray_origin, vec3 ray_direction )
{
	float	t = 0.f;
	vec3	p = ray_origin;
	int		i = 0;
	
	for ( int i = 0; i < MAX_STEPS; i++ )
	{
		vec4 scene =	get_distance_with_color( p );
		float d = 		scene.w;
		vec3 col = 		scene.xyz;

		if( abs( d ) < MIN_DISTANCE )
		{
			//get hit
			vec3 hit_point = p;
			
			//get each channel
			vec3 normal =		get_normal( p ) * .5f + .5f;
			vec3 lambert =		get_lambert(hit_point, normal);
			vec3 reflection =	get_reflection(hit_point, normal, ray_direction);
			
			//normalize the layers by deviding by the total 
			//amount of layes
			col = 			col 		/ 4.f;
			normal =		normal		/ 4.f;
			lambert =		lambert		/ 4.f;
			reflection =	reflection	/ 4.f;
			
			//add to vec4 (makes a difference to do it here)
			vec4 color4 =		vec4(col, 1.f);
			vec4 normal4 =		vec4(normal, 1.f);
			vec4 lambert4 =		vec4(lambert, 1.f);
			vec4 reflection4 =	vec4(reflection, 1.f);
			
			vec4 output = mix(color4, lambert4, lambert_strength);
			output = mix(output, normal4, normal_strength);
			output = mix(output, reflection4, reflect_strength);
			
			//vec4 output = reflection4;
			
			return output;
		}
		if( t > MAX_DISTANCE )
			break;
		
		t += d;	
		p += d * ray_direction;
	}
	return vec4( 0.f );
}

// ------------------------------------------------------------- fragment shader
void fragment() 
{
	vec2 uv = SCREEN_UV * 2.f - 1.f;
	
	vec4 clip_position =	vec4( uv, 1.f, 1.f );
	vec4 world_position =	INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * clip_position;
	
	vec3 ray_end =			world_position.xyz / world_position.w;
	vec3 ray_origin = 		INV_VIEW_MATRIX[3].xyz;
	vec3 ray_direction = 	normalize( ray_end - ray_origin );

	vec4 col = raymarch_color( ray_origin, ray_direction );
	
	ALPHA =		col.a;
	ALBEDO =	col.rgb;
}