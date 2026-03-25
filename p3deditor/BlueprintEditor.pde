/**
 * BlueprintEditor.pde - Visual Logic Workspace
 * 
 * Version: v0.4.9
 * Responsibilities:
 * - Provides an interactive 'Node Graph' canvas for visual programming.
 * - Handles infinite panning, zooming, and grid rendering.
 * - Manages node lifecycle: spawning, dragging, connecting, and deletion.
 * - Implements the 'Compile' bridge to the PDES Scripting system.
 * - Supports 'Hot-Reload' of logic during engine play sessions.
 */
class BlueprintEditor {
  Blueprint activeBlueprint = null;
  boolean visible = false;
  
  float panX = 0, panY = 0;
  float zoom = 1.0;
  
  // Interaction state
  VLBNode draggingNode = null;
  VLBPin draggingPin = null;
  VLBPin hoveredPin = null; // v1.0: Pin hover highlight
  
  // v1.2: Reworked mouse 
  boolean isRightDragging = false;
  float rightPressX, rightPressY;
  boolean isBoxSelecting = false;
  float boxStartX, boxStartY;
  
  // v1.2: Inline pin editing
  VLBPin editingPin = null;
  String editingPinText = "";
  
  // v1.7: Node Title editing (REMOVED - Expression now uses a pin)
  // VLBNode editingNode = null;
  // String editingNodeText = "";
  
  // v0.9.2: Node Menu
  boolean showNodeMenu = false;
  float menuX, menuY;
  float menuScrollY = 0;      // v1.2: Menu scroll offset
  
  // v1.0: Categorized Node Menu
  String[] menuCategories = { "â€?Action â€?, "â€?Logic â€?, "â€?Math â€?, "â€?Data â€?, "â€?Event â€?, "â€?Value â€? };
  String[][] menuItems = {
    { "Action: Wait", "Action: Log", "Action: Print", "Action: Set Position", "Action: Spawn Entity", "Action: Set Visibility", "Action: Light Settings", "Action: Set Background", "Action: Camera Teleport", "Action: Get Visibility" },
    { "Logic: Branch", "Logic: Compare", "Logic: Counter", "Logic: AND", "Logic: OR", "Logic: NOT" },
    { "Math: Add", "Math: Subtract", "Math: Multiply", "Math: Divide" },
    { "Data: Math Expression", "Data: Get Position", "Data: Random", "Data: Time" },
    { "Event: Timer", "Event: TriggerZone", "Event: OnStart", "Event: OnUpdate", "Event: OnKeyPress", "Event: OnMouseClick", "Event: OnBeginOverlap", "Event: OnEndOverlap" },
    { "Value: Int", "Value: Float", "Value: String", "Value: Bool", "Value: Color", "Value: Vector3" }
  };
  
  // v1.0: Compile Feedback
  int compileFlashTime = 0;
  String compileStatus = "";
  
  BlueprintEditor() {
    panX = width / 2;
    panY = height / 2;
  }
  
  void openBP(Blueprint bp) {
    this.activeBlueprint = bp;
    this.visible = true;
  }
  
  // === HELPER: Calculate total menu height ===
  float getMenuTotalHeight() {
    int totalItems = 0;
    for (int c = 0; c < menuCategories.length; c++) totalItems += menuItems[c].length + 1;
    return totalItems * 24 + 10;
  }
  
  // === HELPER: Get menu item name to display ===
  String getMenuItemForY(float clickY) {
    float yy = menuY + 5 + menuScrollY;
    for (int c = 0; c < menuCategories.length; c++) {
      yy += 24; // Header
      for (int i = 0; i < menuItems[c].length; i++) {
        if (clickY > yy && clickY < yy + 24) return menuItems[c][i];
        yy += 24;
      }
    }
    return null;
  }
  
