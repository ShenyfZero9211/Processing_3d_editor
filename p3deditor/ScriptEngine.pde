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
      ArrayList<String> parts = p3deditor.this.interpreter.parseArgs(line);
      if (parts.size() == 0) continue;
      String cmd = parts.get(0).toLowerCase();
      
      if (cmd.equals("if")) {
        if (parts.size() < 4) continue;
        boolean condition = evaluateCondition(parts.get(1), parts.get(2), parts.get(3));
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
        if (parts.size() < 4) continue;
        loopStack.push(pc - 1); // Record the WHILE line
        boolean condition = evaluateCondition(parts.get(1), parts.get(2), parts.get(3));
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
        if (parts.size() < 5) continue;
        String vName = parts.get(1);
        float startV = Float.parseFloat(parts.get(2));
        float endV = Float.parseFloat(parts.get(3));
        float stepV = Float.parseFloat(parts.get(4));
        
        if (!variables.containsKey(vName)) {
           variables.put(vName, startV);
           p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
        }
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
          ArrayList<String> fParts = p3deditor.this.interpreter.parseArgs(forLine);
          String vName = fParts.get(1);
          float stepV = Float.parseFloat(fParts.get(4));
          variables.put(vName, variables.get(vName) + stepV);
          p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
          pc = forPc; // Jump back to FOR line for condition check
        }
      } else if (cmd.equals("wait")) {
        if (parts.size() > 1) {
          waitUntil = p3deditor.this.millis() + Integer.parseInt(parts.get(1));
          return;
        }
      } else if (cmd.equals("eval")) {
        // v1.7: Advanced Math Expression Evaluator
        if (parts.size() >= 3) {
           String targetVar = parts.get(1);
           // Reconstruct the expression (it might contain spaces)
           StringBuilder exprBuilder = new StringBuilder();
           for (int i = 2; i < parts.size(); i++) {
             exprBuilder.append(parts.get(i)).append(" ");
           }
           String expr = exprBuilder.toString().trim();
           try {
             double result = evalExpression(expr);
             variables.put(targetVar, (float)result);
             p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
           } catch (Exception e) {
             p3deditor.this.ui.debugConsole.addLog("Eval Error: " + e.getMessage(), 3);
           }
        }
      } else if (cmd.equals("gettime")) {
        if (parts.size() >= 2) {
          variables.put(parts.get(1), (float)p3deditor.this.millis());
        }
      } else if (cmd.equals("getvisible")) {
        if (parts.size() >= 3) {
           Entity e = p3deditor.this.interpreter.findEntity(parts.get(1));
           if (e != null) {
             variables.put(parts.get(2), e.visible ? 1.0f : 0.0f);
             p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
           }
        }
      } else if (cmd.equals("goto")) {
        if (parts.size() > 1) {
          String lab = parts.get(1).toLowerCase();
          if (labels.containsKey(lab)) pc = labels.get(lab);
        }
      } else if (cmd.equals("set")) {
        if (parts.size() == 3) {
          variables.put(parts.get(1), Float.parseFloat(parts.get(2)));
          p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
        } else if (parts.size() >= 5) {
          // v1.4: Advanced set with arithmetic: set var a op b
          float a = Float.parseFloat(parts.get(2));
          String op = parts.get(3);
          float b = Float.parseFloat(parts.get(4));
          float res = 0;
          if (op.equals("+")) res = a + b;
          else if (op.equals("-")) res = a - b;
          else if (op.equals("*")) res = a * b;
          else if (op.equals("/")) res = (b != 0) ? a / b : 0;
          else if (op.equals("&")) res = (a > 0 && b > 0) ? 1 : 0;
          else if (op.equals("|")) res = (a > 0 || b > 0) ? 1 : 0;
          variables.put(parts.get(1), res);
          p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
        }
      } else if (cmd.equals("getpos")) {
        if (parts.size() >= 5) {
          String eName = parts.get(1);
          Entity e = p3deditor.this.interpreter.findEntity(eName);
          if (e != null) {
            variables.put(parts.get(2), e.transform.position.x);
            variables.put(parts.get(3), e.transform.position.y);
            variables.put(parts.get(4), e.transform.position.z);
            p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
          } else {
            p3deditor.this.ui.debugConsole.addLog("Error: getpos target entity not found: " + eName, 3);
          }
        }
      } else if (cmd.equals("add") || cmd.equals("sub") || cmd.equals("mul") || cmd.equals("div")) {
         if (parts.size() > 2) {
           float cur = variables.getOrDefault(parts.get(1), 0f);
           float val = Float.parseFloat(parts.get(2));
           if (cmd.equals("add")) cur += val;
           if (cmd.equals("sub")) cur -= val;
           if (cmd.equals("mul")) cur *= val;
           if (cmd.equals("div") && val != 0) cur /= val;
           variables.put(parts.get(1), cur);
           p3deditor.this.scriptManager.syncDebugVars(contextEntity, variables);
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
  
  // v1.7: Recursive Descent Parser for Math Expressions
  double evalExpression(final String str) {
    return new Object() {
        int pos = -1, ch;
        void nextChar() { ch = (++pos < str.length()) ? str.charAt(pos) : -1; }
        boolean eat(int charToEat) {
            while (ch == ' ') nextChar();
            if (ch == charToEat) { nextChar(); return true; }
            return false;
        }
        double parse() {
            nextChar();
            double x = parseExpression();
            if (pos < str.length()) throw new RuntimeException("Unexpected: " + (char)ch);
            return x;
        }
        double parseExpression() {
            double x = parseTerm();
            for (;;) {
                if      (eat('+')) x += parseTerm();
                else if (eat('-')) x -= parseTerm();
                else return x;
            }
        }
        double parseTerm() {
            double x = parseFactor();
            for (;;) {
                if      (eat('*')) x *= parseFactor();
                else if (eat('/')) x /= parseFactor();
                else return x;
            }
        }
        double parseFactor() {
            if (eat('+')) return parseFactor();
            if (eat('-')) return -parseFactor();
            double x;
            int startPos = this.pos;
            if (eat('(')) {
                x = parseExpression();
                eat(')');
            } else if ((ch >= '0' && ch <= '9') || ch == '.') {
                while ((ch >= '0' && ch <= '9') || ch == '.') nextChar();
                x = Double.parseDouble(str.substring(startPos, this.pos));
            } else if (ch >= 'a' && ch <= 'z') {
                while (ch >= 'a' && ch <= 'z') nextChar();
                String func = str.substring(startPos, this.pos);
                
                // v1.8: Built-in Constants (Standardized names)
                if (func.equals("time") || func.equals("t")) x = (double)(p3deditor.this.millis() / 1000.0f);
                else if (func.equals("millis") || func.equals("ms")) x = (double)p3deditor.this.millis();
                else if (func.equals("dt")) x = (double)(1.0f / p3deditor.this.frameRate);
                else {
                  x = parseFactor();
                  if (func.equals("sqrt")) x = Math.sqrt(x);
                  else if (func.equals("sin")) x = Math.sin(x);
                  else if (func.equals("cos")) x = Math.cos(x);
                  else if (func.equals("tan")) x = Math.tan(x);
                  else if (func.equals("abs")) x = Math.abs(x);
                  else if (func.equals("rand")) x = Math.random() * x;
                  else throw new RuntimeException("Unknown function: " + func);
                }
            } else {
                throw new RuntimeException("Unexpected expression character: " + (char)ch);
            }
            if (eat('^')) x = Math.pow(x, parseFactor());
            return x;
        }
    }.parse();
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
      
      // v0.6.0: Local Properties mapping
      if (text.contains("$px")) text = text.replace("$px", String.valueOf(contextEntity.transform.position.x));
      if (text.contains("$py")) text = text.replace("$py", String.valueOf(contextEntity.transform.position.y));
      if (text.contains("$pz")) text = text.replace("$pz", String.valueOf(contextEntity.transform.position.z));
      if (text.contains("$rx")) text = text.replace("$rx", String.valueOf(contextEntity.transform.rotation.x));
      if (text.contains("$ry")) text = text.replace("$ry", String.valueOf(contextEntity.transform.rotation.y));
      if (text.contains("$rz")) text = text.replace("$rz", String.valueOf(contextEntity.transform.rotation.z));
      if (text.contains("$sx")) text = text.replace("$sx", String.valueOf(contextEntity.transform.scale.x));
      if (text.contains("$sy")) text = text.replace("$sy", String.valueOf(contextEntity.transform.scale.y));
      if (text.contains("$sz")) text = text.replace("$sz", String.valueOf(contextEntity.transform.scale.z));
      if (text.contains("$dt")) text = text.replace("$dt", String.valueOf(1.0f/p3deditor.this.frameRate));
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
    
    // v1.4: If any unreplaced $variables remain, and they look like VLB script variables, replace with 0
    // This prevents crashes for things like counters or uninitialized math nodes.
    if (text.contains("$")) {
      // Regex to find things like $pos_x_1, $add_2, etc. (words starting with $ and having underscores/numbers)
      // For simplicity, we'll just replace anything that looks like a variable reference that's still there
      text = text.replaceAll("\\$[a-zA-Z_][a-zA-Z0-9_]*", "0");
    }
    
    return text;
  }
}

class ScriptManager {
  ArrayList<ScriptContext> activeScripts = new ArrayList<ScriptContext>();
  CommandInterpreter interpreter;
  
  // v1.8: Cache variables per entity for debugging and UI persistence
  HashMap<Entity, HashMap<String, Float>> debugVariables = new HashMap<Entity, HashMap<String, Float>>();
  
  ScriptManager(CommandInterpreter interpreter) {
    this.interpreter = interpreter;
  }
  
  void syncDebugVars(Entity e, Map<String, Float> vars) {
    if (e == null) return;
    if (!debugVariables.containsKey(e)) debugVariables.put(e, new HashMap<String, Float>());
    debugVariables.get(e).putAll(vars);
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
  
  // v1.8: Force stop scripts for a specific entity (for hot-reload)
  void stopScriptEntity(Entity e) {
    for (int i = activeScripts.size() - 1; i >= 0; i--) {
      if (activeScripts.get(i).contextEntity == e) {
        activeScripts.remove(i);
      }
    }
  }
  
  boolean isEntityExecuting(Entity e, String scriptTitle) {
     for (ScriptContext sc : activeScripts) {
       if (sc.contextEntity == e && sc.scriptName.equals(scriptTitle)) return true;
     }
     return false;
  }
  
  // v1.8: Get live variable value for debugging
  float getVariableValue(Entity e, String varName) {
    // Check with and without $ prefix
    String cleanName = varName.startsWith("$") ? varName.substring(1) : varName;
    // Check cache first for persistence even after script ends
    if (debugVariables.containsKey(e)) {
      HashMap<String, Float> vars = debugVariables.get(e);
      if (vars.containsKey(cleanName)) return vars.get(cleanName);
    }
    
    // Fallback to active scripts
    for (ScriptContext sc : activeScripts) {
      if (sc.contextEntity == e) {
        if (sc.variables.containsKey(cleanName)) return sc.variables.get(cleanName);
      }
    }
    return Float.NaN; // Indicate not found
  }
}
