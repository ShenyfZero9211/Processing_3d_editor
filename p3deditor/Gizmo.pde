/**
 * Gizmo.pde - 3D Transformation Handles
 * 
 * Version: v0.4.9
 * Responsibilities:
 * - Renders Translate, Rotate, and Scale handles in the 3D viewport.
 * - Manages hit-testing for axis-specific mouse dragging.
 * - Implements 'Constant Screen Size' logic for distance-agnostic manipulation.
 * - Handles both World and Local coordinate space visualizations.
 */
class Gizmo {
  float baseSize = 110;
  float baseThick = 4.5f;
  int hoverAxis = 0;
  int mode = 1; // 1=Translate, 2=Rotate, 3=Scale, 4=Select
  
  /**
   * getCenter() - Selection Group Centroid
   * 
   * Calculates the mathematical center of the current selection. For a single
   * entity, returns its world position. For multiple entities, returns the 
   * average position of all members.
   */
  PVector getCenter(SceneManager scene) {
    if (scene.selectedEntities.isEmpty()) return null;
    if (scene.selectedEntities.size() == 1) return scene.selectedEntities.get(0).getWorldPosition();
    
    PVector center = new PVector();
    for (Entity e : scene.selectedEntities) {
      center.add(e.getWorldPosition());
    }
    center.div(scene.selectedEntities.size());
    return center;
  }
  
  /**
   * render() - Gizmo HUD Pass
   * 
   * [ALGORITHM] Constant Screen Size Magic
   * Calculates the distance from the camera to the gizmo's center and scales 
   * the geometry proportionally. This ensures that the handles always appear 
   * the same size on screen, preventing them from becoming too small to click 
   * at long distances or too large when close.
   */
  void render(PApplet app, SceneManager scene) {
    if (mode == 4 || scene.selectedEntities.isEmpty()) return;
    
    app.pushStyle();
    PVector centerPos = getCenter(scene);
    int drawMode = mode; // Allow visual switching for all selections
    
    app.hint(PConstants.DISABLE_DEPTH_TEST);
    app.pushMatrix();
    app.translate(centerPos.x, centerPos.y, centerPos.z);
    
    if (scene.useLocalSpace && scene.selectedEntities.size() == 1) {
      Entity e = scene.selectedEntities.get(0);
      PMatrix3D wm = e.getWorldMatrix();
      // We only want the rotation part of the world matrix
      float rotateX, rotateY, rotateZ;
      // Since our rotation is euler, we can just use the transform.rotation 
      // but if the entity is a child, we need the accumulated world rotation.
      // Easiest: extract from getWorldMatrix or just use e.transform.rotation 
      // if we assume local mode means "selection's direct orientation".
      
      // Better: Use the rotation from the world matrix
      // For simplicity in Processing, we can just apply the Euler angles if we trust them
      app.rotateY(e.transform.rotation.y);
      app.rotateX(e.transform.rotation.x);
      app.rotateZ(e.transform.rotation.z);
    }
    
    float dist = PVector.dist(editorCamera.pos, centerPos);
    float scaleFactor = max(0.01f, dist / 400.0f);
    app.scale(scaleFactor);
    
    if (drawMode == 1 || drawMode == 3) {
      app.noStroke();
      // X Axis (Red)
      if (hoverAxis == 1) app.fill(255, 255, 80); else app.fill(220, 50, 50);
      app.pushMatrix(); app.rotateZ(-HALF_PI); drawAxis(app, drawMode); app.popMatrix();
      
      // Y Axis (Green)
      if (hoverAxis == 2) app.fill(255, 255, 80); else app.fill(50, 200, 50);
      app.pushMatrix(); drawAxis(app, drawMode); app.popMatrix();
      
      // Z Axis (Blue)
      if (hoverAxis == 3) app.fill(255, 255, 80); else app.fill(60, 130, 240);
      app.pushMatrix(); app.rotateX(HALF_PI); drawAxis(app, drawMode); app.popMatrix();
      
      // Center origin geometry
      if (hoverAxis > 0) app.fill(255, 255, 80); else app.fill(240);
      if (drawMode == 1) {
        app.sphereDetail(12);
        app.sphere(baseThick * 1.5f);
      } else {
        app.box(baseThick * 2.5f);
      }
    } 
    else if (drawMode == 2) {
      app.noFill();
      float rSize = baseSize * 1.5f;
      float sw = baseThick / scaleFactor; // Counteract scaling to keep screen weight constant
      
      // X Axis rotates around X (red ring on YZ plane)
      if (hoverAxis == 1) app.stroke(255, 255, 80); else app.stroke(220, 50, 50);
      app.strokeWeight(hoverAxis == 1 ? sw * 1.5f : sw);
      app.pushMatrix(); app.rotateY(HALF_PI); app.ellipse(0, 0, rSize, rSize); app.popMatrix();
      
      // Y Axis rotates around Y (green ring on XZ plane)
      if (hoverAxis == 2) app.stroke(255, 255, 80); else app.stroke(50, 200, 50);
      app.strokeWeight(hoverAxis == 2 ? sw * 1.5f : sw);
      app.pushMatrix(); app.rotateX(HALF_PI); app.ellipse(0, 0, rSize, rSize); app.popMatrix();
      
      // Z Axis rotates around Z (blue ring on XY plane)
      if (hoverAxis == 3) app.stroke(255, 255, 80); else app.stroke(60, 130, 240);
      app.strokeWeight(hoverAxis == 3 ? sw * 1.5f : sw);
      app.ellipse(0, 0, rSize, rSize);
    }
    
    app.popMatrix();
    app.hint(PConstants.ENABLE_DEPTH_TEST);
    app.popStyle();
  }
  
