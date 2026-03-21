import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.AWTException;

// Main Entry for 3D Scene Editor
SceneManager scene;
EditorCamera editorCamera;
UIManager ui;
Raycaster raycaster;
Robot robot;

int draggingAxis = 0; // 0=none, 1=X, 2=Y, 3=Z
float startDragMouseX, startDragMouseY;

// Setup Drag variables
ArrayList<PVector> startDragPositions = new ArrayList<PVector>();
PVector startDragCenter = null;
PVector startDragScale = null;
PVector startDragRot = null;
PVector startDragPlaneHit = null;

PMatrix3D savedProj = new PMatrix3D();
PMatrix3D savedView = new PMatrix3D();

// Undo/Redo Snapshots
PVector[] oldStatesP, oldStatesR, oldStatesS;

boolean[] keyStates = new boolean[256];
boolean isAltDown = false;
boolean isCtrlDown = false;

boolean snapToGrid = false; // 10-unit snapping toggle
boolean showUI = true; // H or TAB toggles visibility

// Box Select Framework
boolean isBoxSelecting = false;
float boxSelectStartX = 0;
float boxSelectStartY = 0;

ArrayList<Entity> clipboard = new ArrayList<Entity>();

boolean showDebugRay = false; // Toggle this to true to use raycast debugging!
Ray debugRay = null;
String debugText = "Ready";

PGraphics pickerBuffer;

void setup() {
  size(1280, 720, P3D);
  surface.setLocation((displayWidth - width) / 2, (displayHeight - height) / 2);
  
  try {
    robot = new Robot();
  } catch (AWTException e) {
    println("Could not initialize Robot for mouse locking.");
  }
  
  pickerBuffer = createGraphics(1280, 720, P3D);
  scene = new SceneManager();
  editorCamera = new EditorCamera();
  ui = new UIManager(scene);
  raycaster = new Raycaster();
  
  scene.addEntity("Cube 1", "Cube");
  scene.addEntity("Sphere 1", "Sphere");
  scene.addEntity("Light 1", "PointLight");
  scene.entities.get(2).transform.position.set(150, -200, 100);
}

void draw() {
  background(40);
  
  editorCamera.update(keyStates); // Process WASD movement frame by frame
  
  // Apply camera
  editorCamera.apply(this);
  
  // Dynamic Scene Lighting
  ambientLight(70, 70, 70);
  lightSpecular(200, 200, 200);
  for (Entity e : scene.entities) {
    if (e.type.equals("PointLight")) {
      PVector p = e.getWorldPosition();
      float r = red(e.col) * e.lightIntensity;
      float g = green(e.col) * e.lightIntensity;
      float b = blue(e.col) * e.lightIntensity;
      
      // factor = 1 / (1 + linear*d + quadratic*d^2)
      // We use quadratic falloff to map lightRange to a 50% drop at the range distance
      lightFalloff(1.0, 0.0, 1.0 / sq(e.lightRange)); 
      pointLight(r, g, b, p.x, p.y, p.z);
    }
  }
  
  // VERY IMPORTANT: Save the matrices before drawing the UI
  savedProj.set(((PGraphics3D)g).projection);
  savedView.set(((PGraphics3D)g).modelview);
  
  // Continuous Gizmo Hover Detection
  if (!scene.selectedEntities.isEmpty() && scene.gizmo != null) {
    if (draggingAxis == 0) {
      Ray hoverRay = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
      scene.gizmo.hoverAxis = scene.gizmo.checkHit(hoverRay, scene, raycaster);
    } else {
      scene.gizmo.hoverAxis = draggingAxis; // Lock highlight visually while tracking
    }
  }
  
  drawGrid();
  scene.render(this);
  
  // ================= DEBUG: DRAW THE RAY =================
  if (showDebugRay && debugRay != null) {
    stroke(255, 255, 0); // Yellow ray
    strokeWeight(2);
    PVector p1 = debugRay.origin;
    PVector p2 = PVector.add(debugRay.origin, PVector.mult(debugRay.direction, 2000));
    line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z);
    
    pushMatrix();
    translate(p1.x, p1.y, p1.z);
    fill(255, 0, 0);
    noStroke();
    sphere(5);
    popMatrix();
  }
  // =======================================================
  
  // UI Layer
  camera(); 
  hint(DISABLE_DEPTH_TEST);
  noLights(); // Prevents 3D scene lighting from tinting the 2D text!
  
  if (showUI) {
    ui.render();
  }
  
  // Render Mode Text Overlay
  if (showUI) {
    fill(255);
    textSize(14);
    textAlign(LEFT, TOP);
    String modeText = "Tool [" + scene.gizmo.mode + "]: ";
    if (scene.gizmo.mode == 1) modeText += "Translate";
    if (scene.gizmo.mode == 2) modeText += "Rotate";
    if (scene.gizmo.mode == 3) modeText += "Scale";
    if (scene.gizmo.mode == 4) modeText += "Select";
    text(modeText + "  |  Snap: " + (snapToGrid ? "ON [G]" : "OFF [G]") + "  |  UI: H/TAB", 270, 70);
  }
  
  // Box Select GUI Screen Overlay
  if (isBoxSelecting) {
    stroke(100, 200, 255);
    strokeWeight(1);
    fill(100, 200, 255, 50);
    rectMode(CORNERS);
    rect(boxSelectStartX, boxSelectStartY, mouseX, mouseY);
    rectMode(CORNER);
  }
  
  // Debug Overlay Text
  if (showDebugRay) {
    fill(0, 255, 0);
    textSize(16);
    textAlign(LEFT, TOP);
    text(debugText, 270, 30);
  }
  
  hint(ENABLE_DEPTH_TEST);
}

