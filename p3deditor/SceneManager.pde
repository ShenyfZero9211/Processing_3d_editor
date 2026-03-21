class SceneManager {
  ArrayList<Entity> entities = new ArrayList<Entity>();
  ArrayList<Entity> selectedEntities = new ArrayList<Entity>();
  Gizmo gizmo = new Gizmo();
  int nextEntityId = 1;
  UndoManager undoManager = new UndoManager();
  boolean useLocalSpace = false; // Default to World as requested
  
  Entity findEntityById(int id) {
    for (Entity e : entities) if (e.id == id) return e;
    return null;
  }
  
  void addEntity(String name, String type) {
    Entity e = new Entity(nextEntityId++, name, type);
    entities.add(e);
    selectEntity(e, false);
    undoManager.push(new AddEntityCommand(this, e));
  }
  
  void addEntityToSceneRecursive(Entity e) {
    if (e.id == -1) e.id = nextEntityId++;
    if (!entities.contains(e)) entities.add(e);
    for (Entity child : e.children) {
      addEntityToSceneRecursive(child);
    }
  }
  
  void render(PApplet app) {
    // Global Base Illumination
    app.ambientLight(50, 50, 50);
    app.lightSpecular(180, 180, 180);
    
    // Note: The main lighting is now handled in p3deditor.draw() via PointLight entities.
    // We keep a very weak fill here just to prevent total blackness on backfaces.
    app.directionalLight(40, 45, 50, 0.5f, -0.2f, 0.5f); 
    
    // ONLY start rendering from root entities (hierarchical recursion handles children)
    for(Entity e : entities) {
      if (e.parent == null) {
        e.render(app);
      }
    }
    
    // Render Gizmo over selected entities
    if (!selectedEntities.isEmpty()) {
      app.hint(PConstants.DISABLE_DEPTH_TEST);
      gizmo.render(app, this);
      app.hint(PConstants.ENABLE_DEPTH_TEST);
    }
  }
  
  void selectEntity(Entity e, boolean ctrlDown) {
    if (!ctrlDown) {
      clearSelection();
    }
    if (e != null && !selectedEntities.contains(e)) {
      selectedEntities.add(e);
      e.selected = true;
    }
  }
  
  Entity pickEntity(Ray ray, Raycaster caster) {
    Entity closest = null;
    float minDist = Float.MAX_VALUE;
    for (Entity e : entities) {
      float t = caster.intersectEntity(ray, e);
      if (t > 0 && t < minDist) {
        minDist = t;
        closest = e;
      }
    }
    return closest;
  }
  
  void clearSelection() {
    for (Entity sel : selectedEntities) {
      sel.selected = false;
    }
    selectedEntities.clear();
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
      ej.setInt("parentId", (e.parent != null) ? e.parent.id : -1);
      
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
    
    String path = file.getAbsolutePath();
    if (!path.toLowerCase().endsWith(".p3de")) {
      path += ".p3de";
    }
    
    saveJSONObject(root, path);
    println("Saved scene to " + path);
  }
  
  void loadScene(File file) {
    if (file == null) return;
    
    try {
      JSONObject root = loadJSONObject(file.getAbsolutePath());
      entities.clear();
      clearSelection();
      
      nextEntityId = root.getInt("nextEntityId");
      
      JSONArray entArr = root.getJSONArray("entities");
      ArrayList<Integer> parentIds = new ArrayList<Integer>();
      
      // Pass 1: Create all entities
      for (int i=0; i<entArr.size(); i++) {
        JSONObject ej = entArr.getJSONObject(i);
        Entity e = new Entity(ej.getInt("id"), ej.getString("name"), ej.getString("type"));
        e.col = ej.getInt("color");
        
        JSONObject t = ej.getJSONObject("transform");
        e.transform.position.set(t.getFloat("px"), t.getFloat("py"), t.getFloat("pz"));
        e.transform.rotation.set(t.getFloat("rx"), t.getFloat("ry"), t.getFloat("rz"));
        e.transform.scale.set(t.getFloat("sx"), t.getFloat("sy"), t.getFloat("sz"));
        
        entities.add(e);
        parentIds.add(ej.isNull("parentId") ? -1 : ej.getInt("parentId"));
      }
      
      // Pass 2: Link parents
      for (int i=0; i<entities.size(); i++) {
        int pid = parentIds.get(i);
        if (pid != -1) {
          Entity child = entities.get(i);
          for (Entity potentialParent : entities) {
            if (potentialParent.id == pid) {
              potentialParent.addChild(child);
              break;
            }
          }
        }
      }
      
      println("Loaded scene from " + file.getAbsolutePath());
    } catch (Exception ex) {
      println("Failed to load scene: " + ex.getMessage());
      ex.printStackTrace();
    }
  }
}