  /**
   * render() - Blueprint Canvas Pass
   * 
   * [ALGORITHM] Layer-based UI Composition
   * Draws the visual graph in clear depth stages:
   * 1. Background Grid (infinite parallax).
   * 2. Bezier Connections (wire layer).
   * 3. VLB Nodes (interactive blocks).
   * 4. Overlays (Compiling status, Menu, Headers).
   */
  void render() {
    if (!visible || activeBlueprint == null) return;
    
    pushStyle();
    p3deditor.this.hint(p3deditor.this.ENABLE_DEPTH_TEST);
    p3deditor.this.background(20, 20, 22);
    
    // Update hovered pin
    float wx = (mouseX - panX) / zoom;
    float wy = (mouseY - panY) / zoom;
    hoveredPin = null;
    if (!showNodeMenu && mouseY > 40 && editingPin == null) {
      for (VLBNode n : activeBlueprint.nodes) {
        VLBPin p = n.getPinAt(wx, wy);
        if (p != null) { hoveredPin = p; break; }
      }
    }
    
    // 3. Render World (Grid + Nodes + Connections)
    pushMatrix();
    translate(panX, panY, 0);
    scale(zoom);
    
    // Grid (Z=-10)
    pushMatrix(); translate(0, 0, -10); drawGrid(); popMatrix();
    
    // Connections (Z=-5)
    pushMatrix(); translate(0, 0, -5);
    for (VLBConnection conn : activeBlueprint.connections) {
      drawConnection(conn);
    }
    popMatrix();
    
    // Nodes (Z=0)
    for (VLBNode n : activeBlueprint.nodes) {
      renderNode(n);
    }
    
    // Active pin drag wire
    if (draggingPin != null) {
      stroke(255, 200, 0, 180); strokeWeight(2.5f); noFill();
      float x1 = draggingPin.getGlobalX();
      float y1 = draggingPin.getGlobalY();
      float mx = (mouseX - panX)/zoom;
      float my = (mouseY - panY)/zoom;
      float ctrlOffset = max(30, abs(mx - x1) * 0.5f);
      bezier(x1, y1, x1 + (draggingPin.isInput ? -ctrlOffset : ctrlOffset), y1, 
             mx + (draggingPin.isInput ? ctrlOffset : -ctrlOffset), my, mx, my);
    }
    
    // v1.2: Box Selection Rect
    if (isBoxSelecting) {
      float bx1 = (boxStartX - panX) / zoom;
      float by1 = (boxStartY - panY) / zoom;
      float bx2 = (mouseX - panX) / zoom;
      float by2 = (mouseY - panY) / zoom;
      stroke(100, 180, 255, 180); strokeWeight(1); 
      fill(100, 180, 255, 30);
      rect(min(bx1, bx2), min(by1, by2), abs(bx2-bx1), abs(by2-by1));
    }
    
    popMatrix();
    
    // 4. Header Overlay
    fill(35, 35, 40); noStroke(); rect(0, 0, width, 40);
    fill(255); textSize(14); textAlign(LEFT, CENTER);
    String ownerName = "Unknown";
    if (activeBlueprint.owner instanceof Entity) ownerName = ((Entity)activeBlueprint.owner).name;
    else if (activeBlueprint.owner instanceof SceneManager) ownerName = "Global Scene";
    text("Blueprint Editor: " + ownerName, 20, 20);
    
    // v1.0: Build & Run Button with compile flash
    float runX = width - 150;
    boolean isFlashing = (millis() - compileFlashTime) < 2000;
    
    if (isFlashing) {
      float pulse = sin((millis() - compileFlashTime) * 0.005f) * 0.3f + 0.7f;
      fill(lerpColor(color(45, 140, 45), color(80, 255, 80), pulse));
      rect(runX, 10, 100, 25, 4);
      fill(255); textSize(11); textAlign(CENTER, CENTER); text("âœ?Compiled!", runX + 50, 22);
    } else {
      if (mouseX > runX && mouseX < runX + 100 && mouseY > 10 && mouseY < 35) fill(60, 180, 60); else fill(45, 70, 45);
      rect(runX, 10, 100, 25, 4);
      fill(255); textSize(11); textAlign(CENTER, CENTER); text("Compile", runX + 50, 22);
    }
    
    // Close Button
    float closeX = width - 40;
    if (mouseX > closeX && mouseX < closeX + 25 && mouseY > 10 && mouseY < 35) fill(200, 50, 50); else fill(60, 60, 65);
    rect(closeX, 10, 25, 25, 4);
    fill(255); textAlign(CENTER, CENTER); text("X", closeX + 12, 22);
    
    // v1.0: Compile Status Bar
    if (!compileStatus.isEmpty()) {
      float elapsed = millis() - compileFlashTime;
      if (elapsed < 4000) {
        float alpha = elapsed < 3000 ? 255 : map(elapsed, 3000, 4000, 255, 0);
        fill(30, 30, 35, alpha); noStroke();
        rect(0, height - 28, width, 28);
        fill(140, 255, 140, alpha); textSize(11); textAlign(LEFT, CENTER);
        text(compileStatus, 15, height - 14);
      }
    }
    
    if (showNodeMenu) renderNodeMenu();
    
    popStyle();
  }
  