void drawGrid() {
  stroke(100);
  strokeWeight(1);
  for(int i=-10; i<=10; i++) {
    line(i*50, 0, -500, i*50, 0, 500);
    line(-500, 0, i*50, 500, 0, i*50);
  }
}

// Global input routing to UI or Camera
void mousePressed() {
  if (showUI) {
    if (ui.isEditingText()) ui.commitEdit(); 
    if (ui.handleMousePressed()) return; 
  }
  
  Ray ray = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
  
  if (mouseButton == RIGHT) {
     // Viewport right-click picking
     if (mouseX >= ui.panelWidth && mouseX <= width - ui.panelWidth) {
        Entity hit = scene.pickEntity(ray, raycaster);
        if (hit != null) {
           scene.selectEntity(hit, false);
           ui.showContextMenu = true;
           ui.menuX = mouseX;
           ui.menuY = mouseY;
           return; // Interrupted by menu
        }
     }
  }
  
  if (showDebugRay) debugRay = ray;
  
  if (showDebugRay) {
    debugText = "Ray Start: " + String.format("%.1f, %.1f", ray.origin.x, ray.origin.y) + 
                " Dir: " + String.format("%.2f, %.2f, %.2f", ray.direction.x, ray.direction.y, ray.direction.z);
  }
  
  if (mouseButton == LEFT) {
    // Check Gizmo intersection explicitly against group center
    if (!scene.selectedEntities.isEmpty()) {
      int gizmoAxis = scene.gizmo.checkHit(ray, scene, raycaster);
      if (gizmoAxis > 0) {
        draggingAxis = gizmoAxis;
        setupDrag();
        return;
      }
    }
    
    // Check Entity picking explicitly
    draggingAxis = 0;
    Entity hit = null;
    float minDist = 999999;
    for(Entity e : scene.entities) {
      float t = raycaster.intersectEntity(ray, e);
      if (t > 0 && t < minDist) {
        minDist = t;
        hit = e;
      }
    }
    
    if (hit != null) {
      scene.selectEntity(hit, isCtrlDown);
      if (showDebugRay) debugText += " | Hit: " + hit.name;
    } else {
      // Begin box selection tracking!
      if (!isCtrlDown) scene.clearSelection();
      isBoxSelecting = true;
      boxSelectStartX = mouseX;
      boxSelectStartY = mouseY;
      if (showDebugRay) debugText += " | Box Selecting";
    }
  }
  
  editorCamera.handleMousePressed();
}

void setupDrag() {
  if (!scene.selectedEntities.isEmpty()) {
    startDragMouseX = mouseX;
    startDragMouseY = mouseY;
    startDragCenter = scene.gizmo.getCenter(scene); // Mathematical center of selection
    
    startDragPositions.clear();
    for (Entity e : scene.selectedEntities) {
      startDragPositions.add(e.transform.position.copy());
    }
    
    // Load scales solely for single target items explicitly
    if (scene.selectedEntities.size() == 1) {
      startDragScale = scene.selectedEntities.get(0).transform.scale.copy();
      startDragRot = scene.selectedEntities.get(0).transform.rotation.copy();
      
      if (scene.gizmo.mode == 2) {
        Ray ray = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
        PVector normal = new PVector();
        if (draggingAxis == 1) normal.x = 1;
        if (draggingAxis == 2) normal.y = 1;
        if (draggingAxis == 3) normal.z = 1;
        
        float t = raycaster.intersectPlane(ray, startDragCenter, normal);
        if (t > 0) {
          startDragPlaneHit = PVector.add(ray.origin, PVector.mult(ray.direction, t));
        }
      }
    }
    // Capture snapshots for Undo
    int count = scene.selectedEntities.size();
    oldStatesP = new PVector[count];
    oldStatesR = new PVector[count];
    oldStatesS = new PVector[count];
    for (int i=0; i<count; i++) {
      Entity e = scene.selectedEntities.get(i);
      oldStatesP[i] = e.transform.position.copy();
      oldStatesR[i] = e.transform.rotation.copy();
      oldStatesS[i] = e.transform.scale.copy();
    }
  }
}

