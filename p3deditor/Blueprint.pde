/**
 * Blueprint.pde - Visual Logic Container
 * 
 * Version: v0.4.9
 * Responsibilities:
 * - Manages a graph of VLB nodes and connections for an entity or level.
 * - Implements the transpilation engine that converts visual nodes into PDES 
 *   assembly script.
 * - Handles event-specific PDES generation (OnStart, OnUpdate, etc.).
 * - Manages node spatial organization (Offset/Zoom).
 */
class Blueprint {
  Object owner; // Can be Entity or SceneManager
  ArrayList<VLBNode> nodes = new ArrayList<VLBNode>();
  ArrayList<VLBConnection> connections = new ArrayList<VLBConnection>();
  
  float offsetX = 0, offsetY = 0;
  float zoom = 1.0;
  
  Blueprint(Object owner) {
    this.owner = owner;
    
    // Default Starting Nodes
    VLBNode start = new VLBNode(0, "Event: OnStart", "Event", 300, 200);
    start.addPin("Out", false, true, "flow");
    nodes.add(start);
    
    VLBNode update = new VLBNode(1, "Event: OnUpdate", "Event", 300, 350);
    update.addPin("Out", false, true, "flow");
    update.addPin("DeltaTime", false, false, "float");
    nodes.add(update);
  }
  
  void addNode(VLBNode node) {
    nodes.add(node);
  }
  
  void connect(VLBPin from, VLBPin pinTo) {
    if (from == null || pinTo == null) return;
    if (from.parent == pinTo.parent) return; // No self-connection
    
    // Ensure pinTo is the input for standardization
    VLBPin src = from.isInput ? pinTo : from;
    VLBPin dst = from.isInput ? from : pinTo;
    
    // Enforce one-to-one for ALL pins: Remove any connection involving src or dst
    for (int i = connections.size() - 1; i >= 0; i--) {
      VLBConnection c = connections.get(i);
      if (c.pinTo == dst || c.from == dst || c.from == src || c.pinTo == src) {
        c.from.connectedTo = null;
        c.pinTo.connectedTo = null;
        connections.remove(i);
      }
    }
    
    connections.add(new VLBConnection(src, dst));
    src.connectedTo = dst;
    dst.connectedTo = src;
  }
  
  /**
   * generatePDES() - Transpilation Hub
   * 
   * [ALGORITHM] VLB to PDES Conversion
   * This is the heart of the Visual Logic System. It traverses the node graph 
   * starting from 'Event: OnStart' and recursively emits PDES commands.
   * It ensures that data-dependency nodes (Math, GetPos) are emitted BEFORE 
   * the flow nodes (Log, SetPos) that consume them.
   */
  String generatePDES() {
    VLBNode startNode = null;
    for (VLBNode n : nodes) if (n.title.equals("Event: OnStart")) { startNode = n; break; }
    if (startNode == null) return "# Error: No OnStart node found";
    
    StringBuilder sb = new StringBuilder();
    sb.append("# Auto-generated PDES from VLB\n");
    HashSet<Integer> visited = new HashSet<Integer>();
    traverseNode(startNode, sb, visited);
    return sb.toString();
  }
  
  // v1.3: Generate PDES for a specific event type entry point
  String generatePDESForEvent(String eventTitle) {
    VLBNode entryNode = null;
    for (VLBNode n : nodes) if (n.title.equals(eventTitle)) { entryNode = n; break; }
    if (entryNode == null) return null;
    
    StringBuilder sb = new StringBuilder();
    sb.append("# Auto-generated PDES [").append(eventTitle).append("]\n");
    HashSet<Integer> visited = new HashSet<Integer>();
    traverseNode(entryNode, sb, visited);
    return sb.toString();
  }
  