  void drawGrid() {
    p3deditor.this.resetShader();
    stroke(28); strokeWeight(1);
    float step = 50;
    float startX = (-panX / zoom) - ((-panX / zoom) % step) - step * 10;
    float startY = (-panY / zoom) - ((-panY / zoom) % step) - step * 10;
    float endX = startX + (width / zoom) + step * 20;
    float endY = startY + (height / zoom) + step * 20;
    for (float x = startX; x < endX; x += step) line(x, startY, x, endY);
    for (float y = startY; y < endY; y += step) line(startX, y, endX, y);
    stroke(35);
    step *= 5;
    startX = (-panX / zoom) - ((-panX / zoom) % step) - step * 2;
    startY = (-panY / zoom) - ((-panY / zoom) % step) - step * 2;
    for (float x = startX; x < endX; x += step) line(x, startY, x, endY);
    for (float y = startY; y < endY; y += step) line(startX, y, endX, y);
  }
  
  void renderNode(VLBNode n) {
    pushStyle();
    // Shadow
    fill(0, 50); noStroke();
    rect(n.x + 4, n.y + 4, n.w, n.h, 6);
    
    // Main Body
    p3deditor.this.noStroke();
    p3deditor.this.fill(35, 35, 40);
    p3deditor.this.rect(n.x, n.y + 25, n.w, n.h-25, 0, 0, 8, 8);
    
    // Selection highlight border
    if (n.selected) {
      stroke(100, 200, 255); strokeWeight(1.5f); noFill();
      rect(n.x - 1, n.y - 1, n.w + 2, n.h + 2, 7);
    }
    
    // Header
    p3deditor.this.fill(n.headerCol);
    noStroke();
    rect(n.x, n.y, n.w, 24, 6, 6, 0, 0);
    fill(255); textSize(11); textAlign(LEFT, CENTER);
    text(n.title, n.x + 8, n.y + 12);
    
    // Pins
    renderPins(n);
    popStyle();
  }
  
