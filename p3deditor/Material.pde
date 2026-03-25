/**
 * Material.pde - PBR Material Data Model
 * 
 * Version: v0.4.9
 * Responsibilities:
 * - Stores physical surface properties for the Cook-Torrance BRDF shader.
 * - Manages texture slots for Albedo, Metallic, and Roughness maps.
 * - Provides path tracking for asset packaging and standalone export.
 */
class Material {
  int albedo = #FFFFFF;
  float metallic = 0.0;
  float roughness = 0.5;
  
  // v0.8.0: Texture Slots
  PImage albedoMap = null;
  PImage metallicMap = null;
  PImage roughnessMap = null;
  
  // v2.1: Path Tracking for Packaging
  String albedoPath = "";
  String metallicPath = "";
  String roughnessPath = "";
  
  boolean hasAlbedoMap = false;
  boolean hasMetallicMap = false;
  boolean hasRoughnessMap = false;
  
  void setAlbedoMap(PImage img) { this.albedoMap = img; this.hasAlbedoMap = (img != null); }
  void setMetallicMap(PImage img) { this.metallicMap = img; this.hasMetallicMap = (img != null); }
  void setRoughnessMap(PImage img) { this.roughnessMap = img; this.hasRoughnessMap = (img != null); }

  Material() {}
  
  Material(int col, float met, float rough) {
    this.albedo = col;
    this.metallic = met;
    this.roughness = rough;
  }
}
