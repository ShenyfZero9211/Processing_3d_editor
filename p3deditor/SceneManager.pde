class SceneManager {
  ArrayList<Entity> entities = new ArrayList<Entity>();
  ArrayList<Entity> selectedEntities = new ArrayList<Entity>();
  Gizmo gizmo = new Gizmo();
  int nextEntityId = 1;
  UndoManager undoManager = new UndoManager();
  boolean useLocalSpace = false; // Default to World as requested
  Entity lastHoveredEntity = null;
  
  // v2.0: Engine Mode System
  public static final int MODE_EDIT = 0;
  public static final int MODE_SIMULATE = 1;
  public static final int MODE_GAME = 2;
  
  int engineMode = MODE_EDIT;
  boolean isPlaying() { return engineMode != MODE_EDIT; }
  
  JSONArray sceneSnapshot = null;
  int snapshotNextId = 1;
  
  // v0.8.0: Global IBL Environment Map
  PImage envMap = null;
  float envMapIntensity = 1.0f; 
  int backgroundColor = p3deditor.this.color(30,30,35); // v2.4: Scene background
  
  // v2.4: Level Blueprint (Global Logic)
  Blueprint levelBlueprint = new Blueprint(this);
  String blueprintPDES = "";
  HashMap<String, String> blueprintEventPDES = new HashMap<String, String>();
  
  void saveSnapshot() {
    sceneSnapshot = new JSONArray();
    for (int i=0; i<entities.size(); i++) {
      sceneSnapshot.setJSONObject(i, entities.get(i).toJSON());
    }
    snapshotNextId = nextEntityId;
    println("Scene Snapshot Saved (" + entities.size() + " entities)");
  }
  
  void restoreSnapshot() {
    if (sceneSnapshot == null) return;
    
    // v1.1: Preserve blueprints before restoring snapshot
    HashMap<Integer, Blueprint> savedBlueprints = new HashMap<Integer, Blueprint>();
    for (Entity e : entities) {
      savedBlueprints.put(e.id, e.blueprint);
    }
    Blueprint savedLevelBP = levelBlueprint;
    
    entities.clear();
    selectedEntities.clear();
    nextEntityId = snapshotNextId;
    
    // First pass: Recreate all entities
    HashMap<Integer, Entity> idMap = new HashMap<Integer, Entity>();
    for (int i=0; i<sceneSnapshot.size(); i++) {
      JSONObject json = sceneSnapshot.getJSONObject(i);
      Entity e = new Entity(json.getInt("id"), json.getString("name"), json.getString("type"));
      e.fromJSON(json);
      
      // v1.1: Restore saved blueprint
      if (savedBlueprints.containsKey(e.id)) {
        e.blueprint = savedBlueprints.get(e.id);
        e.blueprint.owner = e; // Update owner reference
      }
      
      levelBlueprint = savedLevelBP;
      levelBlueprint.owner = this;
      
      entities.add(e);
      idMap.put(e.id, e);
    }
    
    // Second pass: Reconstruct hierarchy
    for (int i=0; i<sceneSnapshot.size(); i++) {
      JSONObject json = sceneSnapshot.getJSONObject(i);
      if (json.hasKey("parentId")) {
        Entity child = idMap.get(json.getInt("id"));
        Entity parent = idMap.get(json.getInt("parentId"));
        if (child != null && parent != null) child.setParent(parent, false);
      }
    }
    
    println("Scene Snapshot Restored (Blueprints preserved)");
  }
  
  Entity findEntityById(int id) {
    for (Entity e : entities) if (e.id == id) return e;
    return null;
  }
  
  Entity addEntity(String name, String type) {
    Entity e = new Entity(nextEntityId++, name, type);
    entities.add(e);
    selectEntity(e, false);
    undoManager.push(new AddEntityCommand(this, e));
    return e;
  }
  
  void triggerEvent(Entity e, String type) {
    if (e == null && !type.equals("Start") && !type.equals("Update")) return;
    
    // v1.3: Multi-event Blueprint PDES support
    // Map runtime event names to Blueprint event keys
    String vlbKey = null;
    if (type.equals("Start")) vlbKey = "OnStart";
    else if (type.equals("Update")) vlbKey = "OnUpdate";
    else if (type.equals("onClick")) vlbKey = "OnMouseClick";
    else if (type.equals("OnKeyPress")) vlbKey = "OnKeyPress";
    else if (type.equals("OnBeginOverlap")) vlbKey = "OnBeginOverlap";
    else if (type.equals("OnEndOverlap")) vlbKey = "OnEndOverlap";
    
    if (vlbKey != null) {
      HashMap<String, String> eventMap = (e != null) ? e.blueprintEventPDES : blueprintEventPDES;
      if (eventMap.containsKey(vlbKey)) {
        String pdes = eventMap.get(vlbKey);
        if (pdes != null && !pdes.isEmpty()) {
          String ownerName = (e != null) ? e.name : "Level";
          if (!type.equals("Update")) {
            p3deditor.this.ui.debugConsole.addLog("> Event [" + vlbKey + "] on '" + ownerName + "' running VLB Logic", 2);
          }
          p3deditor.this.scriptManager.runScript("VLB_" + vlbKey + "_" + ownerName, pdes, e);
        }
      }
    }
    
    // Legacy support & Entity-specific scripts
    if (e != null) {
      if (type.equals("Start") && !e.blueprintEventPDES.containsKey("OnStart") && e.blueprintPDES != null && !e.blueprintPDES.isEmpty()) {
        p3deditor.this.ui.debugConsole.addLog("> Event [Start] on '" + e.name + "' running VLB Logic (legacy)", 2);
        p3deditor.this.scriptManager.runScript("VLB_" + e.name, e.blueprintPDES, e);
      }
      
      ArrayList<String> scripts = e.eventHandlers.get(type);
      if (scripts != null) {
        for (String scriptPath : scripts) {
          String[] lines = p3deditor.this.loadStrings(scriptPath);
          if (lines != null) {
            if (!type.equals("Update")) {
               p3deditor.this.ui.debugConsole.addLog("> Event [" + type + "] on '" + e.name + "' triggered script: " + scriptPath, 2);
            }
            p3deditor.this.scriptManager.runScript(scriptPath, String.join("\n", lines), e);
          } else {
            p3deditor.this.ui.debugConsole.addLog("Error: Event script not found: " + scriptPath, 3);
          }
        }
      }
    }
  }
  
  void updateShaderLights(PShader shader) {
    if (shader == null) return;
    
    shader.set("cameraPos", p3deditor.this.editorCamera.pos);
    
    ArrayList<Entity> lights = new ArrayList<Entity>();
    for (Entity e : entities) {
      if (e.type.equals("PointLight") && e.visible) lights.add(e);
      if (lights.size() >= 5) break;
    }
    
    float[] lPos = new float[lights.size() * 3];
    float[] lCol = new float[lights.size() * 3];
    
    // Use the current modelview matrix to transform light positions into view space
    PMatrix3D view = ((PGraphics3D)p3deditor.this.g).modelview;
    
    for (int i = 0; i < lights.size(); i++) {
        Entity l = lights.get(i);
        PVector wPos = l.getWorldPosition();
        PVector vPos = new PVector();
        view.mult(wPos, vPos);
        
        lPos[i*3 + 0] = vPos.x;
        lPos[i*3 + 1] = vPos.y;
        lPos[i*3 + 2] = vPos.z;
        
        lCol[i*3 + 0] = p3deditor.this.red(l.col) / 255.0f * l.lightIntensity;
        lCol[i*3 + 1] = p3deditor.this.green(l.col) / 255.0f * l.lightIntensity;
        lCol[i*3 + 2] = p3deditor.this.blue(l.col) / 255.0f * l.lightIntensity;
    }
    
    p3deditor.this.pbrShader.set("lightPositions", lPos, 3);
    p3deditor.this.pbrShader.set("lightColors", lCol, 3);
    p3deditor.this.pbrShader.set("lightCount", lights.size());
    
    // v0.8.0: Environmental Lighting (IBL)
    if (envMap != null) {
      p3deditor.this.pbrShader.set("envMap", envMap);
      p3deditor.this.pbrShader.set("hasEnvMap", true);
      p3deditor.this.pbrShader.set("envMapIntensity", envMapIntensity);
    } else {
      p3deditor.this.pbrShader.set("hasEnvMap", false);
    }
  }
  
  void addEntityToSceneRecursive(Entity e) {
    if (e.id == -1) e.id = nextEntityId++;
    if (!entities.contains(e)) entities.add(e);
    for (Entity child : e.children) {
      addEntityToSceneRecursive(child);
    }
  }
  
  void render(PApplet app) {
    updateShaderLights(p3deditor.this.pbrShader);
    // Note: Global lighting is now handled in p3deditor.draw() to respect the 8-light limit.
    
    // ONLY start rendering from root entities (hierarchical recursion handles children)
    for(Entity e : entities) {
      if (e.parent == null) {
        e.render(app);
      }
    }
    
    // Render Gizmo over selected entities
    if (!selectedEntities.isEmpty() && engineMode != MODE_GAME) {
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
    root.setInt("backgroundColor", backgroundColor);
    root.setFloat("envMapIntensity", envMapIntensity);
    root.setJSONObject("levelBlueprint", serializeBlueprint(levelBlueprint));
    
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
      ej.setJSONObject("blueprint", serializeBlueprint(e.blueprint));
      
      entArr.setJSONObject(i, ej);
    }
    root.setJSONArray("entities", entArr);
    
    String path = file.getAbsolutePath();
    if (!path.toLowerCase().endsWith(".p3de")) {
      path += ".p3de";
    }
    
    saveJSONObject(root, path);
    if (p3deditor.this.ui != null) p3deditor.this.ui.debugConsole.addLog("Saved scene to " + path, 1);
    println("Saved scene to " + path);
  }
  
  void loadScene(File file) {
    if (file == null) return;
    
    try {
      JSONObject root = loadJSONObject(file.getAbsolutePath());
      entities.clear();
      clearSelection();
      
      nextEntityId = root.getInt("nextEntityId");
      backgroundColor = root.getInt("backgroundColor", p3deditor.this.color(30, 30, 35));
      envMapIntensity = root.getFloat("envMapIntensity", 1.0f);
      
      if (root.hasKey("levelBlueprint")) {
        deserializeBlueprint(levelBlueprint, root.getJSONObject("levelBlueprint"));
      }
      
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
        
        if (ej.hasKey("blueprint")) {
          deserializeBlueprint(e.blueprint, ej.getJSONObject("blueprint"));
        }
        
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
      
      if (p3deditor.this.ui != null) p3deditor.this.ui.debugConsole.addLog("Loaded scene: " + file.getName(), 1);
      println("Loaded scene: " + file.getAbsolutePath());
    } catch (Exception e) {
      if (p3deditor.this.ui != null) p3deditor.this.ui.debugConsole.addLog("Error loading scene: " + e.getMessage(), 3);
      System.err.println("Error loading scene: " + e.getMessage());
      e.printStackTrace();
    }
  }
  
  // v2.4 Blueprint Serialization Helpers
  JSONObject serializeBlueprint(Blueprint bp) {
    JSONObject bpj = new JSONObject();
    JSONArray nodesArr = new JSONArray();
    for (int ni = 0; ni < bp.nodes.size(); ni++) {
      VLBNode nd = bp.nodes.get(ni);
      JSONObject nj = new JSONObject();
      nj.setInt("id", nd.id);
      nj.setString("title", nd.title);
      nj.setString("type", nd.type);
      nj.setFloat("x", nd.x);
      nj.setFloat("y", nd.y);
      JSONArray pinsArr = new JSONArray();
      ArrayList<VLBPin> allPins = new ArrayList<VLBPin>();
      allPins.addAll(nd.inputs); allPins.addAll(nd.outputs);
      for (int pi = 0; pi < allPins.size(); pi++) {
        VLBPin pin = allPins.get(pi);
        JSONObject pj = new JSONObject();
        pj.setString("label", pin.label);
        pj.setBoolean("isInput", pin.isInput);
        pj.setFloat("val", pin.val);
        pj.setString("sVal", pin.sVal);
        pinsArr.setJSONObject(pi, pj);
      }
      nj.setJSONArray("pins", pinsArr);
      nodesArr.setJSONObject(ni, nj);
    }
    bpj.setJSONArray("nodes", nodesArr);
    JSONArray connsArr = new JSONArray();
    for (int ci = 0; ci < bp.connections.size(); ci++) {
      VLBConnection conn = bp.connections.get(ci);
      JSONObject cj = new JSONObject();
      cj.setInt("fromNodeId", conn.from.parent.id);
      cj.setString("fromPinLabel", conn.from.label);
      cj.setBoolean("fromIsInput", conn.from.isInput);
      cj.setInt("toNodeId", conn.pinTo.parent.id);
      cj.setString("toPinLabel", conn.pinTo.label);
      cj.setBoolean("toIsInput", conn.pinTo.isInput);
      connsArr.setJSONObject(ci, cj);
    }
    bpj.setJSONArray("connections", connsArr);
    return bpj;
  }
  
  void deserializeBlueprint(Blueprint bp, JSONObject bpj) {
    bp.nodes.clear();
    bp.connections.clear();
    JSONArray nodesArr = bpj.getJSONArray("nodes");
    for (int ni = 0; ni < nodesArr.size(); ni++) {
      JSONObject nj = nodesArr.getJSONObject(ni);
      VLBNode nd = new VLBNode(nj.getInt("id"), nj.getString("title"), nj.getString("type"), nj.getFloat("x"), nj.getFloat("y"));
      if (nj.hasKey("pins")) {
        JSONArray pinsArr = nj.getJSONArray("pins");
        for (int pi = 0; pi < pinsArr.size(); pi++) {
          JSONObject pj = pinsArr.getJSONObject(pi);
          VLBPin matchPin = nd.findPin(pj.getString("label"), pj.getBoolean("isInput"));
          if (matchPin != null) {
            matchPin.val = pj.getFloat("val");
            matchPin.sVal = pj.getString("sVal");
          }
        }
      }
      bp.nodes.add(nd);
    }
    if (bpj.hasKey("connections")) {
      JSONArray connsArr = bpj.getJSONArray("connections");
      for (int ci = 0; ci < connsArr.size(); ci++) {
        JSONObject cj = connsArr.getJSONObject(ci);
        VLBPin fromPin = null, toPin = null;
        for (VLBNode nd : bp.nodes) {
          if (nd.id == cj.getInt("fromNodeId")) fromPin = nd.findPin(cj.getString("fromPinLabel"), cj.getBoolean("fromIsInput"));
          if (nd.id == cj.getInt("toNodeId")) toPin = nd.findPin(cj.getString("toPinLabel"), cj.getBoolean("toIsInput"));
        }
        if (fromPin != null && toPin != null) {
          bp.connections.add(new VLBConnection(fromPin, toPin));
          fromPin.connectedTo = toPin;
          toPin.connectedTo = fromPin;
        }
      }
    }
  }
}
