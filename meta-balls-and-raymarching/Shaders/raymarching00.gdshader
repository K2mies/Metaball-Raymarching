shader_type spatial;
render_mode unshaded;

// -------------------------------------------------------------------- uniforms
uniform vec3	translate[2];
uniform vec3	colors[2];
uniform vec3	cube_rotation_axis = vec3(0.f, 1.f, 0.f);
uniform float	cube_rotation_amount = 0.f;
uniform float	cube_size =		1.f;
uniform float	sphere_size =	1.f;
uniform float	weight;

// ------------------------------------------------------------------- variables
const int	MAX_STEPS = 		300;
const float MAX_DISTANCE =		1000.f;
const float MIN_DISTANCE =		0.001f;

// ----------------------------------------------------------------------- enums
const int sphere_a =	0;
const int sphere_b =	1;
const int cube_a =		0;
const int cube_b =		1;
const int color_a =		0;
const int color_b =		1;

// ------------------------------------------------------------------- functions
float signedDistanceSphere( vec3 p, vec3 centrum, float radius )
{
	return length( centrum - p ) - radius;
}

float signedDistanceCube( vec3 p, vec3 centre, vec3 size )
{
	vec3 offset = abs( p - centre ) - size;
	// distance from point outside box to edge (0 if inside box)
	float unsignedDistance = length( max( offset, 0.f ) );
	// distance from point inside box to edge (0 if outside box)
	float distanceInsideBox = min( max( offset.x, max( offset.y, offset.z ) ), 0.0 );
	return unsignedDistance + distanceInsideBox;
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

//infinite repititions
vec3 opRep( vec3 p, vec3 c )
{
	vec3 q = mod( p + .5f * c, c ) - .5f * c;
	return q;
}

float smooth_min( float dstA, float dstB, float k )
{
	float h = max( k - abs( dstA - dstB ), 0 ) / k;
	return ( min( dstA, dstB ) - h*h*h*k*1.f / 6.f );
}

vec4 get_distance_with_color( vec3 p )
{
	//First sphere distance
	float sphere01 = signedDistanceSphere( p, translate[sphere_a], sphere_size );
	//Second sphere distance
	//float sphere02 = signedDistanceSphere( p, translate[sphere_b], 1.f );
	
	// 1. Localize p to the cube's center and add translation
	vec3 local_p = p - translate[cube_b];
	
	// We rotate around axies based on TIME
	local_p = rotate( local_p, normalize( cube_rotation_axis ), cube_rotation_amount * TIME );

	//float sphere02 = signedDistanceCube(p, translate[cube_b], vec3(1.f));
	vec3 size = vec3( cube_size );
	float sphere02 = signedDistanceCube( local_p, vec3( 0.f ), size );

	
	// Calculate the blend factor 'h' (identical logic to smooth_min)
	float h = clamp( 0.5 + 0.5 * ( sphere01 - sphere02 ) / weight, 0.0, 1.0 );
	// Mix the distances (standard smooth min)
	float dist = mix( sphere01, sphere02, h ) - weight * h * ( 1.f - h );
	// Mix the colors based on the same blend factor
	vec3 mixed_color = mix( colors[color_b], colors[color_a], h );
	
	return vec4( mixed_color, dist );
}

float get_distance( vec3 p )
{
	//First sphere distance
	//float sphere01 = signedDistanceSphere(p, vec3(-1.5f, 0.f, -3.f), 1.f);
	//float sphere01 = signedDistanceSphere(p, translate[sphere_a], 1.f);

	//Second sphere distance
	//float sphere02 = signedDistanceSphere(p, vec3(1.5f, 0.f, -3.f), 1.f);
	//float sphere02 = signedDistanceSphere(p, translate[sphere_b], 1.f);

	// Combine them: the renderer will hit whichever surface is closer
	//return smooth_min(sphere01, sphere02, weight);
	//return min(sphere01, sphere02);
	//p = opRep( p, vec3( -6.f, -6.f, -6.f ) ); //uncomment for repeating spheres
	//return signedDistanceSphere( p, vec3( 0.f, 0.f, -3.f ), 1.f ); // you can change the position of the sphere from the vec3
	return get_distance_with_color( p ).w;
}

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

// ------------------------------------------------------- non colored meta balls
//vec4 raymarch( vec3 ray_origin, vec3 ray_dir )
//{
	//float	t = 0.f;
	//vec3	p = ray_origin;
	//int		i = 0;
	//
	//for ( int i = 0; i < MAX_STEPS; i++ )
	//{
		//float d = get_distance( p );
//
		//if( abs( d ) < MIN_DISTANCE )
		//{
			//vec3 normal = get_normal( p ) * .5f + .5f;
			//return vec4( normal, 1.f );
		//}
		//
		//if( t > MAX_DISTANCE )
			//break;
		//
		//t += d;	
		//p += d * ray_dir;
	//}
	//return vec4(float(i) * 0.01f); // uncomment for simple glow effect
	////return vec4( 0.f );
//}

// ---------------------------------------------------------- colored meta balls
vec4 raymarch_color( vec3 ray_origin, vec3 ray_dir )
{
	float	t = 0.f;
	vec3	p = ray_origin;
	int		i = 0;
	
	for ( int i = 0; i < MAX_STEPS; i++ )
	{
		vec4 scene = get_distance_with_color( p );
		float d = scene.w;
		vec3 col = scene.xyz;

		if( abs( d ) < MIN_DISTANCE )
		{
			//here we mix the color channel with the normals for effect
			vec3 normal =	get_normal( p ) * .5f + .5f;
			
			vec4 normal4 =	vec4( normal, 1.f );
			vec4 col4 =		vec4( col, 1.f );
			
			return mix( normal4, col4, .5f );
			//return vec4( normal, 1.f );
			//return vec4(col, 1.f);
		}
		if( t > MAX_DISTANCE )
			break;
		
		t += d;	
		p += d * ray_dir;
	}
	return vec4(0.f);
	//return vec4(float(i) * 0.01f); // uncomment for simple glow effect
	//return vec4( 0.f );
}

// --------------------------------------------------------------- vertex shader
void vertex() {
	//POSITION = vec4(VERTEX, 1.f);
}

// ------------------------------------------------------------- fragment shader
void fragment() {
	vec2 uv = SCREEN_UV * 2.f - 1.f;
	
	vec4 clip_position =	vec4( uv, 1.f, 1.f );
	vec4 world_position =	INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * clip_position;
	
	vec3 ray_end =			world_position.xyz / world_position.w;
	vec3 ray_origin = 		INV_VIEW_MATRIX[3].xyz;
	vec3 ray_direction = 	normalize( ray_end - ray_origin );
	
	//vec4 col_a = raymarch( ray_origin, ray_direction );
	//vec4 col_b = raymarch_color( ray_origin, ray_direction );
	
	//vec4 col = mix(col_a, col_b, .5f);
	vec4 col = raymarch_color( ray_origin, ray_direction );
	
	ALPHA =		col.a;
	ALBEDO =	col.rgb;
}