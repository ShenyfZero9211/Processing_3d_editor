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
  
  class HierarchyItemRect {
    Entity entity;
    float y;
    HierarchyItemRect(Entity e, float y) { this.entity = e; this.y = y; }
  }

  UIManager(SceneManager scene) {
    this.scene = scene;
  }
  
  boolean isEditingText() { return activeEditTarget > 0; }
  
  void commitEdit() {
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
      if (key == 0 || key == CODED) return;
      // Allow hex characters for color editing
      boolean isHexChar = (key >= 'a' && key <= 'f') || (key >= 'A' && key <= 'F');
      if (activeEditTarget == 1 || activeEditTarget == 11 || (key >= '0' && key <= '9') || key == '.' || key == '-' || isHexChar) {
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
    textAlign(LEFT, BASELINE);
    fill(40, 40, 40, 230);
    noStroke();
    rect(0, 0, panelWidth, height);
    
    int listTopY = 50;
    int listBottomY = height - 120;
    
    hierarchyRects.clear();
    float currentY = listTopY + scrollY;
    for (Entity e : scene.entities) {
      if (e.parent == null) {
        currentY = renderHierarchyNode(e, 0, currentY, listTopY, listBottomY);
      }
    }
    
    fill(40, 40, 40);
    noStroke();
    rect(0, 0, panelWidth, listTopY);
    fill(200); textSize(20);
    text("Hierarchy", 15, 30);
    stroke(100); line(10, 40, panelWidth - 10, 40);
    
    fill(40, 40, 40);
    noStroke();
    rect(0, listBottomY, panelWidth, height - listBottomY);
    
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
    
    // Buttons
    fill(80, 150, 110); rect(15, height - 100, 105, 30, 5);
    fill(180, 110, 80); rect(125, height - 100, 105, 30, 5);
    fill(255); textSize(12);
    text("Load Scene", 35, height - 80); text("Save Scene", 145, height - 80);
    
    fill(0, 150, 255);
    rect(15, height - 60, 50, 30, 5); 
    rect(70, height - 60, 50, 30, 5); 
    rect(125, height - 60, 50, 30, 5);
    rect(180, height - 60, 50, 30, 5); // +Light
    fill(255);
    text("+Cube", 21, height - 40); 
    text("+Sph.", 80, height - 40); 
    text("+Pln.", 135, height - 40);
    text("+Lgt.", 191, height - 40);
    
    renderInspector();
    renderStats();
    if (showContextMenu) renderContextMenu();
  }

  void renderStats() {
    int totalPolys = 0;
    for (Entity e : scene.entities) totalPolys += e.getPolyCount();
    
    float x = 270;
    float y = 100;
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
      float indent = 20 + depth * 20;
      if (depth > 0) {
        stroke(80);
        line(indent - 10, y + itemH/2, indent - 10, y - itemH/2 + 5); 
        line(indent - 10, y + itemH/2, indent - 5, y + itemH/2);
      }
      noStroke(); text(e.name, indent, y + 20);
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
            if (mouseY > hr.y && mouseY < hr.y + 30) {
              scene.selectEntity(hr.entity, isCtrlDown);
              hierarchyDragSource = hr.entity; 
              hierarchyDragStartX = mouseX; hierarchyDragStartY = mouseY; hasDraggedHierarchy = false;
              return true;
            }
          }
          return true; 
        }
        
        if (mouseY > height - 100 && mouseY < height - 70) {
          if (mouseX > 15 && mouseX < 120) { selectInput("Load:", "fileSelectedForLoad"); return true; }
          else if (mouseX > 125 && mouseX < 230) { selectOutput("Save:", "fileSelectedForSave"); return true; }
        }
        if (mouseY > height - 60 && mouseY < height - 30) {
          if (mouseX > 15 && mouseX < 65) scene.addEntity("Cube", "Cube");
          else if (mouseX > 70 && mouseX < 120) scene.addEntity("Sphere", "Sphere");
          else if (mouseX > 125 && mouseX < 175) scene.addEntity("Plane", "Plane");
          else if (mouseX > 180 && mouseX < 230) scene.addEntity("Light", "PointLight");
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
  
  void handleKeyPressed() { if (key == BACKSPACE || key == DELETE) deleteSelection(); }
}
