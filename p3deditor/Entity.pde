class Entity {
  int id;
  String name;
  String type; // "Cube", "Sphere", "Plane"
  Transform transform;
  boolean selected = false;
  color col = color(200);
  
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
  
  void render(PApplet app) {
    app.pushMatrix();
    app.translate(transform.position.x, transform.position.y, transform.position.z);
    app.rotateX(transform.rotation.x);
    app.rotateY(transform.rotation.y);
    app.rotateZ(transform.rotation.z);
    app.scale(transform.scale.x, transform.scale.y, transform.scale.z);
    
    // PBR-like Specular Highlights
    app.specular(120);
    app.shininess(15.0f);
    
    app.fill(selected ? color(255, 180, 0) : col);
    if (selected) {
      app.stroke(255, 100, 0);
      app.strokeWeight(2);
    } else {
      app.noStroke();
    }
    
    if (type.equals("Cube")) app.box(50);
    else if (type.equals("Sphere")) { app.sphereDetail(30); app.sphere(30); }
    else if (type.equals("Plane")) {
      app.box(100, 1, 100); // Proper 3D box acts much better with Normal+Light calculations than a flat rect!
    }
    
    app.popMatrix();
  }
}

class Transform {
  PVector position = new PVector(0, 0, 0);
  PVector rotation = new PVector(0, 0, 0);
  PVector scale = new PVector(1, 1, 1);
}
