import java.util.Map;
import java.util.HashMap;

class CommandInterpreter {
  SceneManager scene;
  String lastResult = "";
  HashMap<String, String> aliases = new HashMap<String, String>();
  int recursionDepth = 0;
  final int MAX_RECURSION = 10;
  ScriptManager scriptManager;
  
  CommandInterpreter(SceneManager s) {
    this.scene = s;
  }
  
  void setScriptManager(ScriptManager sm) {
    this.scriptManager = sm;
  }
  
  String execute(String cmdLine) {
    if (cmdLine == null || cmdLine.trim().isEmpty()) return "";
    
    // 1. Support for multi-commands separated by semicolon
    if (cmdLine.contains(";") && recursionDepth == 0) {
      String[] subCmds = cmdLine.split(";");
      String finalRes = "";
      for (String sc : subCmds) {
        String r = execute(sc.trim());
        if (!r.isEmpty()) finalRes = r; // Keep last result
      }
      return finalRes;
    }

    ArrayList<String> parts = parseArgs(cmdLine);
    if (parts.size() == 0) return "";
    
    String rawCmd = parts.get(0).toLowerCase();
    
    // 2. Alias Resolution
    if (aliases.containsKey(rawCmd)) {
      if (recursionDepth > MAX_RECURSION) return "Error: Maximum alias recursion depth reached!";
      recursionDepth++;
      String expanded = aliases.get(rawCmd);
      // Append original arguments to the alias expansion
      for (int i=1; i<parts.size(); i++) expanded += " " + parts.get(i);
      String res = execute(expanded);
      recursionDepth--;
      return res;
    }

    try {
      if (rawCmd.equals("move") || rawCmd.equals("translate")) {
        if (parts.size() < 5) return "Error: move <name> <x> <y> <z>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        float dx = float(parts.get(2));
        float dy = float(parts.get(3));
        float dz = float(parts.get(4));
        e.transform.position.add(dx, dy, dz);
        return "SUCCESS: Moved " + e.name;
      } 
      else if (rawCmd.equals("tp") || rawCmd.equals("set_pos")) {
        if (parts.size() < 5) return "Error: tp <name> <x> <y> <z>";
        Entity e = findEntity(parts.get(1));
        e.transform.position.set(float(parts.get(2)), float(parts.get(3)), float(parts.get(4)));
        // v1.8 debug: Log execution to check values
        p3deditor.this.ui.debugConsole.addLog("PDES Trace: tp " + e.name + " to " + parts.get(2) + " (actual: " + e.transform.position.x + ")", 1);
        return "SUCCESS: Teleported " + e.name;
      }
      else if (rawCmd.equals("color") || rawCmd.equals("set_color")) {
        if (parts.size() < 3) return "Error: color <name> <hex>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        String hexStr = parts.get(2).replace("#", "");
        if (hexStr.length() == 6) {
          e.col = (int)Long.parseLong("FF" + hexStr, 16);
          e.material.albedo = e.col;
          return "SUCCESS: Colored " + e.name;
        }
        return "Error: Invalid hex format";
      }
      else if (rawCmd.equals("scale")) {
        if (parts.size() < 3) return "Error: scale <name> <val> (or x y z)";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        if (parts.size() == 3) {
          float s = float(parts.get(2));
          e.transform.scale.set(s, s, s);
        } else if (parts.size() >= 5) {
          e.transform.scale.set(float(parts.get(2)), float(parts.get(3)), float(parts.get(4)));
        }
        return "SUCCESS: Scaled " + e.name;
      }
      else if (rawCmd.equals("metallic") || rawCmd.equals("metal")) {
        if (parts.size() < 3) return "Error: metal <name> <val>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.material.metallic = float(parts.get(2));
        return "SUCCESS: Set metallic of " + e.name + " to " + e.material.metallic;
      }
      else if (rawCmd.equals("roughness") || rawCmd.equals("rough")) {
        if (parts.size() < 3) return "Error: rough <name> <val>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.material.roughness = float(parts.get(2));
        return "SUCCESS: Set roughness of " + e.name + " to " + e.material.roughness;
      }
      else if (rawCmd.equals("intensity")) {
        if (parts.size() < 3) return "Error: intensity <name> <val>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.lightIntensity = float(parts.get(2));
        return "SUCCESS: Set intensity of " + e.name + " to " + e.lightIntensity;
      }
      else if (rawCmd.equals("range")) {
        if (parts.size() < 3) return "Error: range <name> <val>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.lightRange = float(parts.get(2));
        return "SUCCESS: Set range of " + e.name + " to " + e.lightRange;
      }
      else if (rawCmd.equals("visible") || rawCmd.equals("hide")) {
        if (parts.size() < 2) return "Error: visible <name> [0|1]";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        if (parts.size() >= 3) {
          e.visible = parts.get(2).equals("1") || parts.get(2).equalsIgnoreCase("true");
        } else {
          e.visible = !e.visible;
        }
        return "SUCCESS: " + e.name + " visibility is now " + e.visible;
      }
      else if (rawCmd.equals("delete") || rawCmd.equals("remove")) {
        if (parts.size() < 2) return "Error: delete <name>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        scene.entities.remove(e);
        return "SUCCESS: Deleted " + e.name;
      }
      else if (rawCmd.equals("create") || rawCmd.equals("add") || rawCmd.equals("spawn")) {
        if (parts.size() < 2) return "Error: create <type> [name] [x] [y] [z]";
        String type = parts.get(1).toLowerCase();
        String name = (parts.size() >= 3) ? parts.get(2) : "";
        float x = (parts.size() >= 4) ? float(parts.get(3)) : 0;
        float y = (parts.size() >= 5) ? float(parts.get(4)) : 0;
        float z = (parts.size() >= 6) ? float(parts.get(5)) : 0;
        
        Entity e = null;
        if (type.equals("cube")) e = scene.addEntity(name.isEmpty()?"Cube":name, "Cube");
        else if (type.equals("sphere")) e = scene.addEntity(name.isEmpty()?"Sphere":name, "Sphere");
        else if (type.equals("plane")) e = scene.addEntity(name.isEmpty()?"Plane":name, "Plane");
        else if (type.equals("light") || type.equals("pointlight")) { 
          int existingLights = 0;
          for (Entity el : scene.entities) if (el.type.equals("PointLight")) existingLights++;
          if (existingLights >= 5) return "Error: Maximum 5 point lights reached";
          e = scene.addEntity(name.isEmpty()?"Light":name, "PointLight"); 
        } else {
          return "Error: Unknown type: " + type;
        }
        
        if (e != null && parts.size() >= 4) {
          e.transform.position.set(x, y, z);
        }
        return "SUCCESS: Created " + (e!=null?e.name:type) + " at (" + x + "," + y + "," + z + ")";
      }
      else if (rawCmd.equals("rename") || rawCmd.equals("name")) {
        if (parts.size() < 3) return "Error: rename <oldName> <newName>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.name = parts.get(2);
        return "SUCCESS: Renamed '" + parts.get(1) + "' to '" + parts.get(2) + "'";
      }
      else if (rawCmd.equals("alias")) {
        if (parts.size() == 1) {
          if (aliases.isEmpty()) return "No aliases registered.";
          StringBuilder sb = new StringBuilder("Registered Aliases:\n");
          for (String key : aliases.keySet()) sb.append("  ").append(key).append(" -> ").append(aliases.get(key)).append("\n");
          return sb.toString();
        }
        if (parts.size() < 3) return "Error: alias <shorthand> <full_command>";
        String aliasName = parts.get(1).toLowerCase();
        // Join remaining parts for the expansion
        StringBuilder expansion = new StringBuilder();
        for (int i=2; i<parts.size(); i++) expansion.append(parts.get(i)).append(i == parts.size()-1 ? "" : " ");
        aliases.put(aliasName, expansion.toString());
        return "SUCCESS: Registered alias '" + aliasName + "'";
      }
      else if (rawCmd.equals("unalias")) {
        if (parts.size() < 2) return "Error: unalias <shorthand>";
        aliases.remove(parts.get(1).toLowerCase());
        return "SUCCESS: Removed alias '" + parts.get(1) + "'";
      }
      else if (rawCmd.equals("clear") || rawCmd.equals("deleteall")) {
        scene.entities.clear();
        scene.selectedEntities.clear();
        scene.nextEntityId = 1;
        return "SUCCESS: Cleared entire scene";
      }
      else if (rawCmd.equals("run")) {
        if (parts.size() < 2) return "Error: run <filename.p3des>";
        String filename = parts.get(1);
        if (!filename.endsWith(".p3des")) filename += ".p3des";
        String[] lines = p3deditor.this.loadStrings(filename);
        if (lines == null) return "Error: Script not found: " + filename;
        if (scriptManager != null) {
          scriptManager.runScript(filename, String.join("\n", lines), null); // No context for manual run
          return "SUCCESS: Started logic-script " + filename;
        }
        return "Error: ScriptManager not initialized";
      }
      else if (rawCmd.equals("stop")) {
        if (scriptManager != null) {
          scriptManager.stopAll();
          if (scene.isPlaying()) {
            scene.engineMode = SceneManager.MODE_EDIT;
            scene.restoreSnapshot();
            scene.lastHoveredEntity = null; // Clear hover state
            return "SUCCESS: Stopped Mode & Restored Scene";
          }
          return "SUCCESS: Stopped all scripts";
        }
        return "Error: ScriptManager not initialized";
      }
      else if (rawCmd.equals("play") || rawCmd.equals("start")) {
        if (scene.isPlaying()) return "Already in Play Mode";
        
        // v2.0: Support "play simulate" vs "play game" (default to simulate for developer safety)
        int targetMode = SceneManager.MODE_SIMULATE;
        if (parts.size() >= 2) {
          if (parts.get(1).equalsIgnoreCase("game")) targetMode = SceneManager.MODE_GAME;
          else if (parts.get(1).equalsIgnoreCase("simulate")) targetMode = SceneManager.MODE_SIMULATE;
        }
        
        scene.saveSnapshot();
        scene.engineMode = targetMode;
        scene.clearSelection();
        
        // v2.4 Level Blueprint Auto-compile & Start
        if (scene.levelBlueprint != null && scene.levelBlueprint.nodes.size() > 0) {
          scene.levelBlueprint.compileAllEvents();
          scene.triggerEvent(null, "Start");
        }
        
        // v1.3: Auto-compile all entity blueprints (all event types)
        for (Entity e : scene.entities) {
          if (e.blueprint != null && e.blueprint.nodes.size() > 0) {
            e.blueprint.compileAllEvents();
          }
        }
        for (Entity e : scene.entities) {
          scene.triggerEvent(e, "Start");
        }
        return "SUCCESS: Entered " + (targetMode == SceneManager.MODE_GAME ? "GAME" : "SIMULATE") + " Mode";
      }
      else if (rawCmd.equals("mount")) {
        if (parts.size() < 4) return "Error: mount <entity> <event> <script>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.mount(parts.get(2), parts.get(3));
        return "SUCCESS: Mounted " + parts.get(3) + " to " + parts.get(1) + ":" + parts.get(2);
      }
      else if (rawCmd.equals("unmount")) {
        if (parts.size() < 3) return "Error: unmount <entity> <event>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.eventHandlers.remove(parts.get(2));
        return "SUCCESS: Unmounted events from " + parts.get(1) + ":" + parts.get(2);
      }
      else if (rawCmd.equals("exec") || rawCmd.equals("script")) {
        if (parts.size() < 2) return "Error: exec <filename>";
        return executeScript(parts.get(1));
      }
      else if (rawCmd.equals("echo") || rawCmd.equals("print") || rawCmd.equals("say")) {
        StringBuilder sb = new StringBuilder();
        for (int i=1; i<parts.size(); i++) sb.append(parts.get(i)).append(i == parts.size()-1 ? "" : " ");
        return sb.toString();
      }
      else if (rawCmd.equals("osc_connect")) {
        if (parts.size() < 3) return "Error: osc_connect <ip> <port>";
        try {
          int port = Integer.parseInt(parts.get(2));
          p3deditor.this.oscClient.connect(parts.get(1), port);
          return "SUCCESS: Connected OSC to " + parts.get(1) + ":" + port;
        } catch (Exception e) {
          return "Error: Invalid port";
        }
      }
      else if (rawCmd.equals("osc_send")) {
        if (parts.size() < 2) return "Error: osc_send <address> [args...]";
        if (!p3deditor.this.oscClient.isConnected) return "Error: OSC not connected";
        
        OSCMessage msg = new OSCMessage(parts.get(1));
        for (int i=2; i<parts.size(); i++) {
          String arg = parts.get(i);
          try {
            if (arg.contains(".")) msg.addFloat(Float.parseFloat(arg));
            else msg.addInt(Integer.parseInt(arg));
          } catch (Exception e) {
            msg.addString(arg);
          }
        }
        p3deditor.this.oscClient.send(msg);
        return "SUCCESS: Sent OSC Message to " + parts.get(1);
      }
      else if (rawCmd.equals("osc_telemetry")) {
        if (parts.size() < 2) return "Error: osc_telemetry <on|off>";
        p3deditor.this.oscTelemetryEnabled = parts.get(1).equalsIgnoreCase("on");
        return "SUCCESS: OSC Telemetry is now " + (p3deditor.this.oscTelemetryEnabled ? "ON" : "OFF");
      }
      else if (rawCmd.equals("load_obj")) {
        if (parts.size() < 3) return "Error: load_obj <name> <path>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.model = p3deditor.this.loadShape(parts.get(2));
        e.type = "Model";
        return "SUCCESS: Loaded model into " + e.name;
      }
      else if (rawCmd.equals("load_env")) {
        if (parts.size() < 2) return "Error: load_env <path>";
        scene.envMap = p3deditor.this.loadImage(parts.get(1));
        return "SUCCESS: Loaded Global Environment Map: " + parts.get(1);
      }
      else if (rawCmd.equals("load_albedo")) {
        if (parts.size() < 3) return "Error: load_albedo <name> <path>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.material.setAlbedoMap(p3deditor.this.loadImage(parts.get(2)));
        return "SUCCESS: Loaded Albedo Map into " + e.name;
      }
      else if (rawCmd.equals("load_metal")) {
        if (parts.size() < 3) return "Error: load_metal <name> <path>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.material.setMetallicMap(p3deditor.this.loadImage(parts.get(2)));
        return "SUCCESS: Loaded Metallic Map into " + e.name;
      }
      else if (rawCmd.equals("load_rough")) {
        if (parts.size() < 3) return "Error: load_rough <name> <path>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.material.setRoughnessMap(p3deditor.this.loadImage(parts.get(2)));
        return "SUCCESS: Loaded Roughness Map into " + e.name;
      }
      else if (rawCmd.equals("cam_tp")) {
        if (parts.size() < 4) return "Error: cam_tp <x> <y> <z>";
        float tx = Float.parseFloat(parts.get(1));
        float ty = Float.parseFloat(parts.get(2));
        float tz = Float.parseFloat(parts.get(3));
        p3deditor.this.editorCamera.pos.set(tx, ty, tz);
        return "SUCCESS: Teleported camera to " + tx + " " + ty + " " + tz;
      }
      else if (rawCmd.equals("bg")) {
        if (parts.size() < 4) return "Error: bg <r> <g> <b>";
        int r = (int)Float.parseFloat(parts.get(1));
        int g = (int)Float.parseFloat(parts.get(2));
        int b = (int)Float.parseFloat(parts.get(3));
        scene.backgroundColor = p3deditor.this.color(r, g, b);
        return "SUCCESS: Set background color to RGB(" + r + "," + g + "," + b + ")";
      }
      else if (rawCmd.equals("help")) {
        return "CMDS: move, tp, color, scale, delete, rename, clear, create, metal, rough, load_obj, load_env, load_albedo, mount, osc_connect, play, cam_tp, bg, help";
      }
    } catch (Exception ex) {
      return "Error: " + ex.getMessage();
    }
    
    return "Unknown command: " + rawCmd;
  }
  