  void renderPins(VLBNode n) {
    textSize(9);
    for (int i=0; i<n.inputs.size(); i++) {
      VLBPin p = n.inputs.get(i);
      float py = n.y + 35 + i*20;
      
      // v1.0: Pin hover highlight
      if (p == hoveredPin) {
        fill(255, 255, 255, 30); noStroke();
        rect(n.x, py - 9, n.w / 2, 18, 3);
      }
      
      fill(p.isFlow ? 255 : color(100, 255, 100)); noStroke();
      if (p.isFlow) triangle(n.x + 4, py - 5, n.x + 4, py + 5, n.x + 12, py);
      else ellipse(n.x + 8, py, 8, 8);
      
      // v1.2: Inline editable text field for data pins (non-flow, non-connected)
      if (!p.isFlow && p.connectedTo == null) {
        float fieldX = n.x + 16;
        float fieldW = n.w * 0.5f - 20;
        
        if (p.dataType.equals("bool")) {
          // v1.6: Bool Toggle UI
          stroke(80); strokeWeight(1);
          if (p.val > 0.5f) fill(100, 255, 100); else fill(20, 20, 25);
          rect(fieldX, py - 6, 12, 12, 2);
          if (p.val > 0.5f) {
            stroke(255); noFill();
            line(fieldX + 3, py, fieldX + 5, py + 3);
            line(fieldX + 5, py + 3, fieldX + 9, py - 3);
          }
        } else if (editingPin == p) {
          // Active editing state
          fill(20, 20, 25); stroke(100, 180, 255); strokeWeight(1);
          rect(fieldX, py - 7, fieldW, 14, 2);
          fill(255); noStroke(); textAlign(LEFT, CENTER); textSize(8);
          text(editingPinText + "|", fieldX + 3, py);
        } else {
          // Display value
          fill(25, 25, 30); stroke(55); strokeWeight(0.5f);
          rect(fieldX, py - 7, fieldW, 14, 2);
          fill(180); noStroke(); textAlign(LEFT, CENTER); textSize(8);
          String displayVal = p.dataType.equals("string") ? p.sVal : String.format(java.util.Locale.US, "%.1f", p.val);
          text(displayVal, fieldX + 3, py);
        }
      } else {
        fill(200); textAlign(LEFT, CENTER);
        text(p.label, n.x + 16, py);
      }
    }
    for (int i=0; i<n.outputs.size(); i++) {
      VLBPin p = n.outputs.get(i);
      float py = n.y + 35 + i*20;
      
      if (p == hoveredPin) {
        fill(255, 255, 255, 30); noStroke();
        rect(n.x + n.w / 2, py - 9, n.w / 2, 18, 3);
      }
      
      fill(p.isFlow ? 255 : color(100, 255, 100)); noStroke();
      if (p.isFlow) triangle(n.x + n.w - 12, py - 5, n.x + n.w - 12, py + 5, n.x + n.w - 4, py);
      else ellipse(n.x + n.w - 8, py, 8, 8);
      fill(200); textAlign(RIGHT, CENTER);
      text(p.label, n.x + n.w - 16, py);
      
      // v1.8: Show real-time value for output pins (Red box as requested)
      if (!p.isFlow) {
        String varName = getLiveVarName(p);
        float liveVal = p3deditor.this.scriptManager.getVariableValue(activeBlueprint.owner, varName);
        if (!Float.isNaN(liveVal)) {
          String valStr = (liveVal == (long)liveVal) ? String.valueOf((long)liveVal) : String.format(java.util.Locale.US, "%.1f", liveVal);
          float tw = textWidth(valStr) + 8;
          // Position it to the left of the output pin label
          float tx = n.x + n.w - 20 - textWidth(p.label) - tw - 5;
          
          rectMode(CENTER);
          fill(220, 40, 40); noStroke(); 
          rect(tx + tw/2, py, tw, 14, 3);
          fill(255); textAlign(CENTER, CENTER); textSize(8);
          text(valStr, tx + tw/2, py - 1);
          rectMode(CORNER);
          textSize(9); // restore
        }
      }
    }
  }
  
  // v1.8: Map node output pins to PDES variable names
  String getLiveVarName(VLBPin p) {
    if (p.isInput) return "";
    VLBNode n = p.parent;
    if (n.title.equals("Math Expression")) return "res_" + n.id;
    if (n.title.equals("Counter")) return "counter_" + n.id;
    if (n.title.equals("Time")) return "time_" + n.id;
    if (n.title.equals("Get Visibility")) return "vis_" + n.id;
    if (n.title.equals("Random")) return "rand_" + n.id;
    if (n.title.equals("Add")) return "add_" + n.id;
    if (n.title.equals("Subtract")) return "sub_" + n.id;
    if (n.title.equals("Multiply")) return "mul_" + n.id;
    if (n.title.equals("Divide")) return "div_" + n.id;
    if (n.title.equals("Get Position")) {
      if (p.label.equals("X")) return "pos_x_" + n.id;
      if (p.label.equals("Y")) return "pos_y_" + n.id;
      if (p.label.equals("Z")) return "pos_z_" + n.id;
    }
    return p.parent.title.toLowerCase().replace(" ", "_") + "_" + n.id;
  }
  
  void drawConnection(VLBConnection conn) {
    if (conn.from.isFlow) stroke(255, 230); else stroke(100, 200, 255, 230); 
    strokeWeight(2.5f); noFill();
    float x1 = conn.from.getGlobalX();
    float y1 = conn.from.getGlobalY();
    float x2 = conn.pinTo.getGlobalX();
    float y2 = conn.pinTo.getGlobalY();
    float ctrlOffset = max(30, abs(x2 - x1) * 0.5f);
    bezier(x1, y1, x1 + ctrlOffset, y1, x2 - ctrlOffset, y2, x2, y2);
  }
  
