#if defined(VERTEX)
uniform mat4 MVPMatrix;
in vec4 VertexCoord;
in vec4 TexCoord;
out vec2 TEX0;
void main() { gl_Position=MVPMatrix*VertexCoord; TEX0=TexCoord.xy; }
#elif defined(FRAGMENT)
in vec2 TEX0;
uniform sampler2D Texture;
uniform sampler2D PassFeedback0Texture;
out vec4 FragColor;
void main() {
 vec3 source=texture(Texture,TEX0).rgb;
 vec3 previous=texture(PassFeedback0Texture,TEX0).rgb;
 FragColor=vec4(0.5*source+0.5*previous,1.0);
}
#endif