  void drawAxis(PApplet app, int drawMode) {
    float shaftLen = baseSize * 0.8f;
    float radius = baseThick * 0.35f;
    
    app.pushMatrix();
    drawCylinder(app, radius, shaftLen, 10);
    app.translate(0, shaftLen, 0);
    if (drawMode == 1) {
      float headLen = baseSize * 0.2f;
      float headRadius = baseThick * 1.4f;
      drawCone(app, headRadius, headLen, 16);
    } else if (drawMode == 3) {
      float boxSize = baseThick * 2.5f;
      app.translate(0, boxSize/2, 0);
      app.box(boxSize);
    }
    app.popMatrix();
  }
  
  void drawCone(PApplet app, float r, float h, int detail) {
    app.beginShape(TRIANGLES);
    for (int i = 0; i < detail; i++) {
        float a1 = TWO_PI / detail * i;
        float a2 = TWO_PI / detail * (i+1);
        app.vertex(0, h, 0);
        app.vertex(cos(a1)*r, 0, sin(a1)*r);
        app.vertex(cos(a2)*r, 0, sin(a2)*r);
        app.vertex(0, 0, 0);
        app.vertex(cos(a2)*r, 0, sin(a2)*r);
        app.vertex(cos(a1)*r, 0, sin(a1)*r);
    }
    app.endShape();
  }
  
  void drawCylinder(PApplet app, float r, float h, int detail) {
    app.beginShape(QUADS);
    for (int i = 0; i < detail; i++) {
        float a1 = TWO_PI / detail * i;
        float a2 = TWO_PI / detail * (i+1);
        app.vertex(cos(a1)*r, 0, sin(a1)*r);
        app.vertex(cos(a2)*r, 0, sin(a2)*r);
        app.vertex(cos(a2)*r, h, sin(a2)*r);
        app.vertex(cos(a1)*r, h, sin(a1)*r);
    }
    app.endShape();
  }