  /**
   * handleMousePressed() / Dragged() / Released()
   * 
   * [ALGORITHM] Graph Interaction Workflow
   * - Left-Click: Node selection or Pin drag start (wiring).
   * - Box Select: Dragging on empty space to group-select nodes.
   * - Right-Drag: Viewport panning.
   * - Context Menu: Right-click on empty space to spawn nodes.
   */
  void handleMousePressed() {
    if (!visible || activeBlueprint == null) return;
    
    // Close Button
    float closeX = width - 40;
    if (mouseX > closeX && mouseX < closeX + 25 && mouseY > 10 && mouseY < 35) {
      visible = false;
      return;
    }
    
    // Build & Run
    float runX = width - 150;
    if (mouseX > runX && mouseX < runX + 100 && mouseY > 10 && mouseY < 35) {
      String pdes = activeBlueprint.generatePDES();
      
      // Store in entity if applicable
      if (activeBlueprint.owner instanceof Entity) {
        ((Entity)activeBlueprint.owner).blueprintPDES = pdes;
      }
      
      // v1.8: Hot-reload if in Play Mode
      if (p3deditor.this.scene.isPlaying()) {
        String scriptTitle = "VLB_Runtime_";
        if (activeBlueprint.owner instanceof Entity) scriptTitle += ((Entity)activeBlueprint.owner).id;
        else scriptTitle += "Level";
        
        p3deditor.this.scriptManager.stopScriptEntity(activeBlueprint.owner);
        p3deditor.this.scriptManager.runScript(scriptTitle, pdes, activeBlueprint.owner);
      }
      
      compileFlashTime = millis();
      compileStatus = "Compiled & Hot-Reloaded (" + pdes.length() + " bytes)";
      String ownerLogName = (activeBlueprint.owner instanceof Entity) ? ((Entity)activeBlueprint.owner).name : "Global Scene";
      p3deditor.this.ui.debugConsole.addLog("SUCCESS: Blueprint compiled & updated for " + ownerLogName, 1);
      return;
    }
    
    // Menu click handling
    if (showNodeMenu) {
      float menuW = 180;
      float totalH = getMenuTotalHeight();
      float visibleH = min(totalH, height - 60);
      
      if (mouseX > menuX && mouseX < menuX + menuW && mouseY > menuY && mouseY < menuY + visibleH) {
        String item = getMenuItemForY(mouseY);
        if (item != null) spawnNode(item);
      }
      showNodeMenu = false;
      return;
    }
    
    float cwx = (mouseX - panX) / zoom;
    float cwy = (mouseY - panY) / zoom;
    
    // v1.2: RIGHT BUTTON = prepare for pan or menu
    if (mouseButton == RIGHT) {
      isRightDragging = false;
      rightPressX = mouseX;
      rightPressY = mouseY;
      return;
    }
    
    // === LEFT BUTTON ===
    draggingPin = null;
    draggingNode = null;
    
    // Commit any active pin edit
    if (editingPin != null) commitPinEdit();
    
    // 1. Check Pins First
    for (VLBNode n : activeBlueprint.nodes) {
      VLBPin p = n.getPinAt(cwx, cwy);
      if (p != null) {
        // v1.2: Check if clicking on an editable data field
        if (p.isInput && !p.isFlow && p.connectedTo == null) {
          float fieldX = n.x + 16;
          float fieldW = n.w * 0.5f - 20;
          float py = p.getGlobalY();
          if (cwx >= fieldX && cwx <= fieldX + fieldW && cwy >= py - 7 && cwy <= py + 7) {
            if (p.dataType.equals("bool")) {
              p.val = (p.val > 0.5f) ? 0 : 1;
              return;
            }
            editingPin = p;
            editingPinText = p.dataType.equals("string") ? p.sVal : String.format(java.util.Locale.US, "%.1f", p.val);
            return;
          }
        }
        draggingPin = p;
        return;
      }
    }
    
    // 2. Check Nodes (left-click = select)
    boolean hitNode = false;
    for (int i = activeBlueprint.nodes.size()-1; i >= 0; i--) {
      VLBNode n = activeBlueprint.nodes.get(i);
      if (cwx > n.x && cwx < n.x + n.w && cwy > n.y && cwy < n.y + n.h) {
        // v1.4: If clicking an already-selected node, keep multi-selection for group drag
        if (n.selected) {
          // Already selected â€?just set as drag target, don't clear others
          draggingNode = n;
        } else {
          if (!p3deditor.this.keyPressed || (p3deditor.this.key != 17 && p3deditor.this.keyCode != p3deditor.this.CONTROL)) {
            for (VLBNode nn : activeBlueprint.nodes) nn.selected = false;
          }
          n.selected = true;
          draggingNode = n;
          // Bring to front
          activeBlueprint.nodes.remove(i);
          activeBlueprint.nodes.add(n);
        }
        hitNode = true;
        break;
      }
    }
    
    if (!hitNode) {
      // Clear selection and start box select
      for (VLBNode n : activeBlueprint.nodes) n.selected = false;
      isBoxSelecting = true;
      boxStartX = mouseX;
      boxStartY = mouseY;
    }
  }
  
