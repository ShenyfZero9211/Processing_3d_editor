import java.util.*;

/**
 * P3DE Logic-Script (P3DES) Engine
 * Supports multi-threaded, frame-by-frame script execution with wait, goto, and variables.
 */

class ScriptContext {
  String scriptName;
  String[] lines;
  int pc = 0; // Program Counter
  
  HashMap<String, Float> variables = new HashMap<String, Float>();
  HashMap<String, Integer> labels = new HashMap<String, Integer>();
  Stack<Integer> loopStack = new Stack<Integer>();
  
  long waitUntil = 0;
  boolean terminated = false;
  Entity contextEntity = null; // v0.5.0: The entity this script is mounted on
  
  ScriptContext(String name, String[] rawLines, Entity context) {
    this.scriptName = name;
    this.lines = rawLines;
    this.contextEntity = context;
    preScanLabels();
  }
  
  void preScanLabels() {
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.startsWith(":")) {
        labels.put(line.substring(1).toLowerCase(), i);
      }
    }
  }
  
  void update(CommandInterpreter interpreter) {
    if (terminated || pc >= lines.length) {
      terminated = true;
      return;
    }
    
    if (p3deditor.this.millis() < waitUntil) return;
    
    // Process one or more lines per frame until a WAIT or script end
    // To prevent infinite loops, we cap executions per frame
    int burstCap = 100; 
    while (pc < lines.length && p3deditor.this.millis() >= waitUntil && burstCap > 0) {
      String rawLine = lines[pc].trim();
      String line = substituteVariables(rawLine);
      pc++;
      burstCap--;
      
      if (line.isEmpty() || line.startsWith("#") || line.startsWith(":")) continue;
      
      // Logic Commands
      String[] parts = line.split("\\s+");
      if (parts.length == 0) continue;
      String cmd = parts[0].toLowerCase();
      
      if (cmd.equals("if")) {
        if (parts.length < 4) continue;
        boolean condition = evaluateCondition(parts[1], parts[2], parts[3]);
        if (!condition) {
          int depth = 1;
          while (pc < lines.length && depth > 0) {
            String l = lines[pc].trim().toLowerCase();
            if (l.startsWith("if")) depth++;
            if (l.startsWith("endif")) depth--;
            if (depth == 1 && l.startsWith("else")) { pc++; break; } 
            pc++;
          }
        }
      } else if (cmd.equals("else")) {
        int depth = 1;
        while (pc < lines.length && depth > 0) {
          String l = lines[pc].trim().toLowerCase();
          if (l.startsWith("if")) depth++;
          if (l.startsWith("endif")) depth--;
          pc++;
        }
      } else if (cmd.equals("endif")) {
        // Just a marker
      } else if (cmd.equals("while")) {
        if (parts.length < 4) continue;
        loopStack.push(pc - 1); // Record the WHILE line
        boolean condition = evaluateCondition(parts[1], parts[2], parts[3]);
        if (!condition) {
          loopStack.pop();
          int depth = 1;
          while (pc < lines.length && depth > 0) {
            String l = lines[pc].trim().toLowerCase();
            if (l.startsWith("while")) depth++;
            if (l.startsWith("endwhile")) depth--;
            pc++;
          }
        }
      } else if (cmd.equals("endwhile")) {
        if (!loopStack.isEmpty()) {
          pc = loopStack.pop(); // Jump back to WHILE line
        }
      } else if (cmd.equals("for")) {
        if (parts.length < 5) continue;
        String vName = parts[1];
        float startV = Float.parseFloat(parts[2]);
        float endV = Float.parseFloat(parts[3]);
        float stepV = Float.parseFloat(parts[4]);
        
        if (!variables.containsKey(vName)) variables.put(vName, startV);
        float curV = variables.get(vName);
        
        loopStack.push(pc - 1);
        if ((stepV > 0 && curV >= endV) || (stepV < 0 && curV <= endV)) {
          loopStack.pop();
          variables.remove(vName); // Cleanup
          int depth = 1;
          while (pc < lines.length && depth > 0) {
            String l = lines[pc].trim().toLowerCase();
            if (l.startsWith("for")) depth++;
            if (l.startsWith("endfor")) depth--;
            pc++;
          }
        }
      } else if (cmd.equals("endfor")) {
        if (!loopStack.isEmpty()) {
          int forPc = loopStack.pop();
          String forLine = substituteVariables(lines[forPc].trim());
          String[] fParts = forLine.split("\\s+");
          String vName = fParts[1];
          float stepV = Float.parseFloat(fParts[4]);
          variables.put(vName, variables.get(vName) + stepV);
          pc = forPc; // Jump back to FOR line for condition check
        }
      } else if (cmd.equals("wait")) {
        if (parts.length > 1) {
          waitUntil = p3deditor.this.millis() + (long)Float.parseFloat(parts[1]);
          return;
        }
      } else if (cmd.equals("goto")) {
        if (parts.length > 1) {
          String lab = parts[1].toLowerCase();
          if (labels.containsKey(lab)) pc = labels.get(lab);
        }
      } else if (cmd.equals("set")) {
        if (parts.length > 2) {
          variables.put(parts[1], Float.parseFloat(parts[2]));
        }
      } else if (cmd.equals("add") || cmd.equals("sub") || cmd.equals("mul") || cmd.equals("div")) {
         if (parts.length > 2) {
           float cur = variables.getOrDefault(parts[1], 0f);
           float val = Float.parseFloat(parts[2]);
           if (cmd.equals("add")) cur += val;
           if (cmd.equals("sub")) cur -= val;
           if (cmd.equals("mul")) cur *= val;
           if (cmd.equals("div") && val != 0) cur /= val;
           variables.put(parts[1], cur);
         }
      } else {
        try {
          String result = interpreter.execute(line);
          if (result.startsWith("Error")) {
            terminated = true;
            p3deditor.this.ui.debugConsole.addLog("Script Terminated: " + result, 3);
          } else if (line.trim().toLowerCase().startsWith("echo") || line.trim().toLowerCase().startsWith("print")) {
            // Explicitly show echo messages in the terminal
            p3deditor.this.ui.debugConsole.addLog(result, 1);
          }
        } catch (Exception e) {
          terminated = true;
          p3deditor.this.ui.debugConsole.addLog("Script Crash: " + e.getMessage(), 3);
        }
      }
    }
  }
  
  boolean evaluateCondition(String left, String op, String right) {
    try {
      float l = Float.parseFloat(left);
      float r = Float.parseFloat(right);
      if (op.equals("==")) return l == r;
      if (op.equals("!=")) return l != r;
      if (op.equals(">")) return l > r;
      if (op.equals("<")) return l < r;
      if (op.equals(">=")) return l >= r;
      if (op.equals("<=")) return l <= r;
    } catch (Exception e) {}
    return false;
  }
  
  String substituteVariables(String text) {
    // v0.5.0: Handle $this context
    if (contextEntity != null) {
      String ename = contextEntity.name;
      // If the entity name contains spaces, wrap it in quotes so parseArgs treats it as one token
      if (ename.contains(" ")) {
        ename = "\"" + ename + "\"";
      }
      text = text.replace("$this", ename);
    }
    
    if (!text.contains("$")) return text;
    // Sort keys by length descending to prevent partial matches ($xPos vs $x)
    String[] keys = variables.keySet().toArray(new String[0]);
    Arrays.sort(keys, (a, b) -> Integer.compare(b.length(), a.length()));
    
    for (String key : keys) {
      float val = variables.get(key);
      String valStr = (val == (long)val) ? String.valueOf((long)val) : String.valueOf(val);
      text = text.replace("$" + key, valStr);
    }
    return text;
  }
}

class ScriptManager {
  ArrayList<ScriptContext> activeScripts = new ArrayList<ScriptContext>();
  CommandInterpreter interpreter;
  
  ScriptManager(CommandInterpreter interpreter) {
    this.interpreter = interpreter;
  }
  
  void runScript(String name, String content, Entity context) {
    String[] lines = content.split("\\r?\\n");
    activeScripts.add(new ScriptContext(name, lines, context));
    System.out.println("P3DES: Started script " + name + (context != null ? " on " + context.name : ""));
  }
  
  void update() {
    for (int i = activeScripts.size() - 1; i >= 0; i--) {
      ScriptContext ctx = activeScripts.get(i);
      ctx.update(interpreter);
      if (ctx.terminated) {
        activeScripts.remove(i);
        System.out.println("P3DES: Finished script " + ctx.scriptName);
      }
    }
  }
  
  void stopAll() {
    activeScripts.clear();
  }
  
  boolean isEntityExecuting(Entity e, String scriptTitle) {
     for (ScriptContext sc : activeScripts) {
       if (sc.contextEntity == e && sc.scriptName.equals(scriptTitle)) return true;
     }
     return false;
  }
}
