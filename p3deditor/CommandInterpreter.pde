class CommandInterpreter {
  SceneManager scene;
  String lastResult = "";
  
  CommandInterpreter(SceneManager s) {
    this.scene = s;
  }
  
  String execute(String cmdLine) {
    if (cmdLine == null || cmdLine.trim().isEmpty()) return "";
    
    // Simple command splitter that respects quotes for names with spaces
    // e.g. move "Cube 1" 10 0 0
    ArrayList<String> parts = parseArgs(cmdLine);
    if (parts.size() == 0) return "";
    
    String cmd = parts.get(0).toLowerCase();
    
    try {
      if (cmd.equals("move") || cmd.equals("translate")) {
        if (parts.size() < 5) return "Error: move <name> <x> <y> <z>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        float dx = float(parts.get(2));
        float dy = float(parts.get(3));
        float dz = float(parts.get(4));
        e.transform.position.add(dx, dy, dz);
        return "SUCCESS: Moved " + e.name;
      } 
      else if (cmd.equals("tp") || cmd.equals("set_pos")) {
        if (parts.size() < 5) return "Error: tp <name> <x> <y> <z>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.transform.position.set(float(parts.get(2)), float(parts.get(3)), float(parts.get(4)));
        return "SUCCESS: Teleported " + e.name;
      }
      else if (cmd.equals("color") || cmd.equals("set_color")) {
        if (parts.size() < 3) return "Error: color <name> <hex>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        String hexStr = parts.get(2).replace("#", "");
        if (hexStr.length() == 6) {
          e.col = (int)Long.parseLong("FF" + hexStr, 16);
          return "SUCCESS: Colored " + e.name;
        }
        return "Error: Invalid hex format";
      }
      else if (cmd.equals("scale")) {
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
      else if (cmd.equals("delete") || cmd.equals("remove")) {
        if (parts.size() < 2) return "Error: delete <name>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        scene.entities.remove(e);
        return "SUCCESS: Deleted " + e.name;
      }
      else if (cmd.equals("help")) {
        return "CMDS: move, tp, color, scale, delete, help";
      }
    } catch (Exception ex) {
      return "Error: " + ex.getMessage();
    }
    
    return "Unknown command: " + cmd;
  }
  
  ArrayList<String> parseArgs(String line) {
    ArrayList<String> args = new ArrayList<String>();
    boolean inQuotes = false;
    StringBuilder currentArg = new StringBuilder();
    for (int i = 0; i < line.length(); i++) {
        char c = line.charAt(i);
        if (c == '\"') {
            inQuotes = !inQuotes;
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
    for (Entity e : scene.entities) {
      if (e.name.equalsIgnoreCase(nameOrId)) return e;
      if (str(e.id).equals(nameOrId)) return e;
    }
    return null;
  }
}