  // v1.2: Scrollable Node Menu Rendering (clamped to window)
  void renderNodeMenu() {
    pushStyle();
    float menuW = 180;
    float totalH = getMenuTotalHeight();
    float visibleH = min(totalH, height - 60); // Don't exceed window
    
    // Clamp menu position to window bounds
    float drawX = min(menuX, width - menuW - 5);
    float drawY = min(menuY, height - visibleH - 5);
    menuX = drawX;
    menuY = drawY;
    
    // Background
    fill(30, 30, 35, 245); stroke(70); strokeWeight(1);
    rect(drawX, drawY, menuW, visibleH, 6);
    
    // Clip contents
    p3deditor.this.clip(drawX, drawY, menuW, visibleH);
    
    float yy = drawY + 5 + menuScrollY;
    for (int c = 0; c < menuCategories.length; c++) {
      // Category Header
      if (yy + 24 > drawY && yy < drawY + visibleH) {
        fill(70); textSize(9); textAlign(LEFT, CENTER);
        text(menuCategories[c], drawX + 10, yy + 12);
      }
      yy += 24;
      
      // Items
      for (int i = 0; i < menuItems[c].length; i++) {
        if (yy + 24 > drawY && yy < drawY + visibleH) {
          boolean hover = mouseX > drawX && mouseX < drawX + menuW && mouseY > yy && mouseY < yy + 24;
          if (hover) {
            fill(50, 70, 160); noStroke();
            rect(drawX + 3, yy, menuW - 6, 24, 4);
          }
          fill(220); textSize(11); textAlign(LEFT, CENTER);
          String displayName = menuItems[c][i].substring(menuItems[c][i].indexOf(":") + 2);
          text(displayName, drawX + 18, yy + 12);
        }
        yy += 24;
      }
    }
    
    p3deditor.this.noClip();
    
    // Draw scrollbar if content exceeds visible
    if (totalH > visibleH) {
      float thumbH = max(20, visibleH * (visibleH / totalH));
      float maxScroll = totalH - visibleH;
      float thumbY = drawY + (-menuScrollY / maxScroll) * (visibleH - thumbH);
      fill(80, 80, 90); noStroke();
      rect(drawX + menuW - 8, thumbY, 6, thumbH, 3);
    }
    
    popStyle();
  }
  
  void spawnNode(String type) {
    float spawnWx = (menuX - panX) / zoom;
    float spawnWy = (menuY - panY) / zoom;
    int nextId = 0;
    for (VLBNode n : activeBlueprint.nodes) nextId = max(nextId, n.id + 1);
    VLBNode n = createVLBNode(type, nextId, spawnWx, spawnWy);
    if (n != null) activeBlueprint.addNode(n);
  }
  
