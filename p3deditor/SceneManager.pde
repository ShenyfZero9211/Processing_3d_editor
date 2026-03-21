class SceneManager {
  ArrayList<Entity> entities = new ArrayList<Entity>();
  Entity selectedEntity = null;
  Gizmo gizmo = new Gizmo();
  int nextEntityId = 1;
  
  void addEntity(String name, String type) {
    Entity e = new Entity(nextEntityId++, name, type);
    entities.add(e);
    selectEntity(e);
  }
  
  void render(PApplet app) {
    // Advanced 3-point Studio Lighting
    app.ambientLight(60, 60, 60);
    app.directionalLight(240, 230, 220, -0.5f, 0.8f, -0.5f); // Key Light (Warm Sun)
    app.directionalLight(60, 80, 120, 0.5f, -0.2f, 0.5f);   // Fill Light (Cool Sky)
    app.directionalLight(80, 80, 90, 0.0f, 0.0f, -1.0f);    // Rim Light (Backlight)
    app.lightSpecular(200, 200, 200);
    
    for(Entity e : entities) {
      e.render(app);
    }
    
    // Render Gizmo over selected entity without depth testing
    if (selectedEntity != null) {
      app.hint(DISABLE_DEPTH_TEST);
      gizmo.render(app, selectedEntity);
      app.hint(ENABLE_DEPTH_TEST);
    }
  }
  
  void selectEntity(Entity e) {
    if (selectedEntity != null) {
      selectedEntity.selected = false;
    }
    selectedEntity = e;
    if (selectedEntity != null) {
      selectedEntity.selected = true;
    }
  }
  
  void saveScene(File file) {
    if (file == null) return;
    
    JSONObject root = new JSONObject();
    root.setInt("nextEntityId", nextEntityId);
    
    JSONArray entArr = new JSONArray();
    for (int i=0; i<entities.size(); i++) {
      Entity e = entities.get(i);
      JSONObject ej = new JSONObject();
      ej.setInt("id", e.id);
      ej.setString("name", e.name);
      ej.setString("type", e.type);
      ej.setInt("color", e.col);
      
      JSONObject t = new JSONObject();
      t.setFloat("px", e.transform.position.x);
      t.setFloat("py", e.transform.position.y);
      t.setFloat("pz", e.transform.position.z);
      t.setFloat("rx", e.transform.rotation.x);
      t.setFloat("ry", e.transform.rotation.y);
      t.setFloat("rz", e.transform.rotation.z);
      t.setFloat("sx", e.transform.scale.x);
      t.setFloat("sy", e.transform.scale.y);
      t.setFloat("sz", e.transform.scale.z);
      ej.setJSONObject("transform", t);
      
      entArr.setJSONObject(i, ej);
    }
    root.setJSONArray("entities", entArr);
    
    saveJSONObject(root, file.getAbsolutePath());
    println("Saved scene to " + file.getAbsolutePath());
  }
  
  void loadScene(File file) {
    if (file == null) return;
    
    try {
      JSONObject root = loadJSONObject(file.getAbsolutePath());
      entities.clear();
      selectedEntity = null;
      
      nextEntityId = root.getInt("nextEntityId");
      
      JSONArray entArr = root.getJSONArray("entities");
      for (int i=0; i<entArr.size(); i++) {
        JSONObject ej = entArr.getJSONObject(i);
        Entity e = new Entity(ej.getInt("id"), ej.getString("name"), ej.getString("type"));
        e.col = ej.getInt("color");
        
        JSONObject t = ej.getJSONObject("transform");
        e.transform.position.set(t.getFloat("px"), t.getFloat("py"), t.getFloat("pz"));
        e.transform.rotation.set(t.getFloat("rx"), t.getFloat("ry"), t.getFloat("rz"));
        e.transform.scale.set(t.getFloat("sx"), t.getFloat("sy"), t.getFloat("sz"));
        
        entities.add(e);
      }
      println("Loaded scene from " + file.getAbsolutePath());
    } catch (Exception ex) {
      println("Failed to load scene: " + ex.getMessage());
    }
  }
}
