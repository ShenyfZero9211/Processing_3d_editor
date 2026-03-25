/**
 * UIManager - The Graphical Interface & HUD System
 * 
 * Version: v0.5.0
 * Responsibilities:
 * - Renders the dual-panel editor interface (Hierarchy & Inspector).
 * - Manages the top Menu Bar and context-sensitive dropdowns.
 * - Handles text input for property editing and the Command Console.
 * - Implements scrolling, dragging, and widget hit-testing.
 * - Coordinates with BlueprintEditor for visual programming.
 */
class UIManager {
  SceneManager scene;
  BlueprintEditor vlbEditor; 
  int panelWidth = 250;
  float scrollY = 0;
  float totalContentHeight = 0;
  boolean isDraggingScrollbar = false;
  float dragThumbOffsetY = 0;
  
  // v0.5.0: Inspector Scrolling
  float inspectorScrollY = 0;
  float inspectorTotalHeight = 0;
  boolean isDraggingInspectorScroll = false;
  float inspectorDragThumbY = 0;
  
  Entity hierarchyDragSource = null;
  Entity hierarchyDragTarget = null;
  float hierarchyDragStartX, hierarchyDragStartY;
  boolean hasDraggedHierarchy = false;
  
  boolean showContextMenu = false;
  float menuX, menuY;
  
  int activeEditTarget = 0; // 0=None, 1=Name, 2=PosX...
  String activeEditString = "";
  
  ArrayList<HierarchyItemRect> hierarchyRects = new ArrayList<HierarchyItemRect>();
  CommandInterpreter interpreter;
  String consoleResult = "";
  float menuBarHeight = 30;
  String activeMenu = "";
  boolean showConsole = true;
  boolean showStats = true;
  DebugConsole debugConsole;
  
  class HierarchyItemRect {
    Entity entity; float y;
    HierarchyItemRect(Entity e, float y) { this.entity = e; this.y = y; }
  }
  
  UIManager(SceneManager scene, CommandInterpreter interpreter, BlueprintEditor vlbEditor) {
    this.scene = scene;
    this.interpreter = interpreter;
    this.vlbEditor = vlbEditor;
    this.debugConsole = new DebugConsole(interpreter);
    
    // Auto-run startup script if it exists
    interpreter.execute("exec init.p3dec");
  }
  
  boolean isEditingText() { return activeEditTarget > 0; }
  