  // === MOUSE DRAGGED ===
  void handleMouseDragged() {
    if (!visible || activeBlueprint == null) return;
    if (draggingPin != null) return; // No pan while dragging wire
    
    // v1.2: Right-drag = pan viewport
    if (mouseButton == RIGHT) {
      isRightDragging = true;
      panX += (mouseX - pmouseX);
      panY += (mouseY - pmouseY);
      return;
    }
    
    // Left-drag: move selected nodes or box select
    if (draggingNode != null) {
      float dx = (mouseX - pmouseX) / zoom;
      float dy = (mouseY - pmouseY) / zoom;
      // Move ALL selected nodes
      for (VLBNode n : activeBlueprint.nodes) {
        if (n.selected) {
          n.x += dx;
          n.y += dy;
        }
      }
    } else if (isBoxSelecting) {
      // Update box selection in real-time
      float bx1 = min(boxStartX, mouseX);
      float by1 = min(boxStartY, mouseY);
      float bx2 = max(boxStartX, mouseX);
      float by2 = max(boxStartY, mouseY);
      
      float wx1 = (bx1 - panX) / zoom;
      float wy1 = (by1 - panY) / zoom;
      float wx2 = (bx2 - panX) / zoom;
      float wy2 = (by2 - panY) / zoom;
      
      for (VLBNode n : activeBlueprint.nodes) {
        n.selected = (n.x + n.w > wx1 && n.x < wx2 && n.y + n.h > wy1 && n.y < wy2);
      }
    }
  }
  
  // === MOUSE RELEASED ===
  void handleMouseReleased() {
    // Connection Completion
    if (draggingPin != null) {
      float rwx = (mouseX - panX) / zoom;
      float rwy = (mouseY - panY) / zoom;
      
      for (VLBNode n : activeBlueprint.nodes) {
        VLBPin targetPin = n.getPinAt(rwx, rwy);
        if (targetPin != null && targetPin != draggingPin) {
          if (targetPin.isInput != draggingPin.isInput && targetPin.isFlow == draggingPin.isFlow) {
            if (draggingPin.isInput) activeBlueprint.connect(targetPin, draggingPin);
            else activeBlueprint.connect(draggingPin, targetPin);
          }
        }
      }
      draggingPin = null;
    }
    
    // v1.2: Right button released without dragging = show context menu
    if (mouseButton == RIGHT && !isRightDragging) {
      showNodeMenu = true;
      menuX = mouseX;
      menuY = mouseY;
      menuScrollY = 0;
    }
    
    isRightDragging = false;
    isBoxSelecting = false;
    draggingNode = null;
  }
  
  void handleMouseWheel(float count) {
    // v1.2: If menu is open, scroll the menu
    if (showNodeMenu) {
      float totalH = getMenuTotalHeight();
      float visibleH = min(totalH, height - 60);
      if (totalH > visibleH) {
        menuScrollY -= count * 20;
        float maxScroll = totalH - visibleH;
        menuScrollY = constrain(menuScrollY, -maxScroll, 0);
      }
      return;
    }
    
    float prevZoom = zoom;
    if (count < 0) zoom *= 1.1f;
    else zoom *= 0.9f;
    zoom = constrain(zoom, 0.2f, 3.0f);
    
    // Zoom towards mouse
    panX -= (mouseX - panX) * (zoom / prevZoom - 1);
    panY -= (mouseY - panY) * (zoom / prevZoom - 1);
  }
  
  // v1.2: Commit inline pin value edit
  void commitPinEdit() {
    if (editingPin == null) return;
    if (editingPin.dataType.equals("string")) {
      editingPin.sVal = editingPinText;
      // v1.7: If this is the "Expression" pin of a Math Expression node, sync pins
      if (editingPin.label.equals("Expression") && editingPin.parent.title.equals("Math Expression")) {
        syncExpressionPins(editingPin.parent);
      }
      editingPin.parent.updateLayout();
    } else {
      try {
        editingPin.val = Float.parseFloat(editingPinText);
        editingPin.parent.updateLayout();
      } catch (Exception ex) { /* keep old value */ }
    }
    editingPin = null;
    editingPinText = "";
  }
  