  // v1.3: Compile all event entry points into owner's event map
  void compileAllEvents() {
    if (owner == null) return;
    
    HashMap<String, String> targetMap = null;
    if (owner instanceof Entity) {
      targetMap = ((Entity)owner).blueprintEventPDES;
    } else if (owner instanceof SceneManager) {
      targetMap = ((SceneManager)owner).blueprintEventPDES;
    }
    
    if (targetMap == null) return;
    targetMap.clear();
    
    String[] eventTitles = {
      "Event: OnStart", "Event: OnUpdate", "Event: OnKeyPress",
      "Event: OnMouseClick", "Event: OnBeginOverlap", "Event: OnEndOverlap"
    };
    
    for (String evt : eventTitles) {
      String pdes = generatePDESForEvent(evt);
      if (pdes != null) {
        // Map event title to runtime event key
        String key = evt.replace("Event: ", "");
        targetMap.put(key, pdes);
      }
    }
    
    // Legacy compatibility for legacy PDES fields
    if (targetMap.containsKey("OnStart")) {
      String startPdes = targetMap.get("OnStart");
      if (owner instanceof Entity) ((Entity)owner).blueprintPDES = startPdes;
      else if (owner instanceof SceneManager) ((SceneManager)owner).blueprintPDES = startPdes;
    }
  }
  
  /**
   * [ALGORITHM] emitDataDeps() - Recursive Dependency Emission
   * 
   * For a given flow node, this function finds all connected input data pins, 
   * traces them back to their source nodes (e.g., an 'Add' node), and recursively 
   * emits the script commands needed to calculate those values. 
   * Results are stored in temporary variables ($add_12, $pos_x_5) for the 
   * consumer to use.
   */
  void emitDataDeps(VLBNode n, StringBuilder sb, HashSet<Integer> visited) {
    if (n == null || visited.contains(n.id)) return;
    // Only process data-producing nodes (no flow input)
    boolean hasFlowIn = false;
    for (VLBPin p : n.inputs) if (p.isFlow) { hasFlowIn = true; break; }
    if (hasFlowIn) return; // Flow nodes are handled by traverseNode
    
    // First, recursively emit this node's own data dependencies
    for (VLBPin ip : n.inputs) {
      if (!ip.isFlow && ip.connectedTo != null) {
        emitDataDeps(ip.connectedTo.parent, sb, visited);
      }
    }
    
    visited.add(n.id);
    // Emit command for this data node
    if (n.title.equals("Get Position")) {
      String target = resolveData(n.findPin("Target", true));
      sb.append("getpos ").append(target).append(" pos_x_").append(n.id).append(" pos_y_").append(n.id).append(" pos_z_").append(n.id).append("\n");
    } else if (n.title.equals("Add")) {
      sb.append("set add_").append(n.id).append(" ").append(resolveData(n.findPin("A", true))).append(" + ").append(resolveData(n.findPin("B", true))).append("\n");
    } else if (n.title.equals("Subtract")) {
      sb.append("set sub_").append(n.id).append(" ").append(resolveData(n.findPin("A", true))).append(" - ").append(resolveData(n.findPin("B", true))).append("\n");
    } else if (n.title.equals("Multiply")) {
      sb.append("set mul_").append(n.id).append(" ").append(resolveData(n.findPin("A", true))).append(" * ").append(resolveData(n.findPin("B", true))).append("\n");
    } else if (n.title.equals("Divide")) {
      sb.append("set div_").append(n.id).append(" ").append(resolveData(n.findPin("A", true))).append(" / ").append(resolveData(n.findPin("B", true))).append("\n");
    } else if (n.title.equals("Random")) {
      sb.append("rand rand_").append(n.id).append(" ").append(resolveData(n.findPin("Min", true))).append(" ").append(resolveData(n.findPin("Max", true))).append("\n");
    } else if (n.title.equals("AND")) {
      sb.append("set and_").append(n.id).append(" ").append(resolveData(n.findPin("A", true))).append(" & ").append(resolveData(n.findPin("B", true))).append("\n");
    } else if (n.title.equals("OR")) {
      sb.append("set or_").append(n.id).append(" ").append(resolveData(n.findPin("A", true))).append(" | ").append(resolveData(n.findPin("B", true))).append("\n");
    } else if (n.title.equals("NOT")) {
      sb.append("set not_").append(n.id).append(" !").append(resolveData(n.findPin("In", true))).append("\n");
    } else if (n.title.equals("Get Visibility")) {
      String target = resolveData(n.findPin("Target", true));
      sb.append("getvisible ").append(target).append(" vis_").append(n.id).append("\n");
    } else if (n.title.equals("Time")) {
      sb.append("gettime time_").append(n.id).append("\n");
    } else if (n.title.equals("Math Expression")) {
      // v1.8: Refined Advanced Expression Node
      VLBPin exprPin = n.findPin("Expression", true);
      String expr = (exprPin != null) ? exprPin.sVal : "";
      
      // Replace variables in expression with resolved pin data (excluding the expression pin itself)
      for (VLBPin ip : n.inputs) {
        if (!ip.isFlow && ip != exprPin) {
          String val = resolveData(ip);
          expr = expr.replaceAll("\\b" + ip.label + "\\b", val);
        }
      }
      
      // Support 't' alias for time (default to time in seconds)
      if (expr.contains(" t ") || expr.startsWith("t ") || expr.endsWith(" t") || expr.equals("t") || expr.contains("(t)")) {
         expr = expr.replaceAll("\\bt\\b", "time"); 
      }
      
      sb.append("eval res_").append(n.id).append(" ").append(expr).append("\n");
    }
  }
  
