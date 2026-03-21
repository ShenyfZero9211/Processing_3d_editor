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
PVector startDragTargetPos;

PMatrix3D savedProj = new PMatrix3D();
PMatrix3D savedView = new PMatrix3D();

boolean[] keyStates = new boolean[256];
boolean isAltDown = false;
boolean snapToGrid = false; // 10-unit snapping toggle
boolean showUI = true; // H or TAB toggles visibility

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
}

void draw() {
  background(40);
  
  editorCamera.update(keyStates); // Process WASD movement frame by frame
  
  // Apply camera
  editorCamera.apply(this);
  
  // VERY IMPORTANT: Save the matrices before drawing the UI, 
  // because calling camera() for the UI layer resets them to 2D orthographic!
  savedProj.set(((PGraphics3D)g).projection);
  savedView.set(((PGraphics3D)g).modelview);
  
  // Continuous Gizmo Hover Detection
  if (scene.selectedEntity != null && scene.gizmo != null) {
    if (draggingAxis == 0) {
      Ray hoverRay = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
      scene.gizmo.hoverAxis = scene.gizmo.checkHit(hoverRay, scene.selectedEntity, raycaster);
    } else {
      scene.gizmo.hoverAxis = draggingAxis; // Lock highlight visually while tracking mouse
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
    
    // Draw a small red sphere at the origin of the ray
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
  
  // Debug Overlay Text
  if (showDebugRay) {
    fill(0, 255, 0);
    textSize(16);
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
  if (showUI && ui.handleMousePressed()) return; // UI swallows the click only if visible
  
  // 1. Generate pick ray using saved 3D camera matrices!
  Ray ray = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
  if (showDebugRay) debugRay = ray; // Save the ray for visual debugging
  
  if (showDebugRay) {
    debugText = "Ray Start: " + String.format("%.1f, %.1f", ray.origin.x, ray.origin.y) + 
                " Dir: " + String.format("%.2f, %.2f, %.2f", ray.direction.x, ray.direction.y, ray.direction.z);
  }
  
  // 2. Perform intersection only if we clicked Left Mouse Button
  if (mouseButton == LEFT) {
    // Check Gizmo axis intersection first (if selected)
    if (scene.selectedEntity != null) {
      int gizmoAxis = scene.gizmo.checkHit(ray, scene.selectedEntity, raycaster);
      if (gizmoAxis > 0) {
        draggingAxis = gizmoAxis;
        setupDrag();
        return;
      }
    }
    
    // Check Entity intersection
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
      scene.selectEntity(hit);
      if (showDebugRay) debugText += " | Hit: " + hit.name;
    } else {
      scene.selectEntity(null);
      if (showDebugRay) debugText += " | Hit Nothing";
    }
  }
  
  editorCamera.handleMousePressed();
}

PVector startDragPos = null;
PVector startDragScale = null;
PVector startDragRot = null;
PVector startDragPlaneHit = null;

void setupDrag() {
  if (scene.selectedEntity != null) {
    startDragMouseX = mouseX;
    startDragMouseY = mouseY;
    startDragPos = scene.selectedEntity.transform.position.copy();
    startDragScale = scene.selectedEntity.transform.scale.copy();
    startDragRot = scene.selectedEntity.transform.rotation.copy();
    startDragTargetPos = startDragPos.copy(); // backward compat for old code if leftover
    
    if (scene.gizmo.mode == 2) {
      Ray ray = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
      PVector normal = new PVector();
      if (draggingAxis == 1) normal.x = 1;
      if (draggingAxis == 2) normal.y = 1;
      if (draggingAxis == 3) normal.z = 1;
      
      float t = raycaster.intersectPlane(ray, startDragPos, normal);
      if (t > 0) {
        startDragPlaneHit = PVector.add(ray.origin, PVector.mult(ray.direction, t));
      }
    }
  }
}

void mouseDragged() {
  if (draggingAxis > 0 && scene.selectedEntity != null && mouseButton == LEFT) {
    int mode = scene.gizmo.mode;
    
    if (mode == 1 || mode == 3) {
      PVector axisW = new PVector(0,0,0);
      if (draggingAxis == 1) axisW.x = 1;
      if (draggingAxis == 2) axisW.y = 1;
      if (draggingAxis == 3) axisW.z = 1;
      
      PVector p0 = startDragPos;
      PVector p1 = PVector.add(p0, PVector.mult(axisW, 100.0f)); 
      
      PVector s0 = worldToScreen(p0);
      PVector s1 = worldToScreen(p1);
      
      PVector sDir = PVector.sub(s1, s0);
      float sqMag = sDir.magSq();
      
      if (sqMag > 0.001f) {
        PVector mouseDelta = new PVector(mouseX - startDragMouseX, mouseY - startDragMouseY);
        float k = mouseDelta.dot(sDir) / sqMag;
        float worldDelta = k * 100.0f;
        
        if (mode == 1) { // Translate
          float val = 0;
          if (draggingAxis == 1) val = startDragPos.x + worldDelta;
          if (draggingAxis == 2) val = startDragPos.y + worldDelta;
          if (draggingAxis == 3) val = startDragPos.z + worldDelta;
          
          if (snapToGrid) val = round(val / 10.0f) * 10.0f;
          
          if (draggingAxis == 1) scene.selectedEntity.transform.position.x = val;
          if (draggingAxis == 2) scene.selectedEntity.transform.position.y = val;
          if (draggingAxis == 3) scene.selectedEntity.transform.position.z = val;
        }
        else if (mode == 3) { // Scale
          float sDelta = worldDelta / 100.0f; 
          float val = 0;
          if (draggingAxis == 1) val = startDragScale.x + sDelta;
          if (draggingAxis == 2) val = startDragScale.y + sDelta;
          if (draggingAxis == 3) val = startDragScale.z + sDelta;
          
          if (snapToGrid) val = round(val / 0.5f) * 0.5f;
          
          if (draggingAxis == 1) scene.selectedEntity.transform.scale.x = val;
          if (draggingAxis == 2) scene.selectedEntity.transform.scale.y = val;
          if (draggingAxis == 3) scene.selectedEntity.transform.scale.z = val;
        }
      }
    }
    else if (mode == 2 && startDragPlaneHit != null) { // Rotate
      Ray ray = raycaster.getPickRay(mouseX, mouseY, width, height, savedProj, savedView);
      PVector normal = new PVector();
      if (draggingAxis == 1) normal.x = 1;
      if (draggingAxis == 2) normal.y = 1;
      if (draggingAxis == 3) normal.z = 1;
      
      float t = raycaster.intersectPlane(ray, startDragPos, normal);
      if (t > 0) {
        PVector pCur = PVector.add(ray.origin, PVector.mult(ray.direction, t));
        PVector vStart = PVector.sub(startDragPlaneHit, startDragPos).normalize();
        PVector vCur = PVector.sub(pCur, startDragPos).normalize();
        
        float angle = acos(constrain(vStart.dot(vCur), -1.0f, 1.0f));
        PVector cross = vStart.cross(vCur);
        if (cross.dot(normal) < 0) {
          angle = -angle; // Determine rotation direction around normal
        }
        
        float val = 0;
        if (draggingAxis == 1) val = startDragRot.x + angle;
        if (draggingAxis == 2) val = startDragRot.y + angle;
        if (draggingAxis == 3) val = startDragRot.z + angle;
        
        if (snapToGrid) val = round(val / radians(15)) * radians(15);
        
        if (draggingAxis == 1) scene.selectedEntity.transform.rotation.x = val;
        if (draggingAxis == 2) scene.selectedEntity.transform.rotation.y = val;
        if (draggingAxis == 3) scene.selectedEntity.transform.rotation.z = val;
      }
    }
    return;
  }
  
  editorCamera.handleMouseDragged(isAltDown);
}

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
  
  // Transform NDC to Screen Coordinates
  float sx = (clip[0] + 1.0f) * 0.5f * width;
  float sy = 1.0f - (clip[1] + 1.0f) * 0.5f * height; // wait...
  // ny = 1.0f - (2.0f * my / h)
  // 1.0 - ny = 2.0 * my / h => my = (1.0 - ny) * 0.5 * h
  sy = (1.0f - clip[1]) * 0.5f * height;
  
  return new PVector(sx, sy);
}

void mouseReleased() {
  draggingAxis = 0;
  editorCamera.handleMouseReleased();
}

void mouseWheel(MouseEvent event) {
  editorCamera.handleMouseWheel(event);
}

void keyPressed() {
  if (keyCode == ALT) isAltDown = true;
  if (keyCode < 256) keyStates[keyCode] = true;
  
  // Transform Modes
  if (key == '1') scene.gizmo.mode = 1;
  if (key == '2') scene.gizmo.mode = 2;
  if (key == '3') scene.gizmo.mode = 3;
  if (key == '4') scene.gizmo.mode = 4;
  
  // Snapping Toggle
  if (key == 'g' || key == 'G') {
    snapToGrid = !snapToGrid;
  }
  
  // UI Visibility Toggle
  if (key == 'h' || key == 'H' || key == TAB) {
    showUI = !showUI;
  }
  
  ui.handleKeyPressed();
}

void keyReleased() {
  if (keyCode == ALT) isAltDown = false;
  if (keyCode < 256) keyStates[keyCode] = false;
}

// OS specific Save/Load Callbacks initiated by UI
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