void mouseDragged() {
  if (showUI) ui.handleMouseDragged();
  
  if (ui.isDraggingScrollbar) {
      int listTopY = 50;
      int listBottomY = height - 120;
      float listHeight = listBottomY - listTopY;
      float totalContentHeight = scene.entities.size() * 30;
      float thumbHeight = max(20, listHeight * (listHeight / totalContentHeight));
      
      float trackRange = listHeight - thumbHeight;
      float newThumbTop = mouseY - ui.dragThumbOffsetY;
      newThumbTop = constrain(newThumbTop, listTopY, listBottomY - thumbHeight);
      
      float p = (newThumbTop - listTopY) / trackRange;
      float maxScroll = totalContentHeight - listHeight;
      ui.scrollY = -(p * maxScroll);
      return; 
  }

  if (draggingAxis > 0 && !scene.selectedEntities.isEmpty() && mouseButton == LEFT) {
    int mode = scene.gizmo.mode;
    int drawMode = (scene.selectedEntities.size() > 1) ? 1 : mode; // Force translation if multi-selected
    
    if (drawMode == 1 || drawMode == 3) {
      PVector axisW = new PVector(0,0,0);
      if (draggingAxis == 1) axisW.x = 1;
      if (draggingAxis == 2) axisW.y = 1;
      if (draggingAxis == 3) axisW.z = 1;
      
      // Convert Local Axis to World Space if using Local Mode
      if (scene.useLocalSpace && scene.selectedEntities.size() == 1) {
         Entity e = scene.selectedEntities.get(0);
         PMatrix3D wm = e.getWorldMatrix();
         // Multiply matrix by the local axis (as a direction vector, w=0)
         PVector worldAxis = new PVector();
         wm.mult(axisW, worldAxis);
         // The world axis length will be scaled by the entity's scale, 
         // so we normalize to get just the direction.
         axisW = worldAxis.normalize();
      }
      
      PVector p0 = startDragCenter;
      PVector p1 = PVector.add(p0, PVector.mult(axisW, 100.0f)); 
      
      PVector s0 = worldToScreen(p0);
      PVector s1 = worldToScreen(p1);
      
      PVector sDir = PVector.sub(s1, s0);
      float sqMag = sDir.magSq();
      
      if (sqMag > 0.001f) {
        PVector mouseDelta = new PVector(mouseX - startDragMouseX, mouseY - startDragMouseY);
        float k = mouseDelta.dot(sDir) / sqMag;
        float worldDelta = k * 100.0f;
        
        if (drawMode == 1) { // Translate
          float delta = snapToGrid ? (round(worldDelta / 10.0f) * 10.0f) : worldDelta;
          
          for (int i=0; i<scene.selectedEntities.size(); i++) {
            Entity e = scene.selectedEntities.get(i);
            PVector startP = startDragPositions.get(i);
            
            if (scene.useLocalSpace && scene.selectedEntities.size() == 1) {
              if (draggingAxis == 1) e.transform.position.x = startP.x + delta;
              if (draggingAxis == 2) e.transform.position.y = startP.y + delta;
              if (draggingAxis == 3) e.transform.position.z = startP.z + delta;
            } else {
              e.transform.position.set(PVector.add(startP, PVector.mult(axisW, delta)));
            }
          }
        }
        else if (drawMode == 3 && scene.selectedEntities.size() == 1) { // Scale
          float sDelta = worldDelta / 100.0f;
          if (snapToGrid) sDelta = round(sDelta / 0.1f) * 0.1f;
          
          Entity e = scene.selectedEntities.get(0);
          if (scene.useLocalSpace) {
            if (draggingAxis == 1) e.transform.scale.x = max(0.01f, startDragScale.x + sDelta);
            if (draggingAxis == 2) e.transform.scale.y = max(0.01f, startDragScale.y + sDelta);
            if (draggingAxis == 3) e.transform.scale.z = max(0.01f, startDragScale.z + sDelta);
          } else {
            e.transform.scale.set(PVector.add(startDragScale, PVector.mult(axisW, sDelta)));
            e.transform.scale.x = max(0.01f, e.transform.scale.x);
            e.transform.scale.y = max(0.01f, e.transform.scale.y);
            e.transform.scale.z = max(0.01f, e.transform.scale.z);
          }
        }
      }
    }
    else if (drawMode == 2 && startDragPlaneHit != null && scene.selectedEntities.size() == 1) { // Rotate
      Ray ray = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
      PVector normal = new PVector();
      if (draggingAxis == 1) normal.x = 1;
      if (draggingAxis == 2) normal.y = 1;
      if (draggingAxis == 3) normal.z = 1;
      
      float t = raycaster.intersectPlane(ray, startDragCenter, normal);
      if (t > 0) {
        PVector pCur = PVector.add(ray.origin, PVector.mult(ray.direction, t));
        PVector vStart = PVector.sub(startDragPlaneHit, startDragCenter).normalize();
        PVector vCur = PVector.sub(pCur, startDragCenter).normalize();
        
        float angle = acos(constrain(vStart.dot(vCur), -1.0f, 1.0f));
        PVector cross = vStart.cross(vCur);
        if (cross.dot(normal) < 0) angle = -angle; 
        
        if (snapToGrid) angle = round(angle / radians(15)) * radians(15);
        
        Entity e = scene.selectedEntities.get(0);
        PMatrix3D m = new PMatrix3D();
        m.rotateY(startDragRot.y);
        m.rotateX(startDragRot.x);
        m.rotateZ(startDragRot.z);

        if (scene.useLocalSpace) {
          // Local rotation: M_new = M_old * R_local_delta
          if (draggingAxis == 1) m.rotateX(angle);
          if (draggingAxis == 2) m.rotateY(angle);
          if (draggingAxis == 3) m.rotateZ(angle);
        } else {
          // World rotation: M_new = R_world_delta * M_old
          PMatrix3D rDelta = new PMatrix3D();
          if (draggingAxis == 1) rDelta.rotateX(angle);
          if (draggingAxis == 2) rDelta.rotateY(angle);
          if (draggingAxis == 3) rDelta.rotateZ(angle);
          m.preApply(rDelta);
        }
        
        e.updateRotationFromMatrix(m);
      }
    }
    return;
  }
  
  editorCamera.handleMouseDragged(isAltDown);
}