  /**
   * [ALGORITHM] syncExpressionPins() - Dynamic Reflection
   * 
   * This critical algorithm parses a mathematical expression string (e.g. "sin(val) * 10")
   * and automatically generates input pins for every undefined variable ("val") 
   * found in the string. It preserves existing connections during the sync, 
   * enabling seamless 'Expressive Programming'.
   */
  void syncExpressionPins(VLBNode n) {
     VLBPin exprPin = n.findPin("Expression", true);
     if (exprPin == null) return;
     
     String expr = exprPin.sVal;
     HashSet<String> vars = new HashSet<String>();
     Matcher m = Pattern.compile("[a-zA-Z_][a-zA-Z0-9_]*").matcher(expr);
     
     // Reserved words to ignore (functions and constants)
     List<String> reserved = Arrays.asList(
       "sin", "cos", "tan", "sqrt", "abs", "rand", "min", "max", "PI", "E", "time", "dt"
     );
     
     while (m.find()) {
       String v = m.group();
       if (!reserved.contains(v)) vars.add(v);
     }
     
     // Preserve existing pins and connections
     java.util.ArrayList<VLBPin> newInputs = new java.util.ArrayList<VLBPin>();
     
     // v1.7: ALWAYS preserve the "Expression" pin itself
     VLBPin exprPinCurrent = n.findPin("Expression", true);
     if (exprPinCurrent != null) newInputs.add(exprPinCurrent);
     
     for (String v : vars) {
       // Don't add if it's the "Expression" pin itself (redundant)
       if (v.equals("Expression")) continue;
       
       VLBPin existing = n.findPin(v, true);
       if (existing != null) {
         newInputs.add(existing);
       } else {
         VLBPin p = new VLBPin(n, v, true, false, "float");
         newInputs.add(p);
       }
     }
     
     // v1.7: Clear connections to pins that are being removed to prevent ghost wires
     for (int i = activeBlueprint.connections.size() - 1; i >= 0; i--) {
       VLBConnection c = activeBlueprint.connections.get(i);
       if (c.from.parent == n || c.pinTo.parent == n) {
         // Check if either pin is NOT in the new input/output lists
         boolean fromExists = n.outputs.contains(c.from) || newInputs.contains(c.from);
         boolean toExists = n.outputs.contains(c.pinTo) || newInputs.contains(c.pinTo);
         if (!fromExists || !toExists) {
           c.from.connectedTo = null;
           c.pinTo.connectedTo = null;
           activeBlueprint.connections.remove(i);
         }
       }
     }
     
     n.inputs = newInputs;
     n.updateLayout();
  }
  
  void handleKeyPressed(int k, int kc) {
    if (!visible || activeBlueprint == null) return;
    
    // v1.2: Handle inline pin text editing
    if (editingPin != null) {
      if (k == p3deditor.this.ENTER || k == p3deditor.this.RETURN) {
        commitPinEdit();
      } else if (k == p3deditor.this.ESC) {
        editingPin = null;
        editingPinText = "";
        p3deditor.this.key = 0; // Prevent ESC from closing editor
      } else if (k == p3deditor.this.BACKSPACE || k == 8) {
        if (editingPinText.length() > 0) editingPinText = editingPinText.substring(0, editingPinText.length() - 1);
      } else if (k >= 32 && k < 127) {
        editingPinText += (char)k;
      }
      return; // Absorb all keys while editing
    }
    
    // Delete Selected Nodes
    if (k == p3deditor.this.BACKSPACE || k == p3deditor.this.DELETE || kc == p3deditor.this.DELETE || k == 127) {
      for (int i = activeBlueprint.nodes.size()-1; i >= 0; i--) {
        VLBNode n = activeBlueprint.nodes.get(i);
        if (n.selected) {
          for (int j = activeBlueprint.connections.size()-1; j >= 0; j--) {
            VLBConnection c = activeBlueprint.connections.get(j);
            if (c.from.parent == n || c.pinTo.parent == n) {
              c.from.connectedTo = null;
              c.pinTo.connectedTo = null;
              activeBlueprint.connections.remove(j);
            }
          }
          activeBlueprint.nodes.remove(i);
        }
      }
    }
    
    // Ctrl+A = Select All
    if (kc == 65 && p3deditor.this.keyPressed && (p3deditor.this.key == 1 || p3deditor.this.keyCode == p3deditor.this.CONTROL)) {
      for (VLBNode n : activeBlueprint.nodes) n.selected = true;
    }
  }
}