  /**
   * [ALGORITHM] traverseNode() - Control Flow Generation
   * 
   * Performs a linear traversal of the flow-carrying nodes in the graph.
   * 1. Assigns a PDES label (:node_ID) to the current segment.
   * 2. Calls emitDataDeps to prepare all necessary input variables.
   * 3. Maps the visual node type to its corresponding PDES command (tp, spawn, echo, etc.).
   * 4. Follows the output flow pin to the next node in the chain.
   * 5. Special Case: Branch nodes emit 'if/else/goto' logic instead of linear fallthrough.
   */
  void traverseNode(VLBNode n, StringBuilder sb, HashSet<Integer> visited) {
    if (n == null) return;
    visited.add(n.id);
    sb.append(":node_").append(n.id).append("\n");
    
    // v1.4: Pre-emit data dependency nodes (nodes with no flow that feed into this node)
    for (VLBPin ip : n.inputs) {
      if (!ip.isFlow && ip.connectedTo != null) {
        emitDataDeps(ip.connectedTo.parent, sb, visited);
      }
    }
    
    // Command Generation
    if (n.title.equals("Log")) {
      sb.append("echo ").append(resolveData(n.findPin("Message", true))).append("\n");
    } else if (n.title.equals("Print")) {
      sb.append("echo ").append(resolveData(n.findPin("Value", true))).append("\n");
    } else if (n.title.equals("Wait")) {
      sb.append("wait ").append(resolveData(n.findPin("Time (ms)", true))).append("\n");
    } else if (n.title.equals("Set Position")) {
      String target = resolveData(n.findPin("Target", true));
      String x = resolveData(n.findPin("X", true));
      String y = resolveData(n.findPin("Y", true));
      String z = resolveData(n.findPin("Z", true));
      sb.append("tp ").append(target).append(" ").append(x).append(" ").append(y).append(" ").append(z).append("\n");
    } else if (n.title.equals("Spawn Entity")) {
      String type = resolveData(n.findPin("Type", true));
      String name = resolveData(n.findPin("Name", true));
      String x = resolveData(n.findPin("X", true));
      String y = resolveData(n.findPin("Y", true));
      String z = resolveData(n.findPin("Z", true));
      sb.append("spawn ").append(type).append(" ").append(name).append(" ").append(x).append(" ").append(y).append(" ").append(z).append("\n");
    } else if (n.title.equals("Set Visibility")) {
      String target = resolveData(n.findPin("Target", true));
      String visible = resolveData(n.findPin("Visible", true));
      sb.append("visible ").append(target).append(" ").append(visible).append("\n");
    } else if (n.title.equals("Light Settings")) {
      String target = resolveData(n.findPin("Target", true));
      String intensity = resolveData(n.findPin("Intensity", true));
      String range = resolveData(n.findPin("Range", true));
      sb.append("intensity ").append(target).append(" ").append(intensity).append("\n");
      sb.append("range ").append(target).append(" ").append(range).append("\n");
    } else if (n.title.equals("Set Background")) {
      String r = resolveData(n.findPin("R", true));
      String g = resolveData(n.findPin("G", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("bg ").append(r).append(" ").append(g).append(" ").append(b).append("\n");
    } else if (n.title.equals("Camera Teleport")) {
      String x = resolveData(n.findPin("X", true));
      String y = resolveData(n.findPin("Y", true));
      String z = resolveData(n.findPin("Z", true));
      sb.append("cam_tp ").append(x).append(" ").append(y).append(" ").append(z).append("\n");
    } else if (n.title.equals("Branch")) {
      String cond = resolveData(n.findPin("Condition", true));
      VLBPin truePin = n.findPin("True", false);
      VLBPin falsePin = n.findPin("False", false);
      sb.append("if ").append(cond).append(" == 1\n");
      if (truePin.connectedTo != null) sb.append("  goto :node_").append(truePin.connectedTo.parent.id).append("\n");
      sb.append("else\n");
      if (falsePin.connectedTo != null) sb.append("  goto :node_").append(falsePin.connectedTo.parent.id).append("\n");
      sb.append("endif\n");
      return; // Branch handles its own flow
    } else if (n.title.equals("Compare")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      String op = n.findPin("Op", true).sVal;
      VLBPin truePin = n.findPin("True", false);
      VLBPin falsePin = n.findPin("False", false);
      sb.append("if ").append(a).append(" ").append(op).append(" ").append(b).append("\n");
      if (truePin != null && truePin.connectedTo != null) sb.append("  goto :node_").append(truePin.connectedTo.parent.id).append("\n");
      sb.append("else\n");
      if (falsePin != null && falsePin.connectedTo != null) sb.append("  goto :node_").append(falsePin.connectedTo.parent.id).append("\n");
      sb.append("endif\n");
      return;
    } else if (n.title.equals("Get Position")) {
      String target = resolveData(n.findPin("Target", true));
      sb.append("getpos ").append(target).append(" pos_x_").append(n.id).append(" pos_y_").append(n.id).append(" pos_z_").append(n.id).append("\n");
    } else if (n.title.equals("Add")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set add_").append(n.id).append(" ").append(a).append(" + ").append(b).append("\n");
    } else if (n.title.equals("Subtract")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set sub_").append(n.id).append(" ").append(a).append(" - ").append(b).append("\n");
    } else if (n.title.equals("Multiply")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set mul_").append(n.id).append(" ").append(a).append(" * ").append(b).append("\n");
    } else if (n.title.equals("Divide")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set div_").append(n.id).append(" ").append(a).append(" / ").append(b).append("\n");
    } else if (n.title.equals("AND")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set and_").append(n.id).append(" ").append(a).append(" & ").append(b).append("\n");
    } else    if (n.title.equals("OR")) {
      String a = resolveData(n.findPin("A", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set or_").append(n.id).append(" ").append(a).append(" | ").append(b).append("\n");
    } else if (n.title.equals("Counter")) {
       String start = resolveData(n.findPin("Start", true));
       String end = resolveData(n.findPin("End", true));
       String step = resolveData(n.findPin("Step", true));
       String interval = resolveData(n.findPin("Interval", true));
       VLBPin outPin = n.findPin("Out", false);
       VLBPin finishedPin = n.findPin("Finished", false);
       
       sb.append("for counter_").append(n.id).append(" ").append(start).append(" ").append(end).append(" ").append(step).append("\n");
       if (outPin != null && outPin.connectedTo != null) {
         sb.append("  goto :node_").append(outPin.connectedTo.parent.id).append("\n");
       }
       sb.append("  wait ").append(interval).append("\n");
       sb.append("endfor\n");
       if (finishedPin != null && finishedPin.connectedTo != null) {
         sb.append("goto :node_").append(finishedPin.connectedTo.parent.id).append("\n");
       }
       return;
    } else if (n.title.equals("Math Expression")) {
       String expr = n.findPin("Expression", true).sVal;
       // v1.8: Replace all variable markers in the expression with their resolved data
       for (VLBPin p : n.inputs) {
         if (p.label.equals("Expression")) continue;
         String resolved = resolveData(p);
         // Replace whole words only to avoid partial matches
         expr = expr.replaceAll("\\b" + p.label + "\\b", resolved);
       }
       // Support 't' as an alias for time in seconds if users prefer it
       if (!expr.contains("$t")) {
         expr = expr.replaceAll("\\bt\\b", "(time*0.001)");
       }
       
       sb.append("eval res_").append(n.id).append(" ").append(expr).append("\n");
       // Math Expression is a data node, it doesn't have flow outputs to traverse
       // VLBConnection next = findConnection(n.findPin("Out", false)); // This line is incorrect for a data node
       // if (next != null) traverseNode(next.pinTo.parent, sb, visited); // This line is incorrect for a data node
    } else if (n.title.equals("NOT")) {
      String a = resolveData(n.findPin("In", true));
      sb.append("set not_").append(n.id).append(" !").append(a).append("\n");
    } else if (n.title.equals("Random")) {
      String min = resolveData(n.findPin("Min", true));
      String max = resolveData(n.findPin("Max", true));
      sb.append("rand rand_").append(n.id).append(" ").append(min).append(" ").append(max).append("\n");
    } else if (n.title.equals("Timer")) {
      String interval = resolveData(n.findPin("Interval", true));
      sb.append("timer ").append(interval).append("\n");
    } else if (n.title.equals("TriggerZone")) {
      String radius = resolveData(n.findPin("Radius", true));
      sb.append("triggerzone $this ").append(radius).append("\n");
      VLBPin enterPin = n.findPin("OnEnter", false);
      VLBPin exitPin = n.findPin("OnExit", false);
      sb.append("on_enter ");
      if (enterPin != null && enterPin.connectedTo != null) sb.append("goto :node_").append(enterPin.connectedTo.parent.id);
      sb.append("\n");
      sb.append("on_exit ");
      if (exitPin != null && exitPin.connectedTo != null) sb.append("goto :node_").append(exitPin.connectedTo.parent.id);
      sb.append("\n");
      return; // TriggerZone handles its own flow
    } else if (n.title.equals("Int") || n.title.equals("Float")) {
      sb.append("set val_").append(n.id).append(" ").append(resolveData(n.findPin("Value", true))).append("\n");
    } else if (n.title.equals("String")) {
      sb.append("set str_").append(n.id).append(" ").append(resolveData(n.findPin("Value", true))).append("\n");
    } else if (n.title.equals("Bool")) {
      sb.append("set bool_").append(n.id).append(" ").append(resolveData(n.findPin("Value", true))).append("\n");
    } else if (n.title.equals("Color")) {
      String r = resolveData(n.findPin("R", true));
      String g = resolveData(n.findPin("G", true));
      String b = resolveData(n.findPin("B", true));
      sb.append("set color_").append(n.id).append(" ").append(r).append(" ").append(g).append(" ").append(b).append("\n");
    } else if (n.title.equals("Vector3")) {
      String vx = resolveData(n.findPin("X", true));
      String vy = resolveData(n.findPin("Y", true));
      String vz = resolveData(n.findPin("Z", true));
      sb.append("set vec3_").append(n.id).append(" ").append(vx).append(" ").append(vy).append(" ").append(vz).append("\n");
    }
    
    // Linear Flow
    for (VLBPin p : n.outputs) {
      if (p.isFlow && p.connectedTo != null) {
        VLBNode next = p.connectedTo.parent;
        if (!visited.contains(next.id)) {
          traverseNode(next, sb, visited);
        } else {
          sb.append("goto :node_").append(next.id).append("\n");
        }
        break;
      }
    }
  }
  
  /**
   * resolveData() - Pin Value Binding
   * 
   * [ALGORITHM] Variable Reference Mapping
   * Determines what string should represent a pin's value in the final script.
   * - If disconnected: Returns the pin's literal value (10.0, "Hello").
   * - If connected: Returns a variable reference ($res_ID, $pos_x_ID) that 
   *   points to the pre-emitted calculation result of the source node.
   */
  String resolveData(VLBPin p) {
    if (p == null) return "0";
    // v1.1: Follow connected data pins to their source
    if (p.connectedTo != null && !p.isFlow) {
      VLBPin src = p.connectedTo;
      // If source is an output from a Value node, read that node's input value
      if (!src.isInput) {
        VLBNode srcNode = src.parent;
        VLBPin valPin = srcNode.findPin("Value", true);
        if (valPin != null) {
          return resolveData(valPin);
        }
        // For nodes like Get Position, Expression etc., return variable reference
        if (srcNode.title.equals("Expression") || srcNode.title.equals("Math Expression")) return "$res_" + srcNode.id;
        if (srcNode.title.equals("Random")) return "$rand_" + srcNode.id;
        if (srcNode.title.equals("Counter")) return "$counter_" + srcNode.id;
        if (srcNode.title.equals("Add")) return "$add_" + srcNode.id;
        if (srcNode.title.equals("Subtract")) return "$sub_" + srcNode.id;
        if (srcNode.title.equals("Multiply")) return "$mul_" + srcNode.id;
        if (srcNode.title.equals("Divide")) return "$div_" + srcNode.id;
        if (srcNode.title.equals("AND")) return "$and_" + srcNode.id;
        if (srcNode.title.equals("OR")) return "$or_" + srcNode.id;
        if (srcNode.title.equals("NOT")) return "$not_" + srcNode.id;
        if (srcNode.title.equals("Get Position")) {
          if (src.label.equals("X")) return "$pos_x_" + srcNode.id;
          if (src.label.equals("Y")) return "$pos_y_" + srcNode.id;
          if (src.label.equals("Z")) return "$pos_z_" + srcNode.id;
        }
      }
      // Fallback: read connected pin value directly
      if (src.dataType.equals("string")) {
        if (src.sVal.startsWith("$")) return src.sVal;
        return src.sVal.isEmpty() ? "\"\"" : "\"" + src.sVal + "\"";
      }
      return String.valueOf(src.val);
    }
    if (p.dataType.equals("string")) {
      if (p.sVal.startsWith("$")) return p.sVal;
      return p.sVal.isEmpty() ? "\"\"" : "\"" + p.sVal + "\"";
    }
    
    // v1.7: Special variable mapping for complex nodes
    if (p.parent.title.equals("Math Expression") && p.label.equals("Return Value")) {
      return "$res_" + p.parent.id;
    }
    if (p.parent.title.equals("Counter") && p.label.equals("Value")) {
      return "$counter_" + p.parent.id;
    }
    if (p.parent.title.equals("Time") && p.label.equals("Millis")) {
      return "$time_" + p.parent.id;
    }
    if (p.parent.title.equals("Get Visibility") && p.label.equals("Visible")) {
      return "$vis_" + p.parent.id;
    }
    
    // Default variable naming for data nodes
    if (!p.isInput) {
       return "$" + p.parent.title.toLowerCase().replace(" ", "_") + "_" + p.parent.id;
    }
    
    return String.valueOf(p.val);
  }
}
