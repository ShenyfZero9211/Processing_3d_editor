class EditorCamera {
  PVector pos = new PVector(0, -100, 400); 
  PVector target = new PVector(0, 0, 0);
  float orbitDistance = 400;
  
  float rotX = -PI/6; // Pitch
  float rotY = PI/4;  // Yaw
  
  float lastMouseX, lastMouseY;
  boolean isRightDragging = false;
  boolean wasCursorHidden = false;
  float flySpeed = 8.0f;
  
  EditorCamera() {
    updatePosFromTarget();
  }
  
  void reset() {
    pos.set(0, -100, 400); 
    target.set(0, 0, 0);
    orbitDistance = 400;
    rotX = -PI/6;
    rotY = PI/4;
    updatePosFromTarget();
  }
  
  // Mathematical derivation of View space basis vectors mapped to World space
  PVector getForward() { 
    return new PVector(cos(rotX)*sin(rotY), -sin(rotX), -cos(rotX)*cos(rotY)); 
  }
  PVector getRight() { 
    return new PVector(cos(rotY), 0, sin(rotY)); 
  }
  PVector getUp() { 
    // Guarantee orthogonal local Up vector to prevent mathematically flipping the camera
    return getRight().cross(getForward()); 
  }
  
  void apply(PApplet app) {
    PVector fwd = getForward();
    PVector up = getUp();
    PVector lookAt = PVector.add(pos, fwd);
    app.camera(pos.x, pos.y, pos.z, lookAt.x, lookAt.y, lookAt.z, up.x, up.y, up.z);
  }
  
  void updatePosFromTarget() {
    pos = PVector.sub(target, PVector.mult(getForward(), orbitDistance));
  }
  
  void updateTargetFromPos() {
    target = PVector.add(pos, PVector.mult(getForward(), orbitDistance));
  }
  
  // Called every frame
  void update(boolean[] keyStates) {
    if (isRightDragging && !isAltDown) { // Fly mode WASD movement and Cursor Lock
      
      // 1. Precise Cursor Lock and Rotation via Java AWT Robot
      if (robot != null) {
        if (!wasCursorHidden) {
          noCursor();
          robot.mouseMove(displayWidth / 2, displayHeight / 2);
          wasCursorHidden = true;
        } else {
          java.awt.Point p = java.awt.MouseInfo.getPointerInfo().getLocation();
          int centerX = displayWidth / 2;
          int centerY = displayHeight / 2;
          int actDx = p.x - centerX;
          int actDy = p.y - centerY;
          
          if (actDx != 0 || actDy != 0) {
            rotY += actDx * 0.005f; // Left/Right inverted as requested
            rotX -= actDy * 0.005f; // Pitch
            rotX = constrain(rotX, -HALF_PI+0.01, HALF_PI-0.01);
            updateTargetFromPos(); 
            
            robot.mouseMove(centerX, centerY);
          }
        }
      }
      
      // 2. Physical WASD Free Fly movement
      PVector f = getForward();
      PVector r = getRight();
      PVector u = new PVector(0, -1, 0); // Absolute UP is -Y for intuitive EQ rising
      
      PVector move = new PVector();
      if (keyStates['W'] || keyStates['w']) move.add(f);
      if (keyStates['S'] || keyStates['s']) move.sub(f);
      if (keyStates['A'] || keyStates['a']) move.sub(r);
      if (keyStates['D'] || keyStates['d']) move.add(r);
      if (keyStates['E'] || keyStates['e']) move.add(u);
      if (keyStates['Q'] || keyStates['q']) move.sub(u);
      
      if (move.magSq() > 0) {
        move.normalize();
        pos.add(PVector.mult(move, flySpeed));
        updateTargetFromPos(); // Update logical pivot so Orbit later orbits what we flew up to
      }
      
    } else {
      if (wasCursorHidden) {
        cursor();
        wasCursorHidden = false;
      }
    }
  }
  
  void handleMousePressed() {
    lastMouseX = mouseX;
    lastMouseY = mouseY;
    if (mouseButton == RIGHT) isRightDragging = true;
  }
  
  void handleMouseDragged(boolean isAltDown) {
    float dx = mouseX - lastMouseX;
    float dy = mouseY - lastMouseY;
    
    if (isAltDown) {
      if (mouseButton == LEFT) { // Orbit
        rotY += dx * 0.01;
        rotX -= dy * 0.01; // Inverted Y-axis per user preference
        rotX = constrain(rotX, -HALF_PI+0.01, HALF_PI-0.01);
        updatePosFromTarget();
      } 
      else if (mouseButton == CENTER) { // Pan
        float panSpeed = orbitDistance * 0.0015f;
        target.sub(PVector.mult(getRight(), dx * panSpeed));
        target.sub(PVector.mult(getUp(), dy * panSpeed)); // P3D Up vector mapping respects camera pitch
        updatePosFromTarget();
      } 
      else if (mouseButton == RIGHT) { // Zoom
        orbitDistance += (dx - dy) * orbitDistance * 0.005f;
        orbitDistance = max(5, orbitDistance);
        updatePosFromTarget();
      }
    } else {
      if (mouseButton == RIGHT) { // Fly Look (Pitch & Yaw from local position)
        if (robot == null) {
          // Fallback mathematically if java Robot creation failed
          rotY += dx * 0.01; // FPS Yaw reversed
          rotX -= dy * 0.01; // Pitch (Inverted/Airplane mode)
          rotX = constrain(rotX, -HALF_PI+0.01, HALF_PI-0.01);
          updateTargetFromPos(); // Re-adjust orbit target
        }
      }
    }
    
    lastMouseX = mouseX; 
    lastMouseY = mouseY;
  }
  
  void handleMouseReleased() {
    if (mouseButton == RIGHT) isRightDragging = false;
  }
  
  void handleMouseWheel(MouseEvent event) {
    float e = event.getCount();
    orbitDistance += e * orbitDistance * 0.1f;
    orbitDistance = max(5, orbitDistance);
    updatePosFromTarget();
  }
}
