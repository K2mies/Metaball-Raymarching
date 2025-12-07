shader_type spatial;
render_mode unshaded;

// ------------------------------------------------------------------- variables
const int	MAX_STEPS = 300;
const float MAX_DISTANCE = 1000.f;
const float MIN_DISTANCE = 0.001f;

// ------------------------------------------------------------------- functions
float signedDistanceSphere( vec3 p, vec3 centrum, float radius )
{
	return length( centrum - p ) - radius;
}

//infinite repititions
vec3 opRep( vec3 p, vec3 c )
{
	vec3 q = mod( p + .5f * c, c ) - .5f * c;
	return q;
}

float get_distance( vec3 p )
{
	//p = opRep( p, vec3( 3 ) ); //uncomment for repeating spheres
	p = opRep( p, vec3( -6.f, -6.f, -6.f ) ); //uncomment for repeating spheres

	return signedDistanceSphere( p, vec3( 0.f, 0.f, -3.f ), 1.f ); // you can change the position of the sphere from the vec3
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

vec4 raymarch( vec3 ray_origin, vec3 ray_dir )
{
	float	t = 0.f;
	vec3	p = ray_origin;
	
	for ( int i = 0; i < MAX_STEPS; i++ )
	{
		float d = get_distance( p );
		//t += d;
		
		if( abs( d ) < MIN_DISTANCE )
		{
			vec3 normal = get_normal( p ) * .5f + .5f;
			return vec4( normal, 1.f );
		}
		
		if( t > MAX_DISTANCE )
			break;
		
		t += d;	
		p += d * ray_dir;
		//if(abs(d) < MIN_DISTANCE)
			//return vec4(get_normal(p), 1);
	}
	//return vec4(float(i) * 0.01f); // uncomment for simple glow effect
	return vec4( 0.f );
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
	
	//vec4 camera = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(uv, 1, 1);
	
	//vec3 ray_origin = INV_VIEW_MATRIX[3].xyz;
	//vec3 ray_dir = normalize(camera.xyz);
	
	vec4 col = raymarch( ray_origin, ray_direction );
	
	ALPHA =		col.a;
	ALBEDO =	col.rgb;
}