  /**
   * commitEdit() - UI Data Synchronization
   * 
   * [ALGORITHM] Property Binding
   * This function is triggered when Enter is pressed in an input field.
   * It parses the 'activeEditString' (which could be a float, hex, or name)
   * and applies it to the selected entity's transform or material properties.
   * It also pushes a 'ValueEditCommand' to the Undo stack for rollback support.
   */
  void commitEdit() {
    if (activeEditTarget == 100) {
      try { scene.envMapIntensity = max(0, Float.parseFloat(activeEditString)); } catch(Exception ex) {}
      activeEditTarget = 0;
      return;
    }
    
    if (activeEditTarget == 99) {
      debugConsole.addLog("> " + activeEditString, 0);
      consoleResult = interpreter.execute(activeEditString);
      if (consoleResult.startsWith("Error")) debugConsole.addLog(consoleResult, 3);
      else debugConsole.addLog(consoleResult, 1);
      activeEditTarget = 0;
      return;
    }
    
    if (activeEditTarget == 0 || scene.selectedEntities.size() != 1) {
      activeEditTarget = 0;
      return;
    }
    Entity e = scene.selectedEntities.get(0);
    String oldVal = "";
    if (activeEditTarget == 1) oldVal = e.name;
    else if (activeEditTarget == 2) oldVal = String.valueOf(e.transform.position.x);
    else if (activeEditTarget == 3) oldVal = String.valueOf(e.transform.position.y);
    else if (activeEditTarget == 4) oldVal = String.valueOf(e.transform.position.z);
    else if (activeEditTarget == 5) oldVal = String.valueOf(degrees(e.transform.rotation.x));
    else if (activeEditTarget == 6) oldVal = String.valueOf(degrees(e.transform.rotation.y));
    else if (activeEditTarget == 7) oldVal = String.valueOf(degrees(e.transform.rotation.z));
    else if (activeEditTarget == 8) oldVal = String.valueOf(e.transform.scale.x);
    else if (activeEditTarget == 9) oldVal = String.valueOf(e.transform.scale.y);
    else if (activeEditTarget == 10) oldVal = String.valueOf(e.transform.scale.z);
    
    try {
      if (activeEditTarget == 1) e.name = activeEditString;
      else if (activeEditTarget == 2) e.transform.position.x = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 3) e.transform.position.y = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 4) e.transform.position.z = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 5) e.transform.rotation.x = radians(Float.parseFloat(activeEditString));
      else if (activeEditTarget == 6) e.transform.rotation.y = radians(Float.parseFloat(activeEditString));
      else if (activeEditTarget == 7) e.transform.rotation.z = radians(Float.parseFloat(activeEditString));
      else if (activeEditTarget == 8) e.transform.scale.x = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 9) e.transform.scale.y = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 10) e.transform.scale.z = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 11) {
        // Hex Color Support
        try { 
           String h = activeEditString.replace("#", "");
           if (h.length() == 6) {
             e.col = (int)Long.parseLong("FF" + h, 16);
             e.material.albedo = e.col;
           }
        } catch(Exception ex) {}
      }
      else if (activeEditTarget == 12) e.lightIntensity = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 13) e.lightRange = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 14) e.material.metallic = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 15) e.material.roughness = Float.parseFloat(activeEditString);
      
      scene.undoManager.push(new ValueEditCommand(scene, e, activeEditTarget, oldVal, activeEditString));
    } catch (Exception ex) {}
    activeEditTarget = 0;
  }
  
  void handleStepperHit(Entity e, int id, int dir) {
    if (id == 2) e.transform.position.x += dir * 1.0f;
    else if (id == 3) e.transform.position.y += dir * 1.0f;
    else if (id == 4) e.transform.position.z += dir * 1.0f;
    else if (id == 5) e.transform.rotation.x += radians(dir * 5.0f);
    else if (id == 6) e.transform.rotation.y += radians(dir * 5.0f);
    else if (id == 7) e.transform.rotation.z += radians(dir * 5.0f);
    else if (id == 8) e.transform.scale.x = max(0.1f, e.transform.scale.x + dir * 0.1f);
    else if (id == 9) e.transform.scale.y = max(0.1f, e.transform.scale.y + dir * 0.1f);
    else if (id == 10) e.transform.scale.z = max(0.1f, e.transform.scale.z + dir * 0.1f);
    else if (id == 12) e.lightIntensity = max(0, e.lightIntensity + dir * 0.1f);
    else if (id == 13) e.lightRange = max(10, e.lightRange + dir * 10.0f);
    else if (id == 14) e.material.metallic = constrain(e.material.metallic + dir * 0.05f, 0, 1);
    else if (id == 15) e.material.roughness = constrain(e.material.roughness + dir * 0.05f, 0, 1);
    else if (id == 100) scene.envMapIntensity = max(0, scene.envMapIntensity + dir * 0.05f);
  }
  
  void handleTextEditKey() {
    if (keyCode == ENTER || keyCode == RETURN) {
      commitEdit();
    } else if (keyCode == ESC) {
      activeEditTarget = 0;
    } else if (keyCode == BACKSPACE || keyCode == DELETE) {
      if (activeEditString.length() > 0) activeEditString = activeEditString.substring(0, activeEditString.length() - 1);
    } else {
      // Allow hex characters for color editing, AND spaces for console commands
      boolean isHexChar = (key >= 'a' && key <= 'f') || (key >= 'A' && key <= 'F');
      boolean isPrintable = (key >= 32 && key <= 126); 
      
      if (activeEditTarget == 14 && isPrintable) {
        activeEditString += key;
      } else if (activeEditTarget == 1 || activeEditTarget == 11 || (key >= '0' && key <= '9') || key == '.' || key == '-' || isHexChar) {
        activeEditString += key;
      }
    }
  }
  
  void drawEditField(String label, String value, int id, float x, float y) {
    fill(200); textSize(11); text(label, x, y);
    float labelW = 85; 
    float boxX = x + labelW;
    float boxW = (id == 1 || id == 11) ? 65 : 50;
    
    // Background for text input box
    float ly = mouseY - inspectorScrollY;
    boolean isHover = mouseX > boxX && mouseX < boxX + boxW && ly > y - 14 && ly < y + 4;
    
    if (activeEditTarget == id) {
      fill(30, 40, 60); stroke(100, 150, 255); strokeWeight(1.5f);
      rect(boxX, y - 14, boxW, 18, 3);
      noStroke(); fill(255, 255, 0); textSize(11);
      text(activeEditString + (frameCount % 60 < 30 ? "|" : ""), boxX + 5, y);
    } else {
      fill(35, 35, 40); stroke(isHover ? 100 : 50); strokeWeight(1);
      rect(boxX, y - 14, boxW, 18, 3);
      noStroke(); fill(isHover ? 255 : 180); textSize(11);
      text(value, boxX + 5, y);
    }
    
    // Stepper Buttons (+/-) for numerical fields (Ignore Name:1, AlbedoHex:11)
    if (id != 1 && id != 11) {
      float btnX = boxX + boxW + 4;
      drawStepperButton("-", btnX, y - 14, 18, 18);
      drawStepperButton("+", btnX + 22, y - 14, 18, 18);
    } else if (id == 11) {
      // Pick Button for Albedo + Preview Swatch
      float btnX = boxX + boxW + 4;
      
      // Color Preview Swatch
      fill(p3deditor.this.scene.selectedEntities.get(0).material.albedo);
      stroke(100); strokeWeight(1);
      rect(btnX, y - 14, 18, 18, 3);
      
      drawStepperButton("Pick", btnX + 22, y - 14, 35, 18);
    }
  }

  void drawStepperButton(String label, float x, float y, float w, float h) {
    float ly = mouseY - inspectorScrollY;
    boolean hover = mouseX > x && mouseX < x + w && ly > y && ly < y + h;
    fill(hover ? 80 : 45); 
    noStroke();
    rect(x, y, w, h, 3);
    fill(255); textAlign(CENTER, CENTER); textSize(10);
    text(label, x + w/2, y + h/2 - 1);
    textAlign(LEFT, BASELINE);
  }

  void drawMapButton(String label, float x, float y, Entity e, String type) {
    boolean hasMap = false;
    if (type.equals("albedo")) hasMap = e.material.hasAlbedoMap;
    else if (type.equals("metallic")) hasMap = e.material.hasMetallicMap;
    else if (type.equals("roughness")) hasMap = e.material.hasRoughnessMap;
    
    float ly = mouseY - inspectorScrollY;
    boolean hover = mouseX > x && mouseX < x + 35 && ly > y && ly < y + 18;
    
    if (hasMap) fill(100, 200, 100); 
    else if (hover) fill(80, 80, 100);
    else fill(40, 40, 45);
    
    noStroke(); rect(x, y, 35, 18, 3);
    
    fill(255); textAlign(CENTER, CENTER); textSize(9);
    text(hasMap ? "ON" : label, x + 17, y + 9);
    textAlign(LEFT, BASELINE);
  }

  /**
   * render() - Main HUD Pass
   * 
   * [ALGORITHM] UI Layering & Clipping
   * Coordinates the drawing of all 2D elements. Uses depth-test disabling
   * and clipping rectangles to ensure sidebars and consoles don't overlap 
   * or bleed into the 3D viewport.
   */
  void render() {
    p3deditor.this.textFont(p3deditor.this.mainFont);
    textAlign(LEFT, BASELINE);
    if (!showUI) return;
    
    // 1. Conditionally render background UI elements
    if (debugConsole.active) {
      // If terminal is open, hide the top Menu Bar to prevent bleed-through line artifacts
      // and clip the sidebars to only show in the bottom half of the screen
      pushStyle();
      p3deditor.this.clip(0, p3deditor.this.height/2, width, height/2);
      renderHierarchy();
      renderInspector();
      p3deditor.this.noClip();
      popStyle();
    } else {
      renderMenuBar();
      renderHierarchy();
      renderInspector();
    }
    
    // 2. Overlays (Suppress top-half overlays when terminal is active to prevent artifacts)
    if (!debugConsole.active) {
      if (showStats) {
        renderStats();
        renderViewportStatus();
      }
      if (showConsole) renderConsole();
    }
    
    if (!activeMenu.equals("")) renderMenuDropdown();
    if (showContextMenu) renderContextMenu();
    
    // 3. Absolute Top Layer
    debugConsole.render(); 
  }
  
  /**
   * renderHierarchy() - Scene Graph Visualization
   * 
   * Renders the tree of entities. Effectively a recursive visitor pattern
   * that handles indentation, selection highlighting, and parent-child 
   * expand/collapse logic (future-proofed).
   */
  void renderHierarchy() {
    p3deditor.this.hint(p3deditor.this.DISABLE_DEPTH_TEST);
    p3deditor.this.resetShader();
    int listTopY = floor(menuBarHeight + 40); 
    int listBottomY = height - 30; // Leave space for Console
    pushStyle();
    // Sidebar Main Plate
    fill(25, 25, 28, 230); noStroke(); 
    rect(0, menuBarHeight, panelWidth, height - menuBarHeight);
    
    // Header Area
    fill(20, 20, 22, 230); noStroke();
    rect(0, menuBarHeight, panelWidth, 30);
    fill(180); textSize(11); textAlign(LEFT, CENTER);
    text("Hierarchy", 15, menuBarHeight + 15);
    stroke(60); line(0, menuBarHeight + 30, panelWidth, menuBarHeight + 30);
    
    // Vertical Divider
    stroke(60); line(panelWidth, menuBarHeight, panelWidth, height - 30);
    
    hierarchyRects.clear();
    float currentY = listTopY + scrollY;
    
    pushMatrix();
    // Clip the rendering to the hierarchy list area
    clip(0, listTopY, panelWidth, listBottomY - listTopY); 
    
    for (Entity e : scene.entities) {
      if (e.parent == null) {
        currentY = renderHierarchyNode(e, 0, currentY, listTopY, listBottomY);
      }
    }
    
    noClip();
    popMatrix();
    
    if (hierarchyDragSource != null && hasDraggedHierarchy) {
      fill(255, 150); textSize(12);
      text("Reparenting: " + hierarchyDragSource.name, mouseX + 15, mouseY);
      if (hierarchyDragTarget != null) {
        stroke(100, 200, 255); strokeWeight(2); noFill();
        for (HierarchyItemRect hr : hierarchyRects) {
          if (hr.entity == hierarchyDragTarget) { rect(5, hr.y, panelWidth - 10, 30, 4); break; }
        }
      }
    }
    
    renderScrollbar(listTopY, listBottomY);
    popStyle();
  }
  
  void renderMenuBar() {
    pushStyle();
    fill(25, 25, 28);
    noStroke();
    rect(0, 0, width, menuBarHeight);
    stroke(60); line(0, menuBarHeight-1, width, menuBarHeight-1);
    
    float x = 10;
    String[] menus = {"File", "Edit", "Create", "Window"};
    for (String m : menus) {
      float w = textWidth(m) + 30;
      boolean hover = mouseX > x && mouseX < x + w && mouseY < menuBarHeight;
      
      // Interaction Optimization: Switch menu if another is already open
      if (!activeMenu.isEmpty() && !activeMenu.equals(m) && hover) {
        activeMenu = m;
      }
      
      if (hover || activeMenu.equals(m)) {
        fill(60, 60, 70);
        rect(x, 2, w, menuBarHeight - 4, 4);
      }
      fill(220); textAlign(CENTER, CENTER); textSize(13);
      text(m, x + w / 2, menuBarHeight / 2);
      x += w;
    }
    
    // v2.0: Professional Mode Buttons
    float centerX = width / 2;
    if (scene.isPlaying()) {
      // STOP BUTTON
      float stopX = centerX - 30;
      boolean stopHover = mouseX > stopX && mouseX < stopX + 60 && mouseY < menuBarHeight && activeMenu.isEmpty();
      if (stopHover) fill(80, 80, 90); else fill(40, 40, 45);
      noStroke(); rect(stopX, 4, 60, menuBarHeight - 8, 4);
      fill(255, 100, 100); rect(stopX + 22, 10, 16, 12, 2);
      fill(255); textSize(9); textAlign(CENTER, CENTER); text("STOP", stopX + 30, menuBarHeight/2 + 7);
    } else {
      // SIMULATE BUTTON (Amber)
      float simX = centerX - 65;
      boolean simHover = mouseX > simX && mouseX < simX + 60 && mouseY < menuBarHeight && activeMenu.isEmpty();
      if (simHover) fill(80, 80, 90); else fill(45, 45, 55);
      noStroke(); rect(simX, 4, 60, menuBarHeight - 8, 4);
      fill(#FFB300); triangle(simX + 15, 9, simX + 15, 21, simX + 25, 15);
      fill(230); textSize(9); textAlign(CENTER, CENTER); text("SIMULATE", simX + 30, menuBarHeight/2 + 7);
      
      // PLAY BUTTON (Blue)
      float gameX = centerX + 5;
      boolean gameHover = mouseX > gameX && mouseX < gameX + 60 && mouseY < menuBarHeight && activeMenu.isEmpty();
      if (gameHover) fill(80, 80, 90); else fill(45, 45, 55);
      noStroke(); rect(gameX, 4, 60, menuBarHeight - 8, 4);
      fill(#4285F4); triangle(gameX + 15, 9, gameX + 15, 21, gameX + 25, 15);
      fill(230); textSize(9); textAlign(CENTER, CENTER); text("PLAY", gameX + 30, menuBarHeight/2 + 7);
    }
    popStyle();
  }
  
  void renderMenuDropdown() {
    String[] items = getItemsForMenu(activeMenu);
    
    if (items.length == 0) { activeMenu = ""; return; }
    
    float x = 10;
    String[] menus = {"File", "Edit", "Create", "Window"};
    for (String m : menus) {
      if (m.equals(activeMenu)) break;
      x += textWidth(m) + 30;
    }
    
    pushStyle();
    float w = 150;
    float h = items.length * 28 + 10;
    fill(35, 35, 40, 230); stroke(80);
    rect(x, menuBarHeight, w, h, 4);
    
    for (int i = 0; i < items.length; i++) {
      float iy = menuBarHeight + 5 + i * 28;
      boolean hover = mouseX > x && mouseX < x + w && mouseY > iy && mouseY < iy + 28;
      boolean enabled = isMenuActionEnabled(activeMenu, items[i]);
      
      if (hover && enabled) {
        fill(60, 80, 150); noStroke();
        rect(x + 2, iy, w - 4, 28, 4);
      }
      
      fill(enabled ? 230 : 100); 
      textAlign(LEFT, CENTER); textSize(12);
      text(items[i], x + 15, iy + 14);
    }
    popStyle();
  }
  
  void renderConsole() {
    p3deditor.this.hint(p3deditor.this.DISABLE_DEPTH_TEST);
    p3deditor.this.resetShader();
    pushStyle();
    float consoleH = 30;
    float yY = height - consoleH;
    
    // Background bar
    fill(25, 25, 28); noStroke();
    rect(0, yY, width, consoleH);
    stroke(60); line(0, yY, width, yY); 
    
    // Command Prompt
    fill(100, 255, 100);
    textAlign(LEFT, CENTER);
    textSize(12);
    text("> ", 15, yY + consoleH/2);
    
    // Current Input
    if (activeEditTarget == 99) {
      fill(255, 255, 0);
      text(activeEditString + (frameCount % 60 < 30 ? "_" : ""), 35, yY + consoleH/2);
    } else {
      fill(120);
      text("Type a command (e.g. 'move Cube 10 0 0') or press 'Enter'...", 35, yY + consoleH/2);
    }
    
    // Last Result
    if (consoleResult != null && !consoleResult.isEmpty()) {
       textAlign(RIGHT, CENTER);
       fill(consoleResult.startsWith("Error") ? color(255, 100, 100) : color(150, 200, 255));
       text(consoleResult, width - 20, height - 15);
    }
    popStyle();
  }
  
  void renderStats() {
    int totalPolys = 0;
    for (Entity e : scene.entities) totalPolys += e.getPolyCount();
    
    float x = 270;
    float y = 45 + menuBarHeight;
    textAlign(LEFT, TOP);
    textSize(12);
    
    // Background plate (smaller and aligned to top-left)
    noStroke();
    fill(0, 100);
    rect(x - 5, y - 5, 140, 60, 5);
    
    fill(200);
    text("FPS: " + nf(frameRate, 0, 1), x, y);
    text("Objects: " + scene.entities.size(), x, y + 15);
    text("Polygons: " + totalPolys, x, y + 30);
    
    textAlign(LEFT, BASELINE); // Reset alignment
  }

  void renderScrollbar(int listTopY, int listBottomY) {
    float listHeight = listBottomY - listTopY;
    totalContentHeight = hierarchyRects.size() * 30;
    if (totalContentHeight > listHeight) {
      float thumbHeight = max(20, listHeight * (listHeight / totalContentHeight));
      float maxScroll = totalContentHeight - listHeight;
      float p = -scrollY / maxScroll;
      float thumbY = listTopY + p * (listHeight - thumbHeight);
      fill(30, 30, 30, 150); rect(panelWidth - 12, listTopY, 8, listHeight, 4);
      if (isDraggingScrollbar) fill(100, 180, 255);
      else if (mouseX > panelWidth - 16 && mouseX < panelWidth && mouseY > thumbY && mouseY < thumbY + thumbHeight) fill(150);
      else fill(100);
      rect(panelWidth - 12, thumbY, 8, thumbHeight, 4);
    }
  }

  float renderHierarchyNode(Entity e, int depth, float y, int listTop, int listBot) {
    float itemH = 30;
    hierarchyRects.add(new HierarchyItemRect(e, y));
    if (y >= listTop - itemH && y <= listBot) {
      boolean isHover = mouseX < panelWidth && mouseY >= y && mouseY < y + itemH;
      if (scene.selectedEntities.contains(e)) { 
        fill(80, 130, 200); rect(0, y, panelWidth, itemH); 
      } else if (isHover) {
        fill(60, 60, 70); rect(0, y, panelWidth, itemH);
      }
      
      fill(255);
      textSize(13);
      float indent = 20 + depth * 20;
      if (depth > 0) {
        stroke(100);
        line(indent - 10, y + itemH/2, indent - 10, y - itemH/2 + 5); 
        line(indent - 10, y + itemH/2, indent - 5, y + itemH/2);
      }
      noStroke();
      textAlign(LEFT, CENTER);
      
      float maxWidth = panelWidth - indent - 15;
      String displayName = truncateString(e.name, maxWidth);
      
      // Draw truncated text perfectly centered
      text(displayName, indent, y + itemH/2 - 2);
    }
    float nextY = y + itemH;
    for (Entity child : e.children) {
      nextY = renderHierarchyNode(child, depth + 1, nextY, listTop, listBot);
    }
    return nextY;
  }

  /**
   * renderInspector() - Property Editor
   * 
   * Dynamically generates UI widgets (text fields, steppers, color swatches)
   * based on the type of the selected entity. Supports vertical scrolling
   * for entities with many properties (like PointLights or PBR materials).
   */
  void renderInspector() {
    p3deditor.this.hint(p3deditor.this.DISABLE_DEPTH_TEST);
    p3deditor.this.resetShader();
    if (scene.selectedEntities.isEmpty()) {
      renderGlobalSettings();
      return;
    }
    float panelX = width - panelWidth;
    pushStyle();
    // Sidebar Main Plate
    fill(25, 25, 28, 230); noStroke(); 
    rect(panelX, menuBarHeight, panelWidth, height - menuBarHeight);
    
    // Header Area
    fill(20, 20, 22, 230); noStroke(); 
    rect(panelX, menuBarHeight, panelWidth, 30);
    fill(180); textSize(11); textAlign(LEFT, CENTER);
    text("Inspector", panelX + 15, menuBarHeight + 15);
    stroke(60); line(panelX, menuBarHeight + 30, width, menuBarHeight + 30);
    
    // Vertical Divider
    stroke(60); line(panelX, menuBarHeight, panelX, height - 30);
    
    // v0.5.0: Add clipping and scrolling for Inspector
    p3deditor.this.hint(p3deditor.this.DISABLE_DEPTH_TEST);
    p3deditor.this.clip(panelX, menuBarHeight + 30, panelWidth, height - (menuBarHeight + 30) - 30);
    pushMatrix();
    translate(0, inspectorScrollY);
    
    if (scene.selectedEntities.size() == 1) {
      Entity e = scene.selectedEntities.get(0);
      drawEditField("Name: ", e.name, 1, panelX + 15, 70);
      fill(255); textSize(12); text("Type: " + e.type, panelX + 15, 95); 
      
      // v1.5: Visibility Toggle (Checkbox)
      float toggleX = panelX + 130;
      float toggleY = 82;
      stroke(100); noFill();
      rect(toggleX, toggleY, 14, 14, 2);
      if (e.visible) {
        fill(100, 255, 100); noStroke();
        rect(toggleX + 3, toggleY + 3, 8, 8, 1);
      }
      fill(150); textSize(11); text("Visible", toggleX + 20, toggleY + 11);
      
      fill(255); textSize(12); text("ID: " + e.id, panelX + 15, 120);
      if (e.parent != null) fill(150, 200, 255); else fill(150);
      text("Parent: " + (e.parent != null ? e.parent.name : "None"), panelX + 15, 140);
      fill(180, 255, 180); text("Position (Local)", panelX + 15, 175);
      drawEditField("X: ", String.format(java.util.Locale.US, "%.1f", e.transform.position.x), 2, panelX + 25, 200);
      drawEditField("Y: ", String.format(java.util.Locale.US, "%.1f", e.transform.position.y), 3, panelX + 25, 220);
      drawEditField("Z: ", String.format(java.util.Locale.US, "%.1f", e.transform.position.z), 4, panelX + 25, 240);
      fill(180, 255, 180); text("Rotation (deg)", panelX + 15, 280);
      drawEditField("X: ", String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.x)), 5, panelX + 25, 305);
      drawEditField("Y: ", String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.y)), 6, panelX + 25, 325);
      drawEditField("Z: ", String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.z)), 7, panelX + 25, 345);
      fill(180, 255, 180); text("Scale", panelX + 15, 385);
      drawEditField("X: ", String.format(java.util.Locale.US, "%.1f", e.transform.scale.x), 8, panelX + 25, 410);
      drawEditField("Y: ", String.format(java.util.Locale.US, "%.1f", e.transform.scale.y), 9, panelX + 25, 430);
      drawEditField("Z: ", String.format(java.util.Locale.US, "%.1f", e.transform.scale.z), 10, panelX + 25, 450);
      
      fill(180, 255, 180); text("Material", panelX + 15, 490);
      drawEditField("Albedo: #", hex(e.material.albedo, 6), 11, panelX + 25, 515);
      
      float mapBtnX = panelX + 205;
      drawMapButton("Map", mapBtnX, 501, e, "albedo");
      
      drawEditField("Metallic: ", String.format(java.util.Locale.US, "%.2f", e.material.metallic), 14, panelX + 25, 535);
      drawMapButton("Map", mapBtnX, 521, e, "metallic");
      
      drawEditField("Roughness: ", String.format(java.util.Locale.US, "%.2f", e.material.roughness), 15, panelX + 25, 555);
      drawMapButton("Map", mapBtnX, 541, e, "roughness");
      
      if (e.type.equals("PointLight")) {
        fill(180, 255, 180); text("Light Settings", panelX + 15, 585);
        drawEditField("Intensity: ", String.format(java.util.Locale.US, "%.1f", e.lightIntensity), 12, panelX + 25, 610);
        drawEditField("Range: ", String.format(java.util.Locale.US, "%.0f", e.lightRange), 13, panelX + 25, 630);
      }
      
      // v0.5.0: Events Section
      fill(180, 180, 255); text("Events & Scripts", panelX + 15, 665);
      
      // Mount Script [+] Button
      float btnX = panelX + 130;
      float lyBtn = mouseY - inspectorScrollY;
      boolean mountHover = mouseX > btnX && mouseX < btnX + 22 && lyBtn > 651 && lyBtn < 671;
      if (mountHover) fill(100, 150, 255); else fill(60, 60, 80);
      rect(btnX, 651, 22, 20, 4);
      fill(255); textAlign(CENTER, CENTER); textSize(14); text("+", btnX + 11, 660);
      textAlign(LEFT, BASELINE);
      textSize(12);
      
      float evtY = 690;
      if (e.eventHandlers.isEmpty()) {
        fill(100); textSize(12); text("(No events mounted)", panelX + 25, evtY);
      } else {
        ArrayList<String> sortedTypes = new ArrayList<String>(e.eventHandlers.keySet());
        java.util.Collections.sort(sortedTypes);
        for (String evtType : sortedTypes) {
          fill(200); textSize(12); text(evtType + ":", panelX + 25, evtY);
          evtY += 15;
          for (String script : e.eventHandlers.get(evtType)) {
            fill(150, 150, 255); text("  - " + script, panelX + 25, evtY);
            
            float btnx = width - 40;
            float btnLy = mouseY - inspectorScrollY;
            boolean unmountHover = mouseX > btnx && mouseX < btnx + 16 && btnLy > evtY - 10 && btnLy < evtY + 6;
            if (unmountHover) fill(200, 80, 80); else fill(60, 60, 80);
            rect(btnx, evtY - 10, 14, 14, 3);
            fill(255); textAlign(CENTER, CENTER); textSize(10); text("X", btnx + 7, evtY - 3);
            textAlign(LEFT, BASELINE); textSize(12);
            
            evtY += 15;
          }
          evtY += 5;
        }
      }
      
      // v0.9.0: Blueprint Section
      fill(180, 180, 255); text("Blueprint Logic", panelX + 15, evtY + 30);
      float bpBtnY = evtY + 45;
      float bpBtnW = 100;
      boolean bpHover = mouseX > panelX + 25 && mouseX < panelX + 25 + bpBtnW && (mouseY - inspectorScrollY) > bpBtnY && (mouseY - inspectorScrollY) < bpBtnY + 20;
      if (bpHover) fill(100, 120, 200); else fill(45, 45, 55);
      rect(panelX + 25, bpBtnY, bpBtnW, 20, 4);
      fill(255); textAlign(CENTER, CENTER); textSize(10);
      text("Edit Blueprint", panelX + 25 + bpBtnW/2, bpBtnY + 10);
      textAlign(LEFT, BASELINE);
      
      inspectorTotalHeight = bpBtnY + 40;
    } else {
      fill(255); textSize(14); text(scene.selectedEntities.size() + " Objects Selected", panelX + 15, 70);
      inspectorTotalHeight = 100;
    }
    
    // Help and Instructions - Moved out of Inspector to viewport bottom-right
    popMatrix(); // End scroll translate
    p3deditor.this.noClip();
    
    // Render Inspector Scrollbar
    float listHeight = height; 
    if (inspectorTotalHeight > listHeight) {
      float thumbHeight = max(20, listHeight * (listHeight / inspectorTotalHeight));
      float maxScroll = inspectorTotalHeight - listHeight;
      float p = -inspectorScrollY / maxScroll;
      float thumbY = p * (listHeight - thumbHeight);
      
      fill(30, 30, 30, 150); rect(width - 12, 0, 8, listHeight, 4);
      if (isDraggingInspectorScroll) fill(100, 180, 255);
      else if (mouseX > width - 16 && mouseY > thumbY && mouseY < thumbY + thumbHeight) fill(150);
      else fill(100);
      rect(width - 12, thumbY, 8, thumbHeight, 4);
    }
    
    p3deditor.this.hint(p3deditor.this.ENABLE_DEPTH_TEST);
  }
  
  void renderOverlayInstructions() {
    float x = width - panelWidth - 20;
    float y = height - 60;
    if (debugConsole.active) return;
    pushStyle();
    textAlign(RIGHT, BOTTOM);
    fill(255, 180); textSize(12);
    text("Right-Click for Menu", x, y);
    text("Delete: Backspace / Del", x, y + 20);
    popStyle();
  }
  
  void renderContextMenu() {
    p3deditor.this.hint(p3deditor.this.DISABLE_DEPTH_TEST);
    p3deditor.this.noClip();
    float w = 120;
    float h = 100;
    strokeWeight(1);
    fill(40, 240); stroke(80); rect(menuX, menuY, w, h, 4);
    String[] items = {"Copy", "Paste", "Unparent", "Delete"};
    boolean canUnparent = false;
    for (Entity e : scene.selectedEntities) if (e.parent != null) canUnparent = true;
    boolean[] enabled = {!scene.selectedEntities.isEmpty(), !clipboard.isEmpty(), canUnparent, !scene.selectedEntities.isEmpty()};
    for (int i=0; i<items.length; i++) {
      float itemY = menuY + i*25;
      boolean isHover = mouseX > menuX && mouseX < menuX + w && mouseY > itemY && mouseY < itemY + 25;
      if (enabled[i]) {
        if (isHover) { fill(80, 130, 200); rect(menuX + 2, itemY + 2, w - 4, 21, 2); }
        fill(255);
      } else { fill(100); }
      textSize(12); text(items[i], menuX + 10, itemY + 17);
    }
  }
  
  boolean handleMousePressed() {
    if (!showUI) return false;
    
    // 0. Menu Bar Selection
    if (mouseY < menuBarHeight) {
      // v2.0: Multi-Mode Toolbar Hits
      float centerX = width / 2;
      if (p3deditor.this.scene.isPlaying()) {
        float stopX = centerX - 30;
        if (mouseX > stopX && mouseX < stopX + 60) {
          p3deditor.this.interpreter.execute("stop");
          return true;
        }
      } else {
        float simX = centerX - 65;
        if (mouseX > simX && mouseX < simX + 60) {
          p3deditor.this.interpreter.execute("play simulate");
          return true;
        }
        float gameX = centerX + 5;
        if (mouseX > gameX && mouseX < gameX + 60) {
          p3deditor.this.interpreter.execute("play game");
          return true;
        }
      }
      
      float x = 10;
      String[] menus = {"File", "Edit", "Create", "Window"};
      for (String m : menus) {
        float w = textWidth(m) + 30;
        if (mouseX > x && mouseX < x + w) {
          if (activeMenu.equals(m)) activeMenu = "";
          else activeMenu = m;
          return true;
        }
        x += w;
      }
      activeMenu = "";
      return true;
    }
    
    // 1. Dropdown Item Click
    if (!activeMenu.equals("")) {
      float dropX = 10;
      String[] mainMenus = {"File", "Edit", "Create", "Window"};
      for (String m : mainMenus) {
        if (m.equals(activeMenu)) break;
        dropX += textWidth(m) + 30;
      }
      
      String[] items = getItemsForMenu(activeMenu);
      float dropW = 150;
      for (int i = 0; i < items.length; i++) {
        float iy = menuBarHeight + 5 + i * 28;
        if (mouseX > dropX && mouseX < dropX + dropW && mouseY > iy && mouseY < iy + 28) {
          executeMenuAction(activeMenu, items[i]);
          activeMenu = ""; return true;
        }
      }
      activeMenu = ""; return true;
    }
    
    float pX = width - panelWidth;
    if (showContextMenu) {
      if (mouseX > menuX && mouseX < menuX + 120 && mouseY > menuY && mouseY < menuY + 100) {
        int idx = floor((mouseY - menuY) / 25.0f);
        boolean canUnp = false;
        for (Entity e : scene.selectedEntities) if (e.parent != null) canUnp = true;
        boolean[] en = { !scene.selectedEntities.isEmpty(), !clipboard.isEmpty(), canUnp, !scene.selectedEntities.isEmpty() };
        if (en[idx]) {
          if (idx == 0) copySelection(); else if (idx == 1) pasteClipboard();
          else if (idx == 2) unparentSelection(); else if (idx == 3) deleteSelection();
        }
        showContextMenu = false; return true;
      }
      showContextMenu = false;
    }
    
    if (showUI && showConsole && mouseY > height - 30) {
      activeEditTarget = 99; activeEditString = ""; 
      return true; 
    }
    
    if (mouseX > pX) {
      activeEditTarget = -1; // Deselect any active field if clicking background 
      
      // 3. Inspector Scrollbar Hit Test
      if (inspectorTotalHeight > (height - menuBarHeight - 60) && mouseX > width - 20) {
        float listHeight = height - menuBarHeight - 60;
        float thumbHeight = max(20, listHeight * (listHeight / inspectorTotalHeight));
        float maxScroll = inspectorTotalHeight - listHeight;
        float thumbYPos = menuBarHeight + 30 + (-inspectorScrollY/maxScroll)*(listHeight-thumbHeight);
        
        if (mouseY >= thumbYPos && mouseY <= thumbYPos + thumbHeight) {
          isDraggingInspectorScroll = true; inspectorDragThumbY = mouseY - thumbYPos;
        } else {
          float newThumbTop = constrain(mouseY - menuBarHeight - 30 - thumbHeight/2.0f, 0, listHeight - thumbHeight);
          inspectorScrollY = -((newThumbTop / (listHeight - thumbHeight)) * maxScroll);
          isDraggingInspectorScroll = true; inspectorDragThumbY = thumbHeight/2.0f;
        }
        return true;
      }
      
      if (!scene.selectedEntities.isEmpty()) {
        checkInspectorClicks();
      } else {
        checkGlobalSettingsClicks();
      }
      
      return true; // BREAK: Block all scene interaction through the Inspector panel
    }
    
    if (mouseX < panelWidth || mouseX > pX) {
      if (mouseButton == RIGHT) {
        if (mouseX < panelWidth) {
           for (HierarchyItemRect hr : hierarchyRects) {
              if (mouseY > hr.y && mouseY < hr.y + 30) { scene.selectEntity(hr.entity, isCtrlDown); break; }
           }
        }
        showContextMenu = true; menuX = mouseX; menuY = mouseY; return true;
      }
      
      if (mouseX < panelWidth) {
        if (!showUI) return false;
        int listTopY = 50; int listBottomY = height - 120;
        float listHeight = listBottomY - listTopY;
        totalContentHeight = hierarchyRects.size() * 30;
        
        // 1. Scrollbar Hit Test (MUST be done before items to avoid conflict)
        if (totalContentHeight > listHeight && mouseX > panelWidth - 20) {
          if (mouseY >= listTopY && mouseY <= listBottomY) {
            float thumbHeight = max(20, listHeight * (listHeight / totalContentHeight));
            float maxScroll = totalContentHeight - listHeight;
            float thumbYPos = listTopY + (-scrollY/maxScroll)*(listHeight-thumbHeight);
            if (mouseY >= thumbYPos && mouseY <= thumbYPos + thumbHeight) {
              isDraggingScrollbar = true; dragThumbOffsetY = mouseY - thumbYPos;
            } else {
              float newThumbTop = constrain(mouseY - thumbHeight/2.0f, listTopY, listBottomY - thumbHeight);
              scrollY = -((newThumbTop - listTopY) / (listHeight - thumbHeight) * maxScroll);
              isDraggingScrollbar = true; dragThumbOffsetY = thumbHeight/2.0f;
            }
            return true;
          }
        }
        
        // 2. Hierarchy Items
        if (mouseY >= listTopY && mouseY <= listBottomY) {
          for (HierarchyItemRect hr : hierarchyRects) {
            if (mouseY >= hr.y && mouseY <= hr.y + 30) {
              scene.selectEntity(hr.entity, isCtrlDown);
              hierarchyDragSource = hr.entity; 
              hierarchyDragStartX = mouseX; hierarchyDragStartY = mouseY; hasDraggedHierarchy = false;
              return true;
            }
          }
          return true; 
        }
        return true;
      }
      if (!scene.selectedEntities.isEmpty() && mouseX > width - panelWidth) { checkInspectorClicks(); return true; }
    }
    return false;
  }
  
  void checkInspectorClicks() {
    if (scene.selectedEntities.size() != 1) return;
    Entity e = scene.selectedEntities.get(0);
    int hitId = 0; String startVal = "";
    
    // Account for scrolling
    float iy = mouseY - inspectorScrollY;
    float inspX = width - panelWidth;
    
    // Check Visibility Toggle Hit (v1.5)
    if (iy > 82 && iy < 96 && mouseX > inspX + 130 && mouseX < inspX + 130 + 14) {
      e.visible = !e.visible;
      return;
    }

    // v0.9.0: Blueprint Editor Button Hit (Check early, using standard for loop for safety)
    Object[] handlerKeys = e.eventHandlers.keySet().toArray();
    float currentEvtY = 690;
    for (int i = 0; i < handlerKeys.length; i++) {
        String k = (String)handlerKeys[i];
        currentEvtY += 15 + (e.eventHandlers.get(k).size() * 15) + 5;
    }
    float hitBtnY = currentEvtY + 45;
    if (mouseX > inspX + 25 && mouseX < inspX + 25 + 100 && iy > hitBtnY && iy < hitBtnY + 20) {
        Blueprint bpToOpen = e.blueprint;
        this.vlbEditor.activeBlueprint = bpToOpen;
        this.vlbEditor.visible = true;
        return;
    }
    
    // Check Event Script Mount [+] Button
    if (iy > 651 && iy < 671) {
      float btnX = (width - panelWidth) + 130;
      if (mouseX > btnX && mouseX < btnX + 22) {
        final Entity targetEnt = e;
        new Thread(new Runnable() {
          public void run() {
            Object[] options = {"onClick", "Start", "Update", "onHover"};
            javax.swing.JOptionPane pane = new javax.swing.JOptionPane("Select Event Type:", javax.swing.JOptionPane.QUESTION_MESSAGE, javax.swing.JOptionPane.OK_CANCEL_OPTION);
            pane.setWantsInput(true);
            pane.setSelectionValues(options);
            pane.setInitialSelectionValue("onClick");
            javax.swing.JDialog dialog = pane.createDialog(null, "Mount Script");
            dialog.setAlwaysOnTop(true);
            dialog.setVisible(true);
            
            Object value = pane.getInputValue();
            if (value != javax.swing.JOptionPane.UNINITIALIZED_VALUE && value != null) {
               String evt = value.toString();
               p3deditor.this.scriptMountTarget = targetEnt;
               p3deditor.this.scriptMountEvent = evt;
               p3deditor.this.selectInput("Select a .p3des script to mount:", "fileSelectedForScript");
            }
          }
        }).start();
        return;
      }
    }
    
    // Check Unmount [X] Buttons
    float evtY = 690;
    ArrayList<String> sortedTypes = new ArrayList<String>(e.eventHandlers.keySet());
    java.util.Collections.sort(sortedTypes);
    for (String evtType : sortedTypes) {
      evtY += 15;
      for (int i = 0; i < e.eventHandlers.get(evtType).size(); i++) {
        float btnx = width - 40;
        if (iy > evtY - 10 && iy < evtY + 6 && mouseX > btnx && mouseX < btnx + 16) {
           String unmountedScript = e.eventHandlers.get(evtType).get(i);
           e.eventHandlers.get(evtType).remove(i);
           if (e.eventHandlers.get(evtType).isEmpty()) {
              e.eventHandlers.remove(evtType);
           }
           p3deditor.this.ui.debugConsole.addLog("Unmounted script '" + unmountedScript + "' from " + e.name + " (" + evtType + ")", 2);
           return;
        }
        evtY += 15;
      }
      evtY += 5;
    }
    
    float lX = inspX + 25; // Base X for fields in renderInspector
    
    // Helper lambda-like check for field hits
    // id 1: 70, 2-4: 200,220,240, 5-7: 305,325,345, 8-10: 410,430,450, 11: 515, 14,15: 535,555
    // 12,13: 610,630
    
    if (iy > 55 && iy <= 75) { hitId = 1; startVal = e.name; }
    else if (iy > 185 && iy <= 205) { hitId = 2; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.x); }
    else if (iy > 205 && iy <= 225) { hitId = 3; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.y); }
    else if (iy > 225 && iy <= 245) { hitId = 4; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.z); }
    else if (iy > 290 && iy <= 310) { hitId = 5; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.x)); }
    else if (iy > 310 && iy <= 330) { hitId = 6; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.y)); }
    else if (iy > 330 && iy <= 350) { hitId = 7; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.z)); }
    else if (iy > 395 && iy <= 415) { hitId = 8; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.x); }
    else if (iy > 415 && iy <= 435) { hitId = 9; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.y); }
    else if (iy > 435 && iy <= 455) { hitId = 10; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.z); }
    else if (iy > 495 && iy <= 525) { 
       // Check if clicked the "Pick" button instead of the hex box
       float boxX = lX + 85;
       float boxW = 65;
       float pickBtnX = boxX + boxW + 4; 
       if (mouseX > pickBtnX && mouseX < pickBtnX + 20) {
         final Entity targetE = e;
         new Thread(new Runnable() {
           public void run() {
             java.awt.Color initial = new java.awt.Color((int)p3deditor.this.red(targetE.material.albedo), (int)p3deditor.this.green(targetE.material.albedo), (int)p3deditor.this.blue(targetE.material.albedo));
             
             // Create a non-blocking dialog that stays on top
             javax.swing.JColorChooser chooser = new javax.swing.JColorChooser(initial);
             javax.swing.JDialog dialog = javax.swing.JColorChooser.createDialog(null, "Select Albedo Color", false, chooser, 
               new java.awt.event.ActionListener() {
                 public void actionPerformed(java.awt.event.ActionEvent e) {
                   java.awt.Color selected = chooser.getColor();
                   if (selected != null) {
                     targetE.material.albedo = color(selected.getRed(), selected.getGreen(), selected.getBlue());
                     targetE.col = targetE.material.albedo;
                   }
                 }
               }, null);
             dialog.setAlwaysOnTop(true);
             dialog.setVisible(true);
           }
         }).start();
         return;
       }
       hitId = 11; startVal = hex(e.material.albedo, 6); 
    }
    else if (iy > 525 && iy <= 545) { hitId = 14; startVal = String.format(java.util.Locale.US, "%.2f", e.material.metallic); }
    else if (iy > 545 && iy <= 565) { hitId = 15; startVal = String.format(java.util.Locale.US, "%.2f", e.material.roughness); }
    
    // Check Map Buttons
    float mapBtnX = (width - panelWidth) + 205;
    if (mouseX > mapBtnX && mouseX < mapBtnX + 65) {
      boolean isToggle = mouseX > mapBtnX + 38;
      
      if (iy > 501 && iy < 519) {
        if (isToggle) e.material.hasAlbedoMap = !e.material.hasAlbedoMap;
        else {
          p3deditor.this.scriptMountTarget = e; 
          p3deditor.this.selectInput("Select Albedo Texture:", "albedoMapSelected");
        }
        return;
      }
      if (iy > 521 && iy < 539) {
        if (isToggle) e.material.hasMetallicMap = !e.material.hasMetallicMap;
        else {
          p3deditor.this.scriptMountTarget = e; 
          p3deditor.this.selectInput("Select Metallic Texture:", "metallicMapSelected");
        }
        return;
      }
      if (iy > 541 && iy < 559) {
        if (isToggle) e.material.hasRoughnessMap = !e.material.hasRoughnessMap;
        else {
          scriptMountTarget = e; 
          selectInput("Select Roughness Texture:", "roughnessMapSelected");
        }
        return;
      }
    }
    else if (e.type.equals("PointLight")) {
       if (iy > 600 && iy <= 620) { hitId = 12; startVal = String.format(java.util.Locale.US, "%.1f", e.lightIntensity); }
       else if (iy > 620 && iy <= 640) { hitId = 13; startVal = String.format(java.util.Locale.US, "%.0f", e.lightRange); }
    }
    
    // Process Stepper Hits
    if (hitId > 1 && hitId != 11) {
       float boxX = lX + 85;
       float boxW = (hitId == 1) ? 65 : 50; // Although hitId 1 is Name, handled separately
       float btnX = boxX + boxW + 4;
       if (mouseX > btnX && mouseX < btnX + 18) { handleStepperHit(e, hitId, -1); return; }
       if (mouseX > btnX + 22 && mouseX < btnX + 40) { handleStepperHit(e, hitId, 1); return; }
    }
    
    if (hitId > 0) { activeEditTarget = hitId; activeEditString = startVal; }
    else commitEdit();
  }
  
  void copySelection() {
    if (scene.selectedEntities.isEmpty()) return;
    clipboard.clear();
    for (Entity sel : scene.selectedEntities) clipboard.add(sel.cloneEntity(-1, sel.name)); 
  }
  
  void pasteClipboard() {
    if (clipboard.isEmpty()) return;
    scene.clearSelection();
    for (Entity clipE : clipboard) {
      clipE.transform.position.x += 15; clipE.transform.position.z += 15;
      Entity ne = clipE.cloneEntity(scene.nextEntityId++, clipE.name + " Copy");
      scene.addEntityToSceneRecursive(ne);
      scene.selectEntity(ne, true);
      scene.undoManager.push(new AddEntityCommand(scene, ne));
    }
  }
  
  void unparentSelection() {
    for (Entity e : scene.selectedEntities) {
      if (e.parent != null) {
        scene.undoManager.push(new ReparentCommand(scene, e, e.parent, null));
        e.setParent(null, true);
      }
    }
  }
  
  void deleteSelection() {
    if (scene.selectedEntities.isEmpty()) return;
    scene.undoManager.push(new DeleteEntityCommand(scene, scene.selectedEntities));
    debugConsole.addLog("Deleted " + scene.selectedEntities.size() + " entities", 0);
    for (Entity e : new ArrayList<Entity>(scene.selectedEntities)) {
      if (e.parent != null) e.parent.children.remove(e);
      scene.entities.remove(e);
    }
    scene.clearSelection();
  }
  
  void handleMouseDragged() {
    if (isDraggingInspectorScroll) {
      float listHeight = height;
      float thumbHeight = max(20, listHeight * (listHeight / inspectorTotalHeight));
      float maxScroll = inspectorTotalHeight - listHeight;
      float newThumbTop = constrain(mouseY - inspectorDragThumbY, 0, listHeight - thumbHeight);
      inspectorScrollY = -((newThumbTop / (listHeight - thumbHeight)) * maxScroll);
    }
    
    if (hierarchyDragSource != null) {
      if (dist(mouseX, mouseY, hierarchyDragStartX, hierarchyDragStartY) > 5) hasDraggedHierarchy = true;
      if (!hasDraggedHierarchy) return;
      hierarchyDragTarget = null;
      if (mouseX < panelWidth) {
        for (HierarchyItemRect hr : hierarchyRects) {
          if (mouseY > hr.y && mouseY < hr.y + 30) {
            if (hr.entity != hierarchyDragSource && !isDescendant(hierarchyDragSource, hr.entity)) hierarchyDragTarget = hr.entity;
            break;
          }
        }
      }
    }
  }
  
  void handleMouseReleased() {
    isDraggingInspectorScroll = false;
    if (hierarchyDragSource != null && hasDraggedHierarchy) {
      Entity oldP = hierarchyDragSource.parent;
      Entity newP = null;
      if (mouseX < panelWidth && hierarchyDragTarget != null) newP = hierarchyDragTarget;
      
      if (newP != oldP) {
        scene.undoManager.push(new ReparentCommand(scene, hierarchyDragSource, oldP, newP));
        if (newP != null) newP.addChild(hierarchyDragSource);
        else hierarchyDragSource.setParent(null, true);
      }
    }
    hierarchyDragSource = null; hierarchyDragTarget = null;
  }
  
  boolean isDescendant(Entity parent, Entity potential) {
    Entity p = potential.parent;
    while (p != null) { if (p == parent) return true; p = p.parent; }
    return false;
  }
  


  void drawButton(String label, float x, float y, float w, float h, color base) {
    pushStyle();
    boolean hover = mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
    fill(hover ? lerpColor(base, color(255), 0.2f) : base);
    noStroke();
    rect(x, y, w, h, 5);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(12);
    text(label, x + w/2, y + h/2);
    popStyle();
  }
  
  String[] getItemsForMenu(String menu) {
    if (menu.equals("File")) return new String[]{"New Scene", "Load Scene", "Save Scene", "Load Env Map", "Build Standalone"};
    else if (menu.equals("Edit")) return new String[]{"Undo  [Ctrl+Z]", "Redo  [Ctrl+Y]", "Delete [Del]"};
    else if (menu.equals("Create")) return new String[]{"Cube", "Sphere", "Plane", "Point Light", "Import OBJ"};
    else if (menu.equals("Window")) return new String[]{"Toggle Console", "Toggle Stats", "Reset Camera"};
    return new String[]{};
  }
  
  boolean isMenuActionEnabled(String menu, String item) {
    if (menu.equals("Edit")) {
      if (item.contains("Undo")) return !scene.undoManager.undoStack.isEmpty();
      if (item.contains("Redo")) return !scene.undoManager.redoStack.isEmpty();
      if (item.contains("Delete")) return !scene.selectedEntities.isEmpty();
    }
    return true;
  }

  void executeMenuAction(String menu, String item) {
    if (!isMenuActionEnabled(menu, item)) return;
    
    if (item.contains("New Scene")) {
      scene.entities.clear(); scene.clearSelection();
    } else if (item.contains("Load Scene")) {
      selectInput("Load Scene:", "fileSelectedForLoad");
    } else if (item.contains("Save Scene")) {
      p3deditor.this.selectOutput("Save Scene:", "fileSelectedForSave");
    } else if (item.contains("Build Standalone")) {
      p3deditor.this.selectFolder("Select Export Directory:", "folderSelectedForBuild");
    } else if (item.contains("Export")) {
       saveFrame("exports/screenshot-####.png");
       consoleResult = "SUCCESS: Exported screenshot";
    } else if (item.contains("Load Env Map")) {
      p3deditor.this.selectInput("Select Global Environment Map:", "envMapSelected");
    } else if (item.contains("Undo")) {
      scene.undoManager.undo();
    } else if (item.contains("Redo")) {
      scene.undoManager.redo();
    } else if (item.contains("Delete")) {
      deleteSelection();
    } else if (item.equals("Cube")) {
      scene.addEntity("Cube", "Cube");
      debugConsole.addLog("Created Cube", 0);
    } else if (item.equals("Sphere")) {
      scene.addEntity("Sphere", "Sphere");
      debugConsole.addLog("Created Sphere", 0);
    } else if (item.equals("Plane")) {
      scene.addEntity("Plane", "Plane");
      debugConsole.addLog("Created Plane", 0);
    } else if (item.equals("Point Light")) {
      int count = 0;
      for(Entity e : scene.entities) if(e.type.equals("PointLight")) count++;
      if (count < 5) {
        scene.addEntity("Point Light", "PointLight");
        debugConsole.addLog("Created PointLight", 0);
      }
    } else if (item.contains("Import OBJ")) {
      Entity ne = new Entity(scene.nextEntityId++, "Model", "Model");
      scene.entities.add(ne);
      scene.selectEntity(ne, false);
      p3deditor.this.scriptMountTarget = ne;
      p3deditor.this.selectInput("Select OBJ Model:", "modelSelected");
    } else if (item.contains("Console")) {
      showConsole = !showConsole;
      if (!showConsole && activeEditTarget == 99) activeEditTarget = 0;
    } else if (item.contains("Stats")) {
      showStats = !showStats;
    } else if (item.contains("Reset Camera")) {
      editorCamera.reset();
    }
  }
  
  String truncateString(String s, float maxWidth) {
    if (textWidth(s) <= maxWidth) return s;
    String res = s;
    while (res.length() > 0 && textWidth(res + "...") > maxWidth) {
      res = res.substring(0, res.length() - 1);
    }
    return res + "...";
  }
  
  void handleKeyPressed() {
    // If we're editing an inspector field (not the console), prioritize it and block console keys (except backtick)
    if (isEditingText() && activeEditTarget != 99) {
      if (key == '`') { debugConsole.handleKey(key, keyCode); return; } // Allow console toggle
      handleTextEditKey();
      return;
    }
    
    // Otherwise, handle console keys first
    debugConsole.handleKey(key, keyCode);
    
    // If the console is the active edit target, handle its typing
    if (activeEditTarget == 99) {
      handleTextEditKey();
      return;
    }
    
    // Fallback shortcuts
    if (!debugConsole.active && !isEditingText()) {
      boolean isDelete = (keyCode == DELETE || key == DELETE || key == 127);
      boolean isBackspace = (key == BACKSPACE || key == 8);
      if (isDelete || isBackspace) {
        deleteSelection();
      }
    }
  }
  
  boolean handleMouseWheel(float e) {
    if (mouseX < panelWidth) {
      // Hierarchy Scroll
      int listTopY = floor(menuBarHeight + 30); 
      int listBottomY = height - 30;
      float listHeight = listBottomY - listTopY;
      if (totalContentHeight > listHeight) {
        float maxScroll = totalContentHeight - listHeight;
        scrollY -= e * 30;
        scrollY = constrain(scrollY, -maxScroll, 0);
      }
      return true;
    } else if (mouseX > width - panelWidth) {
      // Inspector Scroll
      float listHeight = height - menuBarHeight - 60;
      if (inspectorTotalHeight > listHeight) {
        float maxScroll = inspectorTotalHeight - listHeight;
        inspectorScrollY -= e * 30;
        inspectorScrollY = constrain(inspectorScrollY, -maxScroll, 0);
      }
      return true;
    }
    
    if (debugConsole.active && mouseY < height/2) {
      debugConsole.handleMouseWheel(e);
      return true;
    }
    
    return false;
  }
  
  void renderViewportStatus() {
    pushStyle();
    fill(255);
    textSize(14);
    textAlign(LEFT, TOP);
    String modeText = "Tool [" + scene.gizmo.mode + "]: ";
    if (scene.gizmo.mode == 1) modeText += "Translate";
    if (scene.gizmo.mode == 2) modeText += "Rotate";
    if (scene.gizmo.mode == 3) modeText += "Scale";
    if (scene.gizmo.mode == 4) modeText += "Select";
    text(modeText + "  |  Snap: " + (p3deditor.this.snapToGrid ? "ON [G]" : "OFF [G]") + "  |  UI: H/TAB", 270, 15 + menuBarHeight);
    popStyle();
  }
  
  void renderGlobalSettings() {
    float panelX = width - panelWidth;
    pushStyle();
    // Sidebar Main Plate
    fill(25, 25, 28, 230); noStroke(); 
    rect(panelX, menuBarHeight, panelWidth, height - menuBarHeight);
    
    // Header Area
    fill(20, 20, 22, 230); noStroke(); 
    rect(panelX, menuBarHeight, panelWidth, 30);
    fill(180); textSize(11); textAlign(LEFT, CENTER);
    text("Global Scene Settings", panelX + 15, menuBarHeight + 15);
    stroke(60); line(panelX, menuBarHeight + 30, width, menuBarHeight + 30);
    
    // Vertical Divider
    stroke(60); line(panelX, menuBarHeight, panelX, height - 30);
    
    float y = menuBarHeight + 70;
    fill(180, 255, 180); text("Global Orchestration", panelX + 15, y);
    
    // Edit Level Blueprint Button
    float btnX = panelX + 25;
    float btnY = y + 25;
    float btnW = panelWidth - 50;
    float btnH = 30;
    
    boolean hoverBP = mouseX > btnX && mouseX < btnX + btnW && mouseY > btnY && mouseY < btnY + btnH;
    fill(hoverBP ? color(60, 80, 160) : color(40, 50, 100));
    stroke(hoverBP ? 120 : 80);
    rect(btnX, btnY, btnW, btnH, 4);
    fill(255); textAlign(CENTER, CENTER);
    text("EDIT LEVEL BLUEPRINT", btnX + btnW/2, btnY + btnH/2);
    
    // Background Color swatch
    y += 85;
    textAlign(LEFT, CENTER);
    fill(180, 255, 180); text("Environmental Settings", panelX + 15, y);
    
    float swatchY = y + 15;
    fill(120); textSize(10); textAlign(LEFT, CENTER);
    text("Background Color", panelX + 25, swatchY + 10);
    int bgCol = scene.backgroundColor;
    // Draw colored swatch
    fill(bgCol); stroke(150); strokeWeight(1);
    rect(panelX + 140, swatchY, 30, 20, 3);
    // Print hex value
    fill(160); textAlign(LEFT, CENTER); textSize(10);
    String hexStr = String.format("#%02X%02X%02X", (int)red(bgCol), (int)green(bgCol), (int)blue(bgCol));
    text(hexStr, panelX + 175, swatchY + 10);
    
    // Help instructions at bottom
    fill(100); textSize(10); textAlign(CENTER, BOTTOM);
    text("Level Blueprints run scene-wide logic", panelX + panelWidth/2, height - 45);
    
    popStyle();
  }
  
  void checkGlobalSettingsClicks() {
    float panelX = width - panelWidth;
    
    // 1. Edit Level Blueprint Button
    float lbBtnX = panelX + 25;
    float lbBtnY = menuBarHeight + 70 + 25;
    float lbBtnW = panelWidth - 50;
    float lbBtnH = 30;
    
    if (mouseX > lbBtnX && mouseX < lbBtnX + lbBtnW && mouseY > lbBtnY && mouseY < lbBtnY + lbBtnH) {
      vlbEditor.openBP(scene.levelBlueprint);
      return;
    }
    
    // 2. Background Color (Open Color Picker)
    float swatchX = panelX + 140;
    float iy = menuBarHeight + 70 + 85 + 15;
    if (mouseX > swatchX && mouseX < swatchX + 30 && mouseY > iy && mouseY < iy + 20) {
      new Thread(new Runnable() {
        public void run() {
          java.awt.Color initial = new java.awt.Color((int)p3deditor.this.red(scene.backgroundColor), (int)p3deditor.this.green(scene.backgroundColor), (int)p3deditor.this.blue(scene.backgroundColor));
          
          javax.swing.JColorChooser chooser = new javax.swing.JColorChooser(initial);
          javax.swing.JDialog dialog = javax.swing.JColorChooser.createDialog(null, "Select Background Color", false, chooser, 
            new java.awt.event.ActionListener() {
              public void actionPerformed(java.awt.event.ActionEvent e) {
                java.awt.Color selected = chooser.getColor();
                if (selected != null) {
                  scene.backgroundColor = color(selected.getRed(), selected.getGreen(), selected.getBlue());
                }
              }
            }, null);
          dialog.setAlwaysOnTop(true);
          dialog.setVisible(true);
        }
      }).start();
      return;
    }
  }
}
