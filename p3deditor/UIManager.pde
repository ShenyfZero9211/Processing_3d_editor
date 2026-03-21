class UIManager {
  SceneManager scene;
  int panelWidth = 250;
  float scrollY = 0;
  boolean isDraggingScrollbar = false;
  float dragThumbOffsetY = 0;
  
  int activeEditTarget = 0; // 0=None, 1=Name, 2=PosX...
  String activeEditString = "";
  
  boolean isEditingText() { return activeEditTarget > 0; }
  
  void commitEdit() {
    if (activeEditTarget == 0 || scene.selectedEntities.size() != 1) {
      activeEditTarget = 0;
      return;
    }
    Entity e = scene.selectedEntities.get(0);
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
      if (activeEditTarget == 1 || (key >= '0' && key <= '9') || key == '.' || key == '-') {
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
        fill(200, 200, 255);
        rect(x - 5, y - 15, 150, 20, 3);
        fill(0);
      }
      text(label + value, x, y);
    }
  }
  
  UIManager(SceneManager scene) {
    this.scene = scene;
  }
  
  void render() {
    textAlign(LEFT, BASELINE);
    
    // 1. Base Panel Background
    fill(40, 40, 40, 230);
    noStroke();
    rect(0, 0, panelWidth, height);
    
    int listTopY = 50;
    int listBottomY = height - 120;
    
    // 2. Scrolling Entity List
    noStroke();
    for(int i = 0; i < scene.entities.size(); i++) {
        float itemY = listTopY + i * 30 + scrollY;
        
        // Painter's algorithm culling
        if (itemY < listTopY - 30 || itemY > listBottomY) continue;
        
        Entity e = scene.entities.get(i);
        if (scene.selectedEntities.contains(e)) {
            fill(80, 130, 200);
            rect(0, itemY, panelWidth, 30);
        }
        fill(255);
        text(e.name, 20, itemY + 20);
    }
    
    // 3. Opaque Header
    fill(40, 40, 40);
    rect(0, 0, panelWidth, listTopY);
    
    fill(200);
    textSize(20);
    text("Hierarchy", 15, 30);
    stroke(100);
    line(10, 40, panelWidth - 10, 40);
    
    // 4. Opaque Footer
    fill(40, 40, 40);
    noStroke();
    rect(0, listBottomY, panelWidth, height - listBottomY);
    
    // 5. Scrollbar
    float listHeight = listBottomY - listTopY;
    float totalContentHeight = scene.entities.size() * 30;
    
    if (totalContentHeight > listHeight) {
      float thumbHeight = max(20, listHeight * (listHeight / totalContentHeight));
      float maxScroll = totalContentHeight - listHeight;
      float p = -scrollY / maxScroll;
      float thumbY = listTopY + p * (listHeight - thumbHeight);
      
      // Track
      fill(30, 30, 30, 150);
      rect(panelWidth - 12, listTopY, 8, listHeight, 4);
      
      // Thumb
      if (isDraggingScrollbar) {
        fill(100, 180, 255);
      } else if (mouseX > panelWidth - 16 && mouseX < panelWidth && mouseY > thumbY && mouseY < thumbY + thumbHeight) {
        fill(150);
      } else {
        fill(100);
      }
      rect(panelWidth - 12, thumbY, 8, thumbHeight, 4);
    }
    
    // System Buttons
    fill(80, 150, 110);
    rect(15, height - 100, 105, 30, 5);
    fill(180, 110, 80);
    rect(125, height - 100, 105, 30, 5);
    fill(255);
    textSize(12);
    text("Load Scene", 35, height - 80);
    text("Save Scene", 145, height - 80);
    
    // Add Entity Buttons
    fill(0, 150, 255);
    rect(15, height - 60, 65, 30, 5);
    rect(90, height - 60, 65, 30, 5);
    rect(165, height - 60, 65, 30, 5);
    fill(255);
    text("+Cube", 28, height - 40);
    text("+Sphere", 100, height - 40);
    text("+Plane", 178, height - 40);
    
    
    // --- RIGHT PANEL (INSPECTOR) ---
    if (!scene.selectedEntities.isEmpty()) {
      float panelX = width - panelWidth;
      fill(40, 40, 40, 230);
      noStroke();
      rect(panelX, 0, panelWidth, height);
      
      fill(200);
      textSize(20);
      text("Inspector", panelX + 15, 30);
      stroke(100);
      line(panelX + 10, 40, width - 10, 40);
      
      if (scene.selectedEntities.size() == 1) {
        Entity e = scene.selectedEntities.get(0);
        
        drawEditField("Name: ", e.name, 1, panelX + 15, 70);
        fill(255); textSize(14);
        text("Type: " + e.type, panelX + 15, 95);
        text("ID: " + e.id, panelX + 15, 120);
        
        fill(180, 255, 180);
        text("Position", panelX + 15, 160);
        drawEditField("X: ", String.format(java.util.Locale.US, "%.1f", e.transform.position.x), 2, panelX + 25, 185);
        drawEditField("Y: ", String.format(java.util.Locale.US, "%.1f", e.transform.position.y), 3, panelX + 25, 205);
        drawEditField("Z: ", String.format(java.util.Locale.US, "%.1f", e.transform.position.z), 4, panelX + 25, 225);
        
        fill(180, 255, 180);
        text("Rotation (deg)", panelX + 15, 265);
        drawEditField("X: ", String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.x)), 5, panelX + 25, 290);
        drawEditField("Y: ", String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.y)), 6, panelX + 25, 310);
        drawEditField("Z: ", String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.z)), 7, panelX + 25, 330);
        
        fill(180, 255, 180);
        text("Scale", panelX + 15, 370);
        drawEditField("X: ", String.format(java.util.Locale.US, "%.1f", e.transform.scale.x), 8, panelX + 25, 395);
        drawEditField("Y: ", String.format(java.util.Locale.US, "%.1f", e.transform.scale.y), 9, panelX + 25, 415);
        drawEditField("Z: ", String.format(java.util.Locale.US, "%.1f", e.transform.scale.z), 10, panelX + 25, 435);
      } else {
        fill(255);
        textSize(14);
        text(scene.selectedEntities.size() + " Objects Selected", panelX + 15, 70);
        text("Group transform active.", panelX + 15, 95);
        text("Rot/Scale disabled natively.", panelX + 15, 120);
      }
      
      fill(150);
      textSize(12);
      text("Drag Gizmo arrows in 3D View", panelX + 10, height - 70);
      text("Delete: Backspace / Del", panelX + 10, height - 50);
    }
  }
  
  boolean handleMousePressed() {
    float panelX = width - panelWidth;
    
    if (mouseX < panelWidth) {
      if (!showUI) return false;
      
      int listTopY = 50;
      int listBottomY = height - 120;
      float listHeight = listBottomY - listTopY;
      float totalContentHeight = scene.entities.size() * 30;
      
      // 1. Check Scrollbar Clicks First
      if (totalContentHeight > listHeight) {
        if (mouseX > panelWidth - 18 && mouseX <= panelWidth) {
          if (mouseY >= listTopY && mouseY <= listBottomY) {
            float thumbHeight = max(20, listHeight * (listHeight / totalContentHeight));
            float maxScroll = totalContentHeight - listHeight;
            float p = -scrollY / maxScroll;
            float thumbY = listTopY + p * (listHeight - thumbHeight);
            
            if (mouseY >= thumbY && mouseY <= thumbY + thumbHeight) {
               isDraggingScrollbar = true;
               dragThumbOffsetY = mouseY - thumbY;
               return true;
            } else {
               // Jump to click
               float newThumbTop = mouseY - (thumbHeight / 2.0f);
               newThumbTop = constrain(newThumbTop, listTopY, listBottomY - thumbHeight);
               float newP = (newThumbTop - listTopY) / (listHeight - thumbHeight);
               scrollY = -(newP * maxScroll);
               isDraggingScrollbar = true;
               dragThumbOffsetY = thumbHeight / 2.0f;
               return true;
            }
          }
        }
      }
      
      // 2. Check Entity List Clicks
      if (mouseY >= listTopY && mouseY <= listBottomY) {
        for(int i = 0; i < scene.entities.size(); i++) {
          float itemY = listTopY + i * 30 + scrollY;
          if (mouseY > itemY && mouseY < itemY + 30) {
            scene.selectEntity(scene.entities.get(i), isCtrlDown);
            return true;
          }
        }
        return true; // Clicked safely into the list
      }
      
      if (mouseY > height - 100 && mouseY < height - 70) {
        if (mouseX > 15 && mouseX < 120) {
          selectInput("Select a file to load:", "fileSelectedForLoad");
          return true;
        } else if (mouseX > 125 && mouseX < 230) {
          selectOutput("Select a file to save to (e.g., scene.p3de):", "fileSelectedForSave");
          return true;
        }
      }
      
      if (mouseY > height - 60 && mouseY < height - 30) {
        if (mouseX > 15 && mouseX < 80) scene.addEntity("Cube " + (scene.entities.size()+1), "Cube");
        else if (mouseX > 90 && mouseX < 155) scene.addEntity("Sphere " + (scene.entities.size()+1), "Sphere");
        else if (mouseX > 165 && mouseX < 230) scene.addEntity("Plane " + (scene.entities.size()+1), "Plane");
      }
      return true;
    }
    
    if (!scene.selectedEntities.isEmpty() && mouseX > panelX) {
      if (scene.selectedEntities.size() == 1) {
        Entity e = scene.selectedEntities.get(0);
        int hitId = 0;
        String startVal = "";
        
        if (mouseY > 55 && mouseY <= 75) { hitId = 1; startVal = e.name; }
        else if (mouseY > 170 && mouseY <= 190) { hitId = 2; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.x); }
        else if (mouseY > 190 && mouseY <= 210) { hitId = 3; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.y); }
        else if (mouseY > 210 && mouseY <= 230) { hitId = 4; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.position.z); }
        else if (mouseY > 275 && mouseY <= 295) { hitId = 5; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.x)); }
        else if (mouseY > 295 && mouseY <= 315) { hitId = 6; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.y)); }
        else if (mouseY > 315 && mouseY <= 335) { hitId = 7; startVal = String.format(java.util.Locale.US, "%.1f", degrees(e.transform.rotation.z)); }
        else if (mouseY > 380 && mouseY <= 400) { hitId = 8; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.x); }
        else if (mouseY > 400 && mouseY <= 420) { hitId = 9; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.y); }
        else if (mouseY > 420 && mouseY <= 440) { hitId = 10; startVal = String.format(java.util.Locale.US, "%.1f", e.transform.scale.z); }
        
        if (hitId > 0) {
          activeEditTarget = hitId;
          activeEditString = startVal;
          return true;
        } else {
          if (activeEditTarget > 0) commitEdit();
        }
      }
      return true;
    }
    
    return false;
  }
  
  void handleKeyPressed() {
    if (scene.selectedEntities.isEmpty()) return;
    
    if (key == BACKSPACE || key == DELETE) {
      ArrayList<Entity> toRemove = new ArrayList<Entity>(scene.selectedEntities);
      for (Entity e : toRemove) {
        scene.entities.remove(e);
      }
      scene.clearSelection();
      return;
    }
  }
}
