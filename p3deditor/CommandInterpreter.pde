import java.util.Map;
import java.util.HashMap;

class CommandInterpreter {
  SceneManager scene;
  String lastResult = "";
  HashMap<String, String> aliases = new HashMap<String, String>();
  int recursionDepth = 0;
  final int MAX_RECURSION = 10;
  
  CommandInterpreter(SceneManager s) {
    this.scene = s;
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
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        e.transform.position.set(float(parts.get(2)), float(parts.get(3)), float(parts.get(4)));
        return "SUCCESS: Teleported " + e.name;
      }
      else if (rawCmd.equals("color") || rawCmd.equals("set_color")) {
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
      else if (rawCmd.equals("delete") || rawCmd.equals("remove")) {
        if (parts.size() < 2) return "Error: delete <name>";
        Entity e = findEntity(parts.get(1));
        if (e == null) return "Error: Entity not found: " + parts.get(1);
        scene.entities.remove(e);
        return "SUCCESS: Deleted " + e.name;
      }
      else if (rawCmd.equals("create") || rawCmd.equals("add")) {
        if (parts.size() < 2) return "Error: create <type> (Cube, Sphere, Plane, Light)";
        String type = parts.get(1).toLowerCase();
        if (type.equals("cube")) { scene.addEntity("Cube", "Cube"); }
        else if (type.equals("sphere")) { scene.addEntity("Sphere", "Sphere"); }
        else if (type.equals("plane")) { scene.addEntity("Plane", "Plane"); }
        else if (type.equals("light") || type.equals("pointlight")) { scene.addEntity("Point Light", "PointLight"); }
        else return "Error: Unknown type: " + type;
        return "SUCCESS: Created " + type;
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
      else if (rawCmd.equals("exec") || rawCmd.equals("run")) {
        if (parts.size() < 2) return "Error: exec <filename>";
        return executeScript(parts.get(1));
      }
      else if (rawCmd.equals("help")) {
        return "CMDS: move, tp, color, scale, delete, alias, unalias, exec, help";
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
