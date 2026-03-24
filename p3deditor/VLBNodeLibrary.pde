// VLBNodeLibrary.pde - Factory for pre-configured logic nodes

VLBNode createVLBNode(String typeName, int id, float x, float y) {
  // === ACTION NODES ===
  if (typeName.equals("Action: Wait")) {
    VLBNode n = new VLBNode(id, "Wait", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin p = n.addPin("Time (ms)", true, false, "float");
    p.val = 1000;
    return n;
  }
  if (typeName.equals("Action: Log")) {
    VLBNode n = new VLBNode(id, "Log", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin p = n.addPin("Message", true, false, "string");
    p.sVal = "Hello from Blueprint!";
    return n;
  }
  if (typeName.equals("Action: Print")) {
    VLBNode n = new VLBNode(id, "Print", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin p = n.addPin("Value", true, false, "string");
    p.sVal = "Debug Output";
    return n;
  }
  if (typeName.equals("Action: Set Position")) {
    VLBNode n = new VLBNode(id, "Set Position", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin tgt = n.addPin("Target", true, false, "string");
    tgt.sVal = "$this";
    n.addPin("X", true, false, "float").val = 0;
    n.addPin("Y", true, false, "float").val = 5;
    n.addPin("Z", true, false, "float").val = 0;
    return n;
  }
  if (typeName.equals("Action: Spawn Entity")) {
    VLBNode n = new VLBNode(id, "Spawn Entity", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin t = n.addPin("Type", true, false, "string");
    t.sVal = "Cube";
    VLBPin nm = n.addPin("Name", true, false, "string");
    nm.sVal = "Spawned";
    n.addPin("X", true, false, "float").val = 0;
    n.addPin("Y", true, false, "float").val = 0;
    n.addPin("Z", true, false, "float").val = 0;
    return n;
  }
  if (typeName.equals("Action: Set Visibility")) {
    VLBNode n = new VLBNode(id, "Set Visibility", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin tgt = n.addPin("Target", true, false, "string");
    tgt.sVal = "$this";
    n.addPin("Visible", true, false, "bool").val = 1;
    return n;
  }
  if (typeName.equals("Action: Get Visibility")) {
    VLBNode n = new VLBNode(id, "Get Visibility", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin tgt = n.addPin("Target", true, false, "string");
    tgt.sVal = "$this";
    n.addPin("Visible", false, false, "bool");
    return n;
  }
  if (typeName.equals("Action: Light Settings")) {
    VLBNode n = new VLBNode(id, "Light Settings", "Action", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Out", false, true, "flow");
    VLBPin tgt = n.addPin("Target", true, false, "string");
    tgt.sVal = "$this";
    n.addPin("Intensity", true, false, "float").val = 1.0;
    n.addPin("Range", true, false, "float").val = 300;
    return n;
  }

  // === LOGIC NODES ===
  if (typeName.equals("Logic: Branch")) {
    VLBNode n = new VLBNode(id, "Branch", "Logic", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("True", false, true, "flow");
    n.addPin("False", false, true, "flow");
    n.addPin("Condition", true, false, "bool");
    return n;
  }
  if (typeName.equals("Logic: Compare")) {
    VLBNode n = new VLBNode(id, "Compare", "Logic", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("A", true, false, "float");
    n.addPin("B", true, false, "float");
    VLBPin op = n.addPin("Op", true, false, "string");
    op.sVal = ">";
    n.addPin("True", false, true, "flow");
    n.addPin("False", false, true, "flow");
    return n;
  }
  if (typeName.equals("Logic: Counter")) {
    VLBNode n = new VLBNode(id, "Counter", "Logic", x, y);
    n.addPin("In", true, true, "flow");
    n.addPin("Reset", true, true, "flow");
    n.addPin("Start", true, false, "float").val = 0;
    n.addPin("End", true, false, "float").val = 10;
    n.addPin("Step", true, false, "float").val = 1;
    n.addPin("Interval", true, false, "float").val = 1000;
    n.addPin("Out", false, true, "flow");
    n.addPin("Finished", false, true, "flow");
    n.addPin("Value", false, false, "float");
    return n;
  }

  // === DATA NODES ===
  if (typeName.equals("Data: Expression")) {
    VLBNode n = new VLBNode(id, "Expression", "Data", x, y);
    n.headerCol = color(80, 60, 160); // Purple
    n.addPin("A", true, false, "float").val = 0;
    n.addPin("B", true, false, "float").val = 0;
    VLBPin op = n.addPin("Op", true, false, "string");
    op.sVal = "+";
    n.addPin("Result", false, false, "float");
    return n;
  }
  if (typeName.equals("Data: Get Position")) {
    VLBNode n = new VLBNode(id, "Get Position", "Data", x, y);
    n.headerCol = color(80, 60, 160); // Purple
    VLBPin tgt = n.addPin("Target", true, false, "string");
    tgt.sVal = "$this";
    n.addPin("X", false, false, "float");
    n.addPin("Y", false, false, "float");
    n.addPin("Z", false, false, "float");
    return n;
  }
  if (typeName.equals("Data: Random")) {
    VLBNode n = new VLBNode(id, "Random", "Data", x, y);
    n.headerCol = color(80, 60, 160); // Purple
    n.addPin("Min", true, false, "float").val = 0;
    n.addPin("Max", true, false, "float").val = 100;
    n.addPin("Result", false, false, "float");
    return n;
  }

  // === MATH OPERATOR NODES ===
  if (typeName.equals("Math: Add")) {
    VLBNode n = new VLBNode(id, "Add", "Math", x, y);
    n.headerCol = color(60, 130, 60); // Green
    n.addPin("A", true, false, "float").val = 0;
    n.addPin("B", true, false, "float").val = 0;
    n.addPin("Result", false, false, "float");
    return n;
  }
  if (typeName.equals("Math: Subtract")) {
    VLBNode n = new VLBNode(id, "Subtract", "Math", x, y);
    n.headerCol = color(60, 130, 60);
    n.addPin("A", true, false, "float").val = 0;
    n.addPin("B", true, false, "float").val = 0;
    n.addPin("Result", false, false, "float");
    return n;
  }
  if (typeName.equals("Math: Multiply")) {
    VLBNode n = new VLBNode(id, "Multiply", "Math", x, y);
    n.headerCol = color(60, 130, 60);
    n.addPin("A", true, false, "float").val = 0;
    n.addPin("B", true, false, "float").val = 1;
    n.addPin("Result", false, false, "float");
    return n;
  }
  if (typeName.equals("Data: Expression") || typeName.equals("Data: Math Expression")) {
    VLBNode n = new VLBNode(id, "Math Expression", "Data", x, y);
    n.addPin("Expression", true, false, "string").sVal = "(1+x)*sin(time)";
    n.addPin("X", true, false, "float").val = 1.0;
    n.addPin("Time", true, false, "float").val = 0.0;
    n.addPin("Return Value", false, false, "float");
    return n;
  }
  if (typeName.equals("Data: Time")) {
    VLBNode n = new VLBNode(id, "Time", "Data", x, y);
    n.addPin("Millis", false, false, "float");
    return n;
  }

  // === LOGIC GATE NODES ===
  if (typeName.equals("Logic: AND")) {
    VLBNode n = new VLBNode(id, "AND", "Logic", x, y);
    n.addPin("A", true, false, "bool").val = 0;
    n.addPin("B", true, false, "bool").val = 0;
    n.addPin("Result", false, false, "bool");
    return n;
  }
  if (typeName.equals("Logic: OR")) {
    VLBNode n = new VLBNode(id, "OR", "Logic", x, y);
    n.addPin("A", true, false, "bool").val = 0;
    n.addPin("B", true, false, "bool").val = 0;
    n.addPin("Result", false, false, "bool");
    return n;
  }
  if (typeName.equals("Logic: NOT")) {
    VLBNode n = new VLBNode(id, "NOT", "Logic", x, y);
    n.addPin("In", true, false, "bool").val = 0;
    n.addPin("Result", false, false, "bool");
    return n;
  }

  // === EVENT NODES ===
  if (typeName.equals("Event: OnStart")) {
    VLBNode n = new VLBNode(id, "Event: OnStart", "Event", x, y);
    n.addPin("Out", false, true, "flow");
    return n;
  }
  if (typeName.equals("Event: Timer")) {
    VLBNode n = new VLBNode(id, "Timer", "Event", x, y);
    n.addPin("Interval", true, false, "float").val = 1000;
    n.addPin("Tick", false, true, "flow");
    return n;
  }
  if (typeName.equals("Event: TriggerZone")) {
    VLBNode n = new VLBNode(id, "TriggerZone", "Event", x, y);
    n.addPin("Radius", true, false, "float").val = 100;
    n.addPin("OnEnter", false, true, "flow");
    n.addPin("OnExit", false, true, "flow");
    n.addPin("Entity", false, false, "string"); // Name of entity that entered
    return n;
  }
  if (typeName.equals("Event: OnUpdate")) {
    VLBNode n = new VLBNode(id, "Event: OnUpdate", "Event", x, y);
    n.addPin("Out", false, true, "flow");
    n.addPin("DeltaTime", false, false, "float");
    return n;
  }
  if (typeName.equals("Event: OnKeyPress")) {
    VLBNode n = new VLBNode(id, "Event: OnKeyPress", "Event", x, y);
    VLBPin k = n.addPin("Key", true, false, "string");
    k.sVal = "W";
    n.addPin("Pressed", false, true, "flow");
    n.addPin("Released", false, true, "flow");
    return n;
  }
  if (typeName.equals("Event: OnMouseClick")) {
    VLBNode n = new VLBNode(id, "Event: OnMouseClick", "Event", x, y);
    n.addPin("Out", false, true, "flow");
    n.addPin("Button", false, false, "string"); // LEFT, RIGHT, CENTER
    return n;
  }
  if (typeName.equals("Event: OnBeginOverlap")) {
    VLBNode n = new VLBNode(id, "Event: OnBeginOverlap", "Event", x, y);
    n.addPin("Out", false, true, "flow");
    n.addPin("OtherEntity", false, false, "string");
    return n;
  }
  if (typeName.equals("Event: OnEndOverlap")) {
    VLBNode n = new VLBNode(id, "Event: OnEndOverlap", "Event", x, y);
    n.addPin("Out", false, true, "flow");
    n.addPin("OtherEntity", false, false, "string");
    return n;
  }

  // === VALUE / LITERAL NODES ===
  if (typeName.equals("Value: Int")) {
    VLBNode n = new VLBNode(id, "Int", "Value", x, y);
    n.headerCol = color(50, 120, 80); // Green
    n.addPin("Value", true, false, "float").val = 0;
    n.addPin("Out", false, false, "float");
    return n;
  }
  if (typeName.equals("Value: Float")) {
    VLBNode n = new VLBNode(id, "Float", "Value", x, y);
    n.headerCol = color(50, 120, 80); // Green
    n.addPin("Value", true, false, "float").val = 0.0;
    n.addPin("Out", false, false, "float");
    return n;
  }
  if (typeName.equals("Value: String")) {
    VLBNode n = new VLBNode(id, "String", "Value", x, y);
    n.headerCol = color(50, 120, 80); // Green
    VLBPin p = n.addPin("Value", true, false, "string");
    p.sVal = "Hello";
    n.addPin("Out", false, false, "string");
    return n;
  }
  if (typeName.equals("Value: Bool")) {
    VLBNode n = new VLBNode(id, "Bool", "Value", x, y);
    n.headerCol = color(50, 120, 80); // Green
    n.addPin("Value", true, false, "bool").val = 1; // 1=true, 0=false
    n.addPin("Out", false, false, "bool");
    return n;
  }
  if (typeName.equals("Value: Color")) {
    VLBNode n = new VLBNode(id, "Color", "Value", x, y);
    n.headerCol = color(50, 120, 80); // Green
    n.addPin("R", true, false, "float").val = 255;
    n.addPin("G", true, false, "float").val = 255;
    n.addPin("B", true, false, "float").val = 255;
    n.addPin("Hex", false, false, "string");
    return n;
  }
  if (typeName.equals("Value: Vector3")) {
    VLBNode n = new VLBNode(id, "Vector3", "Value", x, y);
    n.headerCol = color(50, 120, 80); // Green
    n.addPin("X", true, false, "float").val = 0;
    n.addPin("Y", true, false, "float").val = 0;
    n.addPin("Z", true, false, "float").val = 0;
    n.addPin("X", false, false, "float");
    n.addPin("Y", false, false, "float");
    n.addPin("Z", false, false, "float");
    return n;
  }

  return null;
}
