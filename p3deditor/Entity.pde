class Entity {
  int id;
  String name;
  String type; // "Cube", "Sphere", "Plane"
  Transform transform;
  boolean selected = false;
  color col = color(200);
  Entity parent = null;
  ArrayList<Entity> children = new ArrayList<Entity>();
  
  Entity(int id, String name, String type) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.transform = new Transform();
    
    // Generate beautiful distinct pastel colors automatically based on ID
    float h = (id * 0.618033988749895f) % 1.0f; // Golden ratio separation
    java.awt.Color c = java.awt.Color.getHSBColor(h, 0.45f, 0.85f);
    this.col = color(c.getRed(), c.getGreen(), c.getBlue());
  }
  
  void setParent(Entity newParent, boolean preserveWorld) {
    if (this.parent == newParent) return;
    
    PMatrix3D world = preserveWorld ? getWorldMatrix() : null;
    
    if (this.parent != null) {
      this.parent.children.remove(this);
    }
    
    this.parent = newParent;
    if (newParent != null) {
      newParent.children.add(this);
      
      if (preserveWorld) {
        PMatrix3D invParent = newParent.getWorldMatrix();
        invParent.invert();
        invParent.apply(world); 
        transform.position.set(invParent.m03, invParent.m13, invParent.m23);
      }
    } else if (preserveWorld) {
      transform.position.set(world.m03, world.m13, world.m23);
    }
  }
  
  void addChild(Entity child) {
    child.setParent(this, true);
  }
  
  void addChildNoUpdate(Entity child) {
    child.setParent(this, false);
  }
  
  void removeChild(Entity child) {
    child.setParent(null, true);
  }
  
  void render(PApplet app) {
    app.pushMatrix();
    
    // Apply local transform
    app.translate(transform.position.x, transform.position.y, transform.position.z);
    app.rotateX(transform.rotation.x);
    app.rotateY(transform.rotation.y);
    app.rotateZ(transform.rotation.z);
    app.scale(transform.scale.x, transform.scale.y, transform.scale.z);
    
    // PBR-like Specular Highlights (only for this geometry)
    app.specular(120);
    app.shininess(15.0f);
    
    app.fill(selected ? color(255, 180, 0) : col);
    if (selected) {
      app.stroke(255, 100, 0);
      app.strokeWeight(1.5f);
    } else {
      app.noStroke();
    }
    
    // Draw geometry
    if (type.equals("Cube")) app.box(50);
    else if (type.equals("Sphere")) { app.sphereDetail(30); app.sphere(30); }
    else if (type.equals("Plane")) {
      app.box(100, 1, 100); 
    }
    
    // Recursively render children
    for (Entity child : children) {
      child.render(app);
    }
    
    app.popMatrix();
  }
  
  PVector getWorldPosition() {
    PVector pos = transform.position.copy();
    Entity p = parent;
    while (p != null) {
      // Very naive version of world pos for now (just adding offsets)
      // For full rotations/scales of parents, we'd need matrix multiplication
      // Let's use Processing's matrix math for correctness:
      return getWorldMatrix().mult(new PVector(0,0,0), new PVector());
    }
    return pos;
  }
  
  PMatrix3D getWorldMatrix() {
    PMatrix3D mat = new PMatrix3D();
    if (parent != null) {
      mat.set(parent.getWorldMatrix());
    }
    mat.translate(transform.position.x, transform.position.y, transform.position.z);
    mat.rotateX(transform.rotation.x);
    mat.rotateY(transform.rotation.y);
    mat.rotateZ(transform.rotation.z);
    mat.scale(transform.scale.x, transform.scale.y, transform.scale.z);
    return mat;
  }
  
  Entity cloneEntity(int newId, String newName) {
    Entity ne = new Entity(newId, newName, this.type);
    ne.col = this.col;
    ne.transform.position = this.transform.position.copy();
    ne.transform.rotation = this.transform.rotation.copy();
    ne.transform.scale = this.transform.scale.copy();
    
    // Recursive cloning of children
    for (Entity child : this.children) {
      Entity childClone = child.cloneEntity(-1, child.name);
      ne.addChildNoUpdate(childClone); // IMPORTANT: Use NoUpdate to keep local transform pristine!
    }
    
    return ne;
  }
}

class Transform {
  PVector position = new PVector(0, 0, 0);
  PVector rotation = new PVector(0, 0, 0);
  PVector scale = new PVector(1, 1, 1);
}
