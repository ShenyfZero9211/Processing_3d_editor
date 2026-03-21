class UIManager {
  SceneManager scene;
  int panelWidth = 250;
  
  UIManager(SceneManager scene) {
    this.scene = scene;
  }
  
  void render() {
    // Reset any leaked text alignment states from previous frames
    textAlign(LEFT, BASELINE);
    
    // --- LEFT PANEL (HIERARCHY) ---
    fill(40, 40, 40, 230);
    noStroke();
    rect(0, 0, panelWidth, height);
    
    // Hierarchy Header
    fill(200);
    textSize(20);
    text("Hierarchy", 15, 30);
    stroke(100);
    line(10, 40, panelWidth - 10, 40);
    
    // Entity List
    noStroke();
    for(int i = 0; i < scene.entities.size(); i++) {
      Entity e = scene.entities.get(i);
      if (e == scene.selectedEntity) {
        fill(80, 130, 200);
        rect(0, 50 + i * 30, panelWidth, 30);
      }
      fill(255);
      textSize(14);
      text(e.name, 20, 70 + i * 30);
    }
    
    // System Buttons
    fill(80, 150, 110);
    rect(15, height - 100, 105, 30, 5);
    fill(180, 110, 80);
    rect(125, height - 100, 105, 30, 5);
    fill(255);
    textSize(12);
    text("Load Scene", 35, height - 80); // Processing Native Dialog
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
    if (scene.selectedEntity != null) {
      Entity e = scene.selectedEntity;
      float panelX = width - panelWidth;
      
      fill(40, 40, 40, 230);
      noStroke();
      rect(panelX, 0, panelWidth, height);
      
      // Inspector Header
      fill(200);
      textSize(20);
      text("Inspector", panelX + 15, 30);
      stroke(100);
      line(panelX + 10, 40, width - 10, 40);
      
      fill(255);
      textSize(14);
      text("Name: " + e.name, panelX + 15, 70);
      text("Type: " + e.type, panelX + 15, 95);
      text("ID: " + e.id, panelX + 15, 120);
      
      // Transform Readouts
      fill(180, 255, 180);
      text("Position", panelX + 15, 160);
      fill(255);
      text(String.format("X: %.1f", e.transform.position.x), panelX + 25, 185);
      text(String.format("Y: %.1f", e.transform.position.y), panelX + 25, 205);
      text(String.format("Z: %.1f", e.transform.position.z), panelX + 25, 225);
      
      fill(180, 255, 180);
      text("Rotation (deg)", panelX + 15, 265);
      fill(255);
      text(String.format("X: %.1f", degrees(e.transform.rotation.x)), panelX + 25, 290);
      text(String.format("Y: %.1f", degrees(e.transform.rotation.y)), panelX + 25, 310);
      text(String.format("Z: %.1f", degrees(e.transform.rotation.z)), panelX + 25, 330);
      
      fill(180, 255, 180);
      text("Scale", panelX + 15, 370);
      fill(255);
      text(String.format("X: %.1f", e.transform.scale.x), panelX + 25, 395);
      text(String.format("Y: %.1f", e.transform.scale.y), panelX + 25, 415);
      text(String.format("Z: %.1f", e.transform.scale.z), panelX + 25, 435);
      
      // Hotkey Tooltips
      fill(150);
      textSize(12);
      text("Drag Gizmo arrows in 3D View", panelX + 10, height - 70);
      text("Delete: Backspace / Del", panelX + 10, height - 50);
    }
  }
  
  boolean handleMousePressed() {
    float panelX = width - panelWidth;
    
    // 1. Check Hierarchy Panel click
    if (mouseX < panelWidth) {
      // Check Entity selection
      for(int i = 0; i < scene.entities.size(); i++) {
        float itemY = 50 + i * 30;
        if (mouseY > itemY && mouseY < itemY + 30) {
          scene.selectEntity(scene.entities.get(i));
          return true; // Click handled
        }
      }
      
      // Check System Save/Load buttons
      if (mouseY > height - 100 && mouseY < height - 70) {
        if (mouseX > 15 && mouseX < 120) {
          selectInput("Select a file to load:", "fileSelectedForLoad");
          return true;
        } else if (mouseX > 125 && mouseX < 230) {
          selectOutput("Select a file to save to (e.g., scene.json):", "fileSelectedForSave");
          return true;
        }
      }
      
      // Check Add buttons
      if (mouseY > height - 60 && mouseY < height - 30) {
        if (mouseX > 15 && mouseX < 80) scene.addEntity("Cube " + (scene.entities.size()+1), "Cube");
        else if (mouseX > 90 && mouseX < 155) scene.addEntity("Sphere " + (scene.entities.size()+1), "Sphere");
        else if (mouseX > 165 && mouseX < 230) scene.addEntity("Plane " + (scene.entities.size()+1), "Plane");
      }
      return true; // Click handled (on panel)
    }
    
    // 2. Check Inspector Panel click
    if (scene.selectedEntity != null && mouseX > panelX) {
      return true; // Block raycast/camera orbit on inspector
    }
    
    return false;
  }
  
  void handleKeyPressed() {
    Entity e = scene.selectedEntity;
    if (e == null) return;
    
    // Delete entity
    if (key == BACKSPACE || key == DELETE) {
      scene.entities.remove(e);
      scene.selectEntity(null);
      return;
    }
  }
}