// Converts generic 3D vectors to exact screen overlays flawlessly ensuring boundaries!
PVector worldToScreen(PVector w) {
  float[] world = {w.x, w.y, w.z, 1};
  float[] eye = new float[4];
  savedView.mult(world, eye);
  float[] clip = new float[4];
  savedProj.mult(eye, clip);
  
  if (clip[3] != 0) {
    clip[0] /= clip[3];
    clip[1] /= clip[3];
    clip[2] /= clip[3];
  }
  
  float sx = (clip[0] + 1.0f) * 0.5f * width;
  float sy = (1.0f - clip[1]) * 0.5f * height;
  float sz = clip[3] != 0 ? (clip[2] / clip[3]) : 0;
  
  return new PVector(sx, sy, sz);
}

void mouseReleased() {
  if (showUI) ui.handleMouseReleased();
  
  if (ui.isDraggingScrollbar) {
    ui.isDraggingScrollbar = false;
  }

  if (draggingAxis > 0 && !scene.selectedEntities.isEmpty()) {
    int count = scene.selectedEntities.size();
    PVector[] nP = new PVector[count];
    PVector[] nR = new PVector[count];
    PVector[] nS = new PVector[count];
    boolean changed = false;
    for (int i=0; i<count; i++) {
      Entity e = scene.selectedEntities.get(i);
      nP[i] = e.transform.position.copy();
      nR[i] = e.transform.rotation.copy();
      nS[i] = e.transform.scale.copy();
      if (nP[i].dist(oldStatesP[i]) > 0.001f || nR[i].dist(oldStatesR[i]) > 0.001f || nS[i].dist(oldStatesS[i]) > 0.001f) changed = true;
    }
    if (changed) {
      scene.undoManager.push(new TransformCommand(scene, scene.selectedEntities, oldStatesP, nP, oldStatesR, nR, oldStatesS, nS));
    }
  }

  draggingAxis = 0;
  if (isBoxSelecting) {
    isBoxSelecting = false;
    float x1 = min(boxSelectStartX, mouseX);
    float x2 = max(boxSelectStartX, mouseX);
    float y1 = min(boxSelectStartY, mouseY);
    float y2 = max(boxSelectStartY, mouseY);
    
    if (dist(x1, y1, x2, y2) > 5) { // Reject tiny tremors masking clicking 
      if (!isCtrlDown) scene.clearSelection();
      for (Entity e : scene.entities) {
        PVector s = worldToScreen(e.transform.position);
        if (s.z > -1 && s.z < 1) { // Validate mathematically in bounded clipping volume
          if (s.x >= x1 && s.x <= x2 && s.y >= y1 && s.y <= y2) {
            scene.selectEntity(e, true);
          }
        }
      }
    }
  }
  editorCamera.handleMouseReleased();
}

