class Gizmo {
  float baseSize = 110;
  float baseThick = 4.5f;
  int hoverAxis = 0;
  int mode = 1; // 1=Translate, 2=Rotate, 3=Scale, 4=Select
  
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
  
  void render(PApplet app, SceneManager scene) {
    if (mode == 4 || scene.selectedEntities.isEmpty()) return;
    
    PVector centerPos = getCenter(scene);
    
    // Force translate mode if multiple items selected
    int drawMode = (scene.selectedEntities.size() > 1) ? 1 : mode;
    
    app.hint(PConstants.DISABLE_DEPTH_TEST);
    app.pushMatrix();
    app.translate(centerPos.x, centerPos.y, centerPos.z);
    
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
      
      // X Axis rotates around X (red ring on YZ plane)
      if (hoverAxis == 1) app.stroke(255, 255, 80); else app.stroke(220, 50, 50);
      app.strokeWeight(hoverAxis == 1 ? baseThick * 1.5f : baseThick);
      app.pushMatrix(); app.rotateY(HALF_PI); app.ellipse(0, 0, rSize, rSize); app.popMatrix();
      
      // Y Axis rotates around Y (green ring on XZ plane)
      if (hoverAxis == 2) app.stroke(255, 255, 80); else app.stroke(50, 200, 50);
      app.strokeWeight(hoverAxis == 2 ? baseThick * 1.5f : baseThick);
      app.pushMatrix(); app.rotateX(HALF_PI); app.ellipse(0, 0, rSize, rSize); app.popMatrix();
      
      // Z Axis rotates around Z (blue ring on XY plane)
      if (hoverAxis == 3) app.stroke(255, 255, 80); else app.stroke(60, 130, 240);
      app.strokeWeight(hoverAxis == 3 ? baseThick * 1.5f : baseThick);
      app.ellipse(0, 0, rSize, rSize);
    }
    
    app.popMatrix();
    app.hint(PConstants.ENABLE_DEPTH_TEST);
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

  int checkHit(Ray worldRay, SceneManager scene, Raycaster rc) {
    if (mode == 4 || scene.selectedEntities.isEmpty()) return 0;
    
    PVector pos = getCenter(scene);
    float dist = PVector.dist(editorCamera.pos, pos);
    float scaleFactor = max(0.01f, dist / 400.0f);
    
    int drawMode = (scene.selectedEntities.size() > 1) ? 1 : mode;
    
    if (drawMode == 1 || drawMode == 3) {
      float scaledSize = baseSize * scaleFactor;
      float scaledThick = baseThick * scaleFactor;
      float tolerance = scaledThick * 3.5f;
      
      float tX = rc.intersectAABB(worldRay, 
            new PVector(pos.x, pos.y - tolerance, pos.z - tolerance),
            new PVector(pos.x + scaledSize, pos.y + tolerance, pos.z + tolerance));
            
      float tY = rc.intersectAABB(worldRay, 
            new PVector(pos.x - tolerance, pos.y, pos.z - tolerance),
            new PVector(pos.x + tolerance, pos.y + scaledSize, pos.z + tolerance));
            
      float tZ = rc.intersectAABB(worldRay, 
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
      
      float tX = rc.intersectPlane(worldRay, pos, new PVector(1, 0, 0));
      if (tX > 0) {
        PVector p = PVector.add(worldRay.origin, PVector.mult(worldRay.direction, tX));
        if (abs(PVector.dist(p, pos) - R) < tolerance) { minT = tX; hit = 1; }
      }
      
      float tY = rc.intersectPlane(worldRay, pos, new PVector(0, 1, 0));
      if (tY > 0 && tY < minT) {
        PVector p = PVector.add(worldRay.origin, PVector.mult(worldRay.direction, tY));
        if (abs(PVector.dist(p, pos) - R) < tolerance) { minT = tY; hit = 2; }
      }
      
      float tZ = rc.intersectPlane(worldRay, pos, new PVector(0, 0, 1));
      if (tZ > 0 && tZ < minT) {
        PVector p = PVector.add(worldRay.origin, PVector.mult(worldRay.direction, tZ));
        if (abs(PVector.dist(p, pos) - R) < tolerance) { hit = 3; }
      }
      
      return hit;
    }
    
    return 0;
  }
}
