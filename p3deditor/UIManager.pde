class UIManager {
  SceneManager scene;
  int panelWidth = 250;
  float scrollY = 0;
  boolean isDraggingScrollbar = false;
  float dragThumbOffsetY = 0;
  
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
  
  UIManager(SceneManager scene, CommandInterpreter interpreter) {
    this.scene = scene;
    this.interpreter = interpreter;
    this.debugConsole = new DebugConsole(interpreter);
    
    // Auto-run startup script if it exists
    interpreter.execute("exec init.p3dec");
  }
  
  boolean isEditingText() { return activeEditTarget > 0; }
  
  void commitEdit() {
    if (activeEditTarget == 14) {
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
           if (h.length() == 6) e.col = (int)Long.parseLong("FF" + h, 16);
        } catch(Exception ex) {}
      }
      else if (activeEditTarget == 12) e.lightIntensity = Float.parseFloat(activeEditString);
      else if (activeEditTarget == 13) e.lightRange = Float.parseFloat(activeEditString);
      
      scene.undoManager.push(new ValueEditCommand(scene, e, activeEditTarget, oldVal, activeEditString));
    } catch (Exception ex) {}
    activeEditTarget = 0;
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
    fill(255);
    textSize(14);
    if (activeEditTarget == id) {
      fill(255, 255, 0);
      text(label + activeEditString + (frameCount % 60 < 30 ? "|" : ""), x, y);
    } else {
      if (mouseX > x - 5 && mouseX < x + 150 && mouseY > y - 15 && mouseY < y + 5) {
        strokeWeight(1); stroke(150, 200);
        fill(200, 200, 255, 100);
        rect(x - 5, y - 15, 150, 20, 3);
      }
      noStroke();
      text(label + value, x, y);
    }
  }

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
  
  void renderHierarchy() {
    int listTopY = floor(menuBarHeight + 50); 
    int listBottomY = height - 120;
    
    pushStyle();
    fill(35, 35, 35, 230); // Glass effect alpha
    noStroke();
    rect(0, menuBarHeight, panelWidth, height - menuBarHeight);
    
    fill(25, 25, 25, 230); // Glass effect alpha
    noStroke();
    rect(0, menuBarHeight, panelWidth, 50);
    fill(220); textSize(18);
    textAlign(LEFT, CENTER);
    text("Hierarchy", 15, menuBarHeight + 25);
    stroke(80); line(10, menuBarHeight + 45, panelWidth - 10, menuBarHeight + 45);
    
    fill(40, 40, 40, 230); // Glass effect alpha
    noStroke();
    rect(0, listBottomY, panelWidth, height - listBottomY);
    
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
    popStyle();
  }
  
  void renderMenuDropdown() {
    String[] items = {};
    if (activeMenu.equals("File")) items = new String[]{"New Scene", "Load Scene", "Save Scene", "Export"};
    else if (activeMenu.equals("Edit")) items = new String[]{"Undo  [Ctrl+Z]", "Redo  [Ctrl+Y]", "Delete [Del]"};
    else if (activeMenu.equals("Create")) items = new String[]{"Cube", "Sphere", "Plane", "Point Light"};
    else if (activeMenu.equals("Window")) items = new String[]{"Toggle Console", "Toggle Stats", "Reset Camera"};
    
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
    fill(35, 35, 40, 250); stroke(80);
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
    pushStyle();
    // Background bar
    fill(20, 20, 25, 220);
    noStroke();
    rect(0, height - 30, width, 30);
    stroke(60); line(0, height-30, width, height-30); // Top border
    
    // Command Prompt
    fill(100, 255, 100);
    textAlign(LEFT, CENTER);
    textSize(14);
    text("> ", 15, height - 15);
    
    // Current Input
    if (activeEditTarget == 14) {
      fill(255, 255, 0);
      text(activeEditString + (frameCount % 60 < 30 ? "_" : ""), 35, height - 15);
    } else {
      fill(120);
      text("Type a command (e.g. 'move Cube 10 0 0') or press 'Enter'...", 35, height - 15);
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
    float totalContentHeight = hierarchyRects.size() * 30;
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

  void renderInspector() {
    if (scene.selectedEntities.isEmpty()) return;
    float panelX = width - panelWidth;
    fill(40, 40, 40, 230); noStroke(); rect(panelX, 0, panelWidth, height);
    fill(200); textSize(20); text("Inspector", panelX + 15, 30);
    stroke(100); line(panelX + 10, 40, width - 10, 40);
    if (scene.selectedEntities.size() == 1) {
      Entity e = scene.selectedEntities.get(0);
      drawEditField("Name: ", e.name, 1, panelX + 15, 70);
      fill(255); textSize(14); text("Type: " + e.type, panelX + 15, 95); text("ID: " + e.id, panelX + 15, 120);
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
      drawEditField("Color (Hex): #", hex(e.col, 6), 11, panelX + 25, 515);
      
      // Color Swatches Palette
      int[] swatches = {#FFFFFF, #FF0000, #00FF00, #0000FF, #FFFF00, #00FFFF, #FF00FF, #FFA500, #808080, #333333};
      for(int i=0; i<swatches.length; i++) {
        fill(swatches[i]);
        rect(panelX + 25 + i*20, 530, 15, 15, 3);
      }
      
      if (e.type.equals("PointLight")) {
        fill(180, 255, 180); text("Light Settings", panelX + 15, 570);
        drawEditField("Intensity: ", String.format(java.util.Locale.US, "%.1f", e.lightIntensity), 12, panelX + 25, 595);
        drawEditField("Range: ", String.format(java.util.Locale.US, "%.0f", e.lightRange), 13, panelX + 25, 615);
      }
    } else {
      fill(255); textSize(14); text(scene.selectedEntities.size() + " Objects Selected", panelX + 15, 70);
    }
    fill(150); textSize(11);
    text("Right-Click for Menu", panelX + 10, height - 70);
    text("Delete: Backspace / Del", panelX + 10, height - 50);
  }
  
  void renderContextMenu() {
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
      activeEditTarget = 14; activeEditString = ""; 
      return true; 
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
        float totalContentHeight = hierarchyRects.size() * 30;
        
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
            // Allow hit-test even if partially clipped, as long as it's within the mouse range
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
      if (!scene.selectedEntities.isEmpty() && mouseX > pX) { checkInspectorClicks(); return true; }
    }
    return false;
  }
  
  void checkInspectorClicks() {
    if (scene.selectedEntities.size() != 1) return;
    Entity e = scene.selectedEntities.get(0);
    int hitId = 0; String startVal = "";
    if (mouseY > 55 && mouseY <= 75) { hitId = 1; startVal = e.name; }
    else if (mouseY > 185 && mouseY <= 205) { hitId = 2; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.x); }
    else if (mouseY > 205 && mouseY <= 225) { hitId = 3; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.y); }
    else if (mouseY > 225 && mouseY <= 245) { hitId = 4; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.z); }
    else if (mouseY > 290 && mouseY <= 310) { hitId = 5; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.x)); }
    else if (mouseY > 310 && mouseY <= 330) { hitId = 6; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.y)); }
    else if (mouseY > 330 && mouseY <= 350) { hitId = 7; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.z)); }
    else if (mouseY > 395 && mouseY <= 415) { hitId = 8; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.x); }
    else if (mouseY > 415 && mouseY <= 435) { hitId = 9; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.y); }
    else if (mouseY > 435 && mouseY <= 455) { hitId = 10; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.z); }
    else if (mouseY > 500 && mouseY <= 525) { hitId = 11; startVal = hex(e.col, 6); }
    else if (mouseY > 530 && mouseY <= 545) {
      // Swatch Click
      int[] swatches = {#FFFFFF, #FF0000, #00FF00, #0000FF, #FFFF00, #00FFFF, #FF00FF, #FFA500, #808080, #333333};
      int swatchIdx = (mouseX - (width-panelWidth+25)) / 20;
      if (swatchIdx >= 0 && swatchIdx < swatches.length) {
        e.col = color(red(swatches[swatchIdx]), green(swatches[swatchIdx]), blue(swatches[swatchIdx]));
        return;
      }
    }
    else if (e.type.equals("PointLight")) {
       if (mouseY > 580 && mouseY <= 600) { hitId = 12; startVal = String.format(java.util.Locale.US, "%.1f", e.lightIntensity); }
       else if (mouseY > 600 && mouseY <= 620) { hitId = 13; startVal = String.format(java.util.Locale.US, "%.0f", e.lightRange); }
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
    if (menu.equals("File")) return new String[]{"New Scene", "Load Scene", "Save Scene"};
    else if (menu.equals("Edit")) return new String[]{"Undo  [Ctrl+Z]", "Redo  [Ctrl+Y]", "Delete [Del]"};
    else if (menu.equals("Create")) return new String[]{"Cube", "Sphere", "Plane", "Point Light"};
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
      selectOutput("Save Scene:", "fileSelectedForSave");
    } else if (item.contains("Export")) {
       saveFrame("exports/screenshot-####.png");
       consoleResult = "SUCCESS: Exported screenshot";
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
      scene.addEntity("Point Light", "PointLight");
      debugConsole.addLog("Created PointLight", 0);
    } else if (item.contains("Console")) {
      showConsole = !showConsole;
      if (!showConsole && activeEditTarget == 14) activeEditTarget = 0;
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
    debugConsole.handleKey(key, keyCode);
    
    // Fallback: If console is not active and not editing inspector, allow shortcuts like Delete
    if (!debugConsole.active && !isEditingText()) {
      boolean isDelete = (keyCode == DELETE || key == DELETE || key == 127);
      boolean isBackspace = (key == BACKSPACE || key == 8);
      if (isDelete || isBackspace) {
        deleteSelection();
      }
    }
  }
  
  void handleMouseWheel(float e) {
    debugConsole.handleMouseWheel(e);
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
}
