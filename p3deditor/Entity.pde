class Entity {
  int id;
  String name;
  String type; // "Cube", "Sphere", "Plane"
  Transform transform;
  boolean selected = false;
  color col = color(200);
  Material material = new Material();
  Entity parent = null;
  ArrayList<Entity> children = new ArrayList<Entity>();
  Blueprint blueprint; // v0.9.0 Visual Logic Blueprint
  String blueprintPDES = ""; // v0.9.4: Cached PDES logic (legacy/Start)
  HashMap<String, String> blueprintEventPDES = new HashMap<String, String>(); // v1.3: Per-event PDES
  
  public boolean visible = true; // v1.5: Rendering toggle
  
  // Point Light Specific Properties
  float lightIntensity = 1.0f;
  float lightRange = 300.0f;
  
  // v0.8.0: External Model Slot
  PShape model = null;
  String modelPath = ""; // v2.1: Track source for packaging
  
  // v0.5.0: Events & Scripts mounting
  HashMap<String, ArrayList<String>> eventHandlers = new HashMap<String, ArrayList<String>>();
  
  void mount(String eventType, String scriptPath) {
    if (!eventHandlers.containsKey(eventType)) {
      eventHandlers.put(eventType, new ArrayList<String>());
    }
    eventHandlers.get(eventType).add(scriptPath);
  }
  
  Entity(int id, String name, String type) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.transform = new Transform();
    
    if (type.equals("PointLight")) {
      this.col = color(255, 255, 180); // Warm light color
    } else {
      // Generate beautiful distinct pastel colors automatically based on ID
      float h = (id * 0.618033988749895f) % 1.0f; 
      java.awt.Color c = java.awt.Color.getHSBColor(h, 0.45f, 0.85f);
      this.col = color(c.getRed(), c.getGreen(), c.getBlue());
    }
    this.material.albedo = this.col;
    this.blueprint = new Blueprint(this);
  }
  
  void setParent(Entity newParent, boolean preserveWorld) {
    if (this.parent == newParent) return;
    
    PMatrix3D world = preserveWorld ? getWorldMatrix() : null;
    
    if (this.parent != null) {
      this.parent.children.remove(this);
    }
    
    this.parent = newParent;
    if (newParent != null) {
      newParent.children.add(this);
      
      if (preserveWorld) {
        PMatrix3D invParent = newParent.getWorldMatrix();
        invParent.invert();
        invParent.apply(world); 
        transform.position.set(invParent.m03, invParent.m13, invParent.m23);
      }
    } else if (preserveWorld) {
      transform.position.set(world.m03, world.m13, world.m23);
    }
  }
  
  void addChild(Entity child) {
    child.setParent(this, true);
  }
  
  void addChildNoUpdate(Entity child) {
    child.setParent(this, false);
  }
  
  void removeChild(Entity child) {
    child.setParent(null, true);
  }
  
  void render(PApplet app) {
    if (!visible) return;
    app.pushStyle();
    app.pushMatrix();
    
    // Apply local transform
    app.translate(transform.position.x, transform.position.y, transform.position.z);
    app.rotateX(transform.rotation.x);
    app.rotateY(transform.rotation.y);
    app.rotateZ(transform.rotation.z);
    app.scale(transform.scale.x, transform.scale.y, transform.scale.z);
    
    // PBR-like Specular Highlights (only for this geometry)
    app.specular(120);
    app.shininess(15.0f);
    
    if (type.equals("PointLight")) {
      app.resetShader();
      app.fill(selected ? color(255, 180, 0) : material.albedo);
    } else {
      if (p3deditor.this.pbrShader != null) {
        float r = ((material.albedo >> 16) & 0xFF) / 255.0f;
        float g = ((material.albedo >> 8) & 0xFF) / 255.0f;
        float b = (material.albedo & 0xFF) / 255.0f;
        p3deditor.this.pbrShader.set("albedo", r, g, b);
        p3deditor.this.pbrShader.set("metallic", material.metallic);
        p3deditor.this.pbrShader.set("roughness", material.roughness);
        
        // v0.8.5: Pass Model Matrix for World-Space IBL
        PMatrix3D mm = getWorldMatrix();
        p3deditor.this.pbrShader.set("modelMatrix", mm);
        
        // v0.8.0: Texture Maps support
        if (material.hasAlbedoMap) p3deditor.this.pbrShader.set("albedoMap", material.albedoMap);
        p3deditor.this.pbrShader.set("hasAlbedoMap", material.hasAlbedoMap);
        
        if (material.hasMetallicMap) p3deditor.this.pbrShader.set("metallicMap", material.metallicMap);
        p3deditor.this.pbrShader.set("hasMetallicMap", material.hasMetallicMap);
        
        if (material.hasRoughnessMap) p3deditor.this.pbrShader.set("roughnessMap", material.roughnessMap);
        p3deditor.this.pbrShader.set("hasRoughnessMap", material.hasRoughnessMap);
        
        app.shader(p3deditor.this.pbrShader);
      }
      app.fill(selected ? color(255, 180, 0) : material.albedo);
    }

    if (selected) {
      app.stroke(255, 100, 0);
      app.strokeWeight(1.5f);
    } else {
      app.noStroke();
    }
    
    // Draw geometry
    if (model != null) {
      app.shape(model);
    } else {
      if (type.equals("Cube")) app.box(50);
      else if (type.equals("Sphere")) { app.sphereDetail(30); app.sphere(30); }
      else if (type.equals("Plane")) { app.box(100, 1, 100); }
      else if (type.equals("PointLight")) {
      app.noStroke();
      app.emissive(col);
      app.sphere(8);
      app.emissive(0);
      if (selected) {
        app.stroke(col, 150);
        for(int i=0; i<8; i++) {
          float a = i * PConstants.TWO_PI / 8;
          app.line(0,0,0, cos(a)*18, sin(a)*18, 0);
          app.line(0,0,0, 0, cos(a)*18, sin(a)*18);
        }
      }
    }
    }
    
    if (!type.equals("PointLight")) app.resetShader();
    // Visual Range Sphere
    if (type.equals("PointLight") && selected) { // Only draw range sphere if it's a selected PointLight
      app.noFill();
      app.stroke(col, 40);
      app.strokeWeight(0.5f);
      app.sphereDetail(16);
      app.sphere(lightRange);
    }
    
    // Recursively render children
    for (Entity child : children) {
      child.render(app);
    }
    
    app.popMatrix();
    app.popStyle();
  }
  
  PVector getWorldPosition() {
    return getWorldMatrix().mult(new PVector(0,0,0), new PVector());
  }
  
  PMatrix3D getWorldMatrix() {
    PMatrix3D mat = new PMatrix3D();
    if (parent != null) {
      mat.set(parent.getWorldMatrix());
    }
    mat.translate(transform.position.x, transform.position.y, transform.position.z);
    mat.rotateX(transform.rotation.x);
    mat.rotateY(transform.rotation.y);
    mat.rotateZ(transform.rotation.z);
    mat.scale(transform.scale.x, transform.scale.y, transform.scale.z);
    return mat;
  }
  
  Entity cloneEntity(int newId, String newName) {
    Entity ne = new Entity(newId, newName, this.type);
    ne.col = this.col;
    ne.transform.position = this.transform.position.copy();
    ne.transform.rotation = this.transform.rotation.copy();
    ne.transform.scale = this.transform.scale.copy();
    
    // Recursive cloning of children
    for (Entity child : this.children) {
      Entity childClone = child.cloneEntity(-1, child.name);
      ne.addChildNoUpdate(childClone); // IMPORTANT: Use NoUpdate to keep local transform pristine!
    }
    
    return ne;
  }
  
  // Extract Euler angles (YXZ order) from a rotation matrix
  void updateRotationFromMatrix(PMatrix3D m) {
    // Handling Y-X-Z order (Y first, then X, then Z)
    float r11 = m.m00, r12 = m.m01, r13 = m.m02;
    float r21 = m.m10, r22 = m.m11, r23 = m.m12;
    float r31 = m.m20, r32 = m.m21, r33 = m.m22;
    
    // Normalize vectors just in case
    float s = sqrt(r11*r11 + r12*r12 + r13*r13); // Scale factor
    if (s < 0.0001) return;
    r11/=s; r12/=s; r13/=s;
    r21/=s; r22/=s; r23/=s;
    r31/=s; r32/=s; r33/=s;

    // For YXZ:
    // x = asin(-r23)
    // y = atan2(r13, r33)
    // z = atan2(r21, r22)
    
    transform.rotation.x = asin(constrain(-r23, -1, 1));
    if (abs(r23) < 0.99999) {
      transform.rotation.y = atan2(r13, r33);
      transform.rotation.z = atan2(r21, r22);
    } else {
      // Gimbal lock
      transform.rotation.y = atan2(-r31, r11);
      transform.rotation.z = 0;
    }
  }

  // v0.5.0: Snapshot Support
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("id", id);
    json.setString("name", name);
    json.setString("type", type);
    json.setInt("color", col);
    json.setBoolean("visible", visible);
    json.setString("modelPath", modelPath);
    
    JSONObject pos = new JSONObject();
    pos.setFloat("x", transform.position.x);
    pos.setFloat("y", transform.position.y);
    pos.setFloat("z", transform.position.z);
    json.setJSONObject("pos", pos);
    
    JSONObject rot = new JSONObject();
    rot.setFloat("x", transform.rotation.x);
    rot.setFloat("y", transform.rotation.y);
    rot.setFloat("z", transform.rotation.z);
    json.setJSONObject("rot", rot);
    
    JSONObject scl = new JSONObject();
    scl.setFloat("x", transform.scale.x);
    scl.setFloat("y", transform.scale.y);
    scl.setFloat("z", transform.scale.z);
    json.setJSONObject("scale", scl);
    
    if (type.equals("PointLight")) {
      json.setFloat("intensity", lightIntensity);
      json.setFloat("range", lightRange);
    }
    
    // Material Properties
    JSONObject mat = new JSONObject();
    mat.setInt("albedo", material.albedo);
    mat.setFloat("metallic", material.metallic);
    mat.setFloat("roughness", material.roughness);
    mat.setString("albedoPath", material.albedoPath);
    mat.setString("metallicPath", material.metallicPath);
    mat.setString("roughnessPath", material.roughnessPath);
    json.setJSONObject("material", mat);
    
    JSONArray evts = new JSONArray();
    int idx = 0;
    for (String key : eventHandlers.keySet()) {
      for (String script : eventHandlers.get(key)) {
        JSONObject h = new JSONObject();
        h.setString("event", key);
        h.setString("script", script);
        evts.setJSONObject(idx++, h);
      }
    }
    json.setJSONArray("events", evts);
    
    if (parent != null) json.setInt("parentId", parent.id);
    
    return json;
  }
  
  void fromJSON(JSONObject json) {
    this.name = json.getString("name");
    this.col = json.getInt("color");
    this.visible = json.getBoolean("visible", true);
    this.modelPath = json.getString("modelPath", "");
    
    JSONObject pos = json.getJSONObject("pos");
    transform.position.set(pos.getFloat("x"), pos.getFloat("y"), pos.getFloat("z"));
    JSONObject rot = json.getJSONObject("rot");
    transform.rotation.set(rot.getFloat("x"), rot.getFloat("y"), rot.getFloat("z"));
    JSONObject scl = json.getJSONObject("scale");
    transform.scale.set(scl.getFloat("x"), scl.getFloat("y"), scl.getFloat("z"));
    
    if (type.equals("PointLight")) {
      lightIntensity = json.getFloat("intensity");
      lightRange = json.getFloat("range");
    }
    
    if (!json.isNull("material")) {
      JSONObject mat = json.getJSONObject("material");
      material.albedo = mat.getInt("albedo");
      material.metallic = mat.getFloat("metallic");
      material.roughness = mat.getFloat("roughness");
      material.albedoPath = mat.getString("albedoPath", "");
      material.metallicPath = mat.getString("metallicPath", "");
      material.roughnessPath = mat.getString("roughnessPath", "");
    }
    
    eventHandlers.clear();
    if (!json.isNull("events")) {
      JSONArray evts = json.getJSONArray("events");
      for (int i=0; i<evts.size(); i++) {
        JSONObject h = evts.getJSONObject(i);
        mount(h.getString("event"), h.getString("script"));
      }
    }
  }

  int getPolyCount() {
    if (type.equals("Cube")) return 12;
    if (type.equals("Plane")) return 2;
    if (type.equals("Sphere")) return 288;
    return 0;
  }
}

class Transform {
  PVector position = new PVector(0, 0, 0);
  PVector rotation = new PVector(0, 0, 0);
  PVector scale = new PVector(1, 1, 1);
}
