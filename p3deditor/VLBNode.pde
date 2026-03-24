class VLBPin {
  String label;
  boolean isInput;
  boolean isFlow; // True if it's an execution pin (white), false if data (colored)
  String dataType; // "float", "string", "color", etc.
  VLBNode parent;
  
  // Connection state
  VLBPin connectedTo = null; // Simplified: one-to-one for now
  float val = 0; // Default numeric value
  String sVal = ""; // Default string value

  VLBPin(VLBNode parent, String label, boolean isInput, boolean isFlow, String dataType) {
    this.parent = parent;
    this.label = label;
    this.isInput = isInput;
    this.isFlow = isFlow;
    this.dataType = dataType;
  }

  void connectTo(VLBPin other) {
    // Clear old connections
    if (this.connectedTo != null) this.connectedTo.connectedTo = null;
    if (other != null && other.connectedTo != null) other.connectedTo.connectedTo = null;
    
    this.connectedTo = other;
    if (other != null) other.connectedTo = this;
  }

  float getGlobalX() { return parent.x + (isInput ? 0 : parent.w); }
  float getGlobalY() { 
    int idx = isInput ? parent.inputs.indexOf(this) : parent.outputs.indexOf(this);
    if (idx == -1) return parent.y + 12; // Safety fallback to header
    return parent.y + 35 + idx * 20; 
  }
}

class VLBNode {
  int id;
  String title;
  String type; // "Event", "Action", "Logic", "Variable"
  float x, y, w, h;
  ArrayList<VLBPin> inputs = new ArrayList<VLBPin>();
  ArrayList<VLBPin> outputs = new ArrayList<VLBPin>();
  
  boolean selected = false; // v0.9.0
  color headerCol;
  
  VLBNode(int id, String title, String type, float x, float y) {
    this.id = id;
    this.title = title;
    this.type = type;
    this.x = x;
    this.y = y;
    this.w = 120;
    this.h = 60;
    
    // Default Header Colors
    if (type.equals("Event")) headerCol = color(180, 40, 40); // Red
    else if (type.equals("Action")) headerCol = color(40, 80, 180); // Blue
    else if (type.equals("Logic")) headerCol = color(180, 150, 40); // Gold
    else headerCol = color(60, 60, 65);
  }
  
  VLBPin addPin(String label, boolean isInput, boolean isFlow, String dataType) {
    VLBPin p = new VLBPin(this, label, isInput, isFlow, dataType);
    if (isInput) inputs.add(p);
    else outputs.add(p);
    
    updateLayout();
    return p;
  }
  
  // v1.7: Calculate w and h based on pin labels and title
  void updateLayout() {
    float maxLabelW = p3deditor.this.textWidth(title) + 30;
    
    // Check all pins
    for (VLBPin p : inputs) {
      float pw = p3deditor.this.textWidth(p.label) + 40;
      if (p.dataType.equals("string")) {
        float sw = p3deditor.this.textWidth(p.sVal) + 20;
        pw += max(60, sw); 
      }
      else if (!p.isFlow) pw += 40; // Extra for numeric/bool field
      maxLabelW = max(maxLabelW, pw);
    }
    for (VLBPin p : outputs) {
      float pw = p3deditor.this.textWidth(p.label) + 40;
      maxLabelW = max(maxLabelW, pw);
    }
    
    w = max(120, maxLabelW);
    h = max(60, max(inputs.size(), outputs.size()) * 20 + 35);
  }
  
  VLBPin getPinAt(float mx, float my) {
    // v1.0: Enlarged rectangular AABB hit zones covering the entire pin row
    for (VLBPin p : inputs) {
      float py = p.getGlobalY();
      // Input pins: left half of node (x to x + w/2), row height = 18px
      if (mx >= x && mx <= x + w * 0.5f && my >= py - 9 && my <= py + 9) return p;
    }
    for (VLBPin p : outputs) {
      float py = p.getGlobalY();
      // Output pins: right half of node (x + w/2 to x + w), row height = 18px
      if (mx >= x + w * 0.5f && mx <= x + w && my >= py - 9 && my <= py + 9) return p;
    }
    return null;
  }
  
  VLBPin findPin(String label, boolean isInput) {
    ArrayList<VLBPin> list = isInput ? inputs : outputs;
    for (VLBPin p : list) if (p.label.equals(label)) return p;
    return null;
  }
}

class VLBConnection {
  VLBPin from;
  VLBPin pinTo;
  
  VLBConnection(VLBPin from, VLBPin pinTo) {
    this.from = from;
    this.pinTo = pinTo;
  }
}