  String executeScript(String filename) {
    if (!filename.toLowerCase().endsWith(".p3dec")) filename += ".p3dec";
    File f = new File(p3deditor.this.sketchPath(filename));
    if (!f.exists()) return "Error: Script not found: " + f.getAbsolutePath();
    
    String[] lines = p3deditor.this.loadStrings(f.getAbsolutePath());
    if (lines == null) return "Error: Could not read " + filename;
    
    int count = 0;
    for (String l : lines) {
      String trimmed = l.trim();
      if (!trimmed.isEmpty() && !trimmed.startsWith("#") && !trimmed.startsWith("//")) {
        execute(trimmed);
        count++;
      }
    }
    return "SUCCESS: Executed " + count + " instructions from " + filename;
  }
  
  ArrayList<String> parseArgs(String line) {
    ArrayList<String> args = new ArrayList<String>();
    boolean inQuotes = false;
    StringBuilder currentArg = new StringBuilder();
    for (int i = 0; i < line.length(); i++) {
        char c = line.charAt(i);
        if (c == '\"') {
            inQuotes = !inQuotes;
            // DO NOT append the quote character itself
        } else if (c == ' ' && !inQuotes) {
            if (currentArg.length() > 0) {
                args.add(currentArg.toString());
                currentArg.setLength(0);
            }
        } else {
            currentArg.append(c);
        }
    }
    if (currentArg.length() > 0) {
        args.add(currentArg.toString());
    }
    return args;
  }
  
  Entity findEntity(String nameOrId) {
    // Search backwards to prioritize the NEWEST entity if multiple share a name
    for (int i = scene.entities.size() - 1; i >= 0; i--) {
      Entity e = scene.entities.get(i);
      if (e.name.equalsIgnoreCase(nameOrId)) return e;
      if (str(e.id).equals(nameOrId)) return e;
    }
    return null;
  }
}