void mouseWheel(MouseEvent event) {
  if (showUI && mouseX < 250) {
    ui.scrollY += event.getCount() * -20;
    ui.scrollY = min(0, ui.scrollY); // lock top
    
    int listHeight = height - 120 - 50;
    float maxScroll = -max(0, scene.entities.size() * 30 - listHeight);
    ui.scrollY = max(maxScroll, ui.scrollY); // lock bottom
    return;
  }
  editorCamera.handleMouseWheel(event);
}

void keyPressed() {
  if (ui.isEditingText()) {
    ui.handleTextEditKey();
    if (key == ESC) key = 0; // Extremely important: prevents processing from hard-crashing sketch on ECS exit
    return;
  }
  
  // Global Shortcuts (not in text edit mode)
  if (keyCode == ALT) { isAltDown = true; println("Alt Down"); }
  if (keyCode == SHIFT) { keyStates[SHIFT] = true; println("Shift Down"); }
  if (keyCode == CONTROL || keyCode == 157 || keyCode == 91 || (key != CODED && key == 17)) { 
     isCtrlDown = true; 
     println("Control Down"); 
  }
  if (keyCode < 256) keyStates[keyCode] = true;
  
  // Transform Modes
  if (key == '1') { scene.gizmo.mode = 1; println("Mode: Translate"); }
  if (key == '2') { scene.gizmo.mode = 2; println("Mode: Rotate"); }
  if (key == '3') { scene.gizmo.mode = 3; println("Mode: Scale"); }
  if (key == '4') { scene.gizmo.mode = 4; println("Mode: Select"); }
  
  // Snapping Toggle
  if (key == 'g' || key == 'G') {
    snapToGrid = !snapToGrid;
  }
  
  // Coordinate Space Toggle
  if (key == 'l' || key == 'L') {
    scene.useLocalSpace = !scene.useLocalSpace;
    println("Coordinate Space: " + (scene.useLocalSpace ? "LOCAL" : "WORLD"));
  }
  
  // UI Visibility Toggle
  if (key == 'h' || key == 'H' || key == TAB) {
    showUI = !showUI;
  }
  
  if (isCtrlDown) {
    // Determine Undo/Redo correctly
    boolean isZ = (keyCode == 'Z' || (int)key == 26 || (int)key == 122); // 'z' is 122, SUB is 26
    boolean isY = (keyCode == 'Y' || (int)key == 25 || (int)key == 121);
    
    if (isZ && !keyStates[SHIFT]) {
       scene.undoManager.undo();
       debugText = "Action Undone";
       println("Undo Triggered");
    } else if ((isZ && keyStates[SHIFT]) || isY) {
       scene.undoManager.redo();
       debugText = "Action Redone";
       println("Redo Triggered");
    }
    
    // Note: Java/Processing captures CTRL+C as ASCII(3) and CTRL+V as ASCII(22) instead of the literal characters
    if (keyCode == 67 || key == 'c' || key == 'C' || key == 3) {
      ui.copySelection();
    }
    if (keyCode == 86 || key == 'v' || key == 'V' || key == 22) {
      ui.pasteClipboard();
    }
  }
  
  ui.handleKeyPressed();
}

void keyReleased() {
  if (keyCode == ALT) { isAltDown = false; println("Alt Up"); }
  if (keyCode == SHIFT) { keyStates[SHIFT] = false; println("Shift Up"); }
  if (keyCode == CONTROL || keyCode == 157 || keyCode == 91 || (key != CODED && key == 17)) {
     isCtrlDown = false; 
     println("Control Up"); 
  }
  if (keyCode < 256) keyStates[keyCode] = false;
}

// OS specific Save/Load Callbacks initiated by UI routines natively
void fileSelectedForLoad(File selection) {
  if (selection != null) {
    scene.loadScene(selection);
  }
}

void fileSelectedForSave(File selection) {
  if (selection != null) {
    scene.saveScene(selection);
  }
}