  /**
   * checkHit() - Transform Handle Detection
   * 
   * [ALGORITHM] Axis picking
   * For Translate/Scale: Uses AABB intersection on virtual boxes surrounding
   * the axes.
   * For Rotate: Uses Ray-Plane intersection followed by a distance check to
   * detect clicks on the ring perimeter.
   * Supports Local Space by pre-rotating the check-ray.
   */
  int checkHit(Ray worldRay, SceneManager scene, Raycaster rc) {
    if (mode == 4 || scene.selectedEntities.isEmpty()) return 0;
    
    PVector pos = getCenter(scene);
    float dist = PVector.dist(editorCamera.pos, pos);
    float scaleFactor = max(0.01f, dist / 400.0f);
    int drawMode = mode;
    
    Ray localRay = worldRay;
    if (scene.useLocalSpace && scene.selectedEntities.size() == 1) {
      Entity e = scene.selectedEntities.get(0);
      PMatrix3D inv = e.getWorldMatrix();
      inv.invert();
      
      // Transform ray origin and direction into local space
      // Note: we need to handle the gizmo's center relative to entity 
      // But gizmo is AT the entity center, so origin - pos, then rotate.
      PVector originLocal = PVector.sub(worldRay.origin, pos);
      PVector dirLocal = new PVector();
      
      // Create a rotation-only matrix from euler
      PMatrix3D rotM = new PMatrix3D();
      rotM.rotateY(e.transform.rotation.y);
      rotM.rotateX(e.transform.rotation.x);
      rotM.rotateZ(e.transform.rotation.z);
      rotM.invert();
      
      rotM.mult(originLocal, originLocal);
      rotM.mult(worldRay.direction, dirLocal);
      
      // Reconstruct local ray (origin is now relative to Gizmo center at 0,0,0)
      localRay = new Ray(originLocal, dirLocal.normalize());
      // We also shift the check below to use a 0,0,0 pos for the boxes
      pos = new PVector(0,0,0);
    }
    
    if (drawMode == 1 || drawMode == 3) {
      float scaledSize = baseSize * scaleFactor;
      float scaledThick = baseThick * scaleFactor;
      float tolerance = scaledThick * 3.5f;
      
      float tX = rc.intersectAABB(localRay, 
            new PVector(pos.x, pos.y - tolerance, pos.z - tolerance),
            new PVector(pos.x + scaledSize, pos.y + tolerance, pos.z + tolerance));
            
      float tY = rc.intersectAABB(localRay, 
            new PVector(pos.x - tolerance, pos.y, pos.z - tolerance),
            new PVector(pos.x + tolerance, pos.y + scaledSize, pos.z + tolerance));
            
      float tZ = rc.intersectAABB(localRay, 
            new PVector(pos.x - tolerance, pos.y - tolerance, pos.z),
            new PVector(pos.x + tolerance, pos.y + tolerance, pos.z + scaledSize));
            
      float minT = 999999;
      int hit = 0;
      if (tX > 0 && tX < minT) { minT = tX; hit = 1; }
      if (tY > 0 && tY < minT) { minT = tY; hit = 2; }
      if (tZ > 0 && tZ < minT) { minT = tZ; hit = 3; }
      return hit;
    } 
    else if (drawMode == 2) {
      float R = (baseSize * 1.5f * scaleFactor) / 2.0f;
      float tolerance = baseThick * scaleFactor * 3.5f;
      
      float minT = 999999;
      int hit = 0;
      
      float tX = rc.intersectPlane(localRay, pos, new PVector(1, 0, 0));
      if (tX > 0) {
        PVector p = PVector.add(localRay.origin, PVector.mult(localRay.direction, tX));
        if (abs(PVector.dist(p, pos) - R) < tolerance) { minT = tX; hit = 1; }
      }
      
      float tY = rc.intersectPlane(localRay, pos, new PVector(0, 1, 0));
      if (tY > 0 && tY < minT) {
        PVector p = PVector.add(localRay.origin, PVector.mult(localRay.direction, tY));
        if (abs(PVector.dist(p, pos) - R) < tolerance) { minT = tY; hit = 2; }
      }
      
      float tZ = rc.intersectPlane(localRay, pos, new PVector(0, 0, 1));
      if (tZ > 0 && tZ < minT) {
        PVector p = PVector.add(localRay.origin, PVector.mult(localRay.direction, tZ));
        if (abs(PVector.dist(p, pos) - R) < tolerance) { hit = 3; }
      }
      
      return hit;
    }
    
    return 0;
  }
}
