uniform mat4 transform;
uniform mat4 modelview;
uniform mat3 normalMatrix;
uniform mat4 texMatrix;

// v0.8.5: Model matrix for World-Space PBR
uniform mat4 modelMatrix;

attribute vec4 position;
attribute vec3 normal;
attribute vec2 texCoord;

varying vec3 vertNormal;
varying vec3 vertPos;
varying vec2 vertTexCoord;

// v0.8.5: World-Space varyings
varying vec3 worldPos;
varying vec3 worldNormal;

void main() {
  vertPos = vec3(modelview * position);
  vertNormal = normalize(normalMatrix * normal);
  vertTexCoord = (texMatrix * vec4(texCoord, 1.0, 1.0)).st;
  
  // v0.8.5: World-Space calculations
  worldPos = vec3(modelMatrix * position);
  worldNormal = normalize(mat3(modelMatrix) * normal);
  
  gl_Position = transform * position;
}